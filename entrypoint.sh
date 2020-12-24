#!/bin/sh

target="${1:-pi1}"
image_path="/sdcard/filesystem.img"
zip_path="/filesystem.zip"

if [ ! -e $image_path ]; then
  echo "No filesystem detected at ${image_path}!"
  if [ -e $zip_path ]; then
      echo "Extracting fresh filesystem..."
      unzip $zip_path
      mv -- *.img $image_path
  else
    exit 1
  fi
fi

qemu-img resize $image_path 4G

if [ "${target}" = "pi1" ]; then
  emulator=qemu-system-arm
  kernel="/root/qemu-rpi-kernel/kernel-qemu-4.19.50-buster"
  dtb="/root/qemu-rpi-kernel/versatile-pb.dtb"
  machine=versatilepb
  memory=256m
  root=/dev/sda2
  extra=''
  nic='--net nic --net user,hostfwd=tcp::5022-:22'
  cmdline='rootwait earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=${root} elevator=deadline'
elif [ "${target}" = "pi2" ]; then
  emulator=qemu-system-arm
  machine=raspi2
  memory=1024m
  kernel_pattern=kernel7.img
  dtb_pattern=bcm2709-rpi-2-b.dtb
  nic='-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0'
  cmdline=''
elif [ "${target}" = "pi3" ]; then
  emulator=qemu-system-aarch64
  machine=raspi3
  memory=1024m
  kernel_pattern=kernel8.img
  dtb_pattern=bcm2710-rpi-3-b-plus.dtb
  nic='-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0'
  cmdline=''
else
  echo "Target ${target} not supported"
  echo "Supported targets: pi1 pi2 pi3"
  exit 2
fi

if [ "${kernel_pattern}" ] && [ "${dtb_pattern}" ]; then
  fat_path="/fat.img"
  echo "Extracting partitions"
  fdisk -l ${image_path} \
    | awk "/^[^ ]*1/{print \"dd if=${image_path} of=${fat_path} bs=512 skip=\"\$4\" count=\"\$6}" \
    | sh

  echo "Extracting boot filesystem"
  fat_folder="/fat"
  mkdir -p "${fat_folder}"
  fatcat -x "${fat_folder}" "${fat_path}"

  root=/dev/mmcblk0p3

  echo "Searching for kernel='${kernel_pattern}'"
  kernel=$(find "${fat_folder}" -name "${kernel_pattern}")

  echo "Searching for dtb='${dtb_pattern}'"
  dtb=$(find "${fat_folder}" -name "${dtb_pattern}")

  cmdline=$( sed \
    -e 's/console=[^[:space:]]*\ \?//' \
    -e 's/dwc_otg\.lpm_enable=[^[:space:]]*\ \?//' \
    -e 's/dwc_otg\.fig_fsm_enable=[^[:space:]]*\ \?//' \
    -e 's/panic=[^[:space:]]*\ \?//' \
	-e 's/$/ rootwait console=ttyAMA0,115200 dwc_otg.lpm_enable=0 dwc_otg.fiq_fsm_enable=0 panic=1/' \
	< "${fat_folder}/cmdline.txt" \
    )

  echo "Using cmdline='${cmdline}'"

fi

if [ "${kernel}" = "" ] || [ "${dtb}" = "" ] || [ "${cmdline}" = ""]; then
  echo "Missing kernel='${kernel}' or dtb='${dtb}' or cmdline='${cmdline}'"
  exit 2
fi

echo "Booting QEMU machine \"${machine}\" with kernel=${kernel} dtb=${dtb}"
exec ${emulator} \
  --machine "${machine}" \
  --cpu arm1176 \
  --m "${memory}" \
  --append "${cmdline}" \
  --drive "format=raw,file=${image_path}" \
  ${nic} \
  --dtb "${dtb}" \
  --kernel "${kernel}" \
  --display none \
  --serial mon:stdio

#  --append "rootwait earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=${root} init=/spacepi/setup.sh elevator=deadline panic=1 ${extra}" \
#root=/dev/mmcblk0p3 rootwait fsck.repair=yes ro console=tty0 elevator=deadline init=/spacepi/setup.sh
