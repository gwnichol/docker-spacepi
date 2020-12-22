docker build -t spacepi/docker-spacepi ./
docker run -it --rm -v /home/gwnichol/Documents/FFaero/GIT/docker-spacepi/armel.iso:/sdcard/filesystem.img -p 5022:5022 spacepi/docker-spacepi pi2
#docker run -it --rm -v /home/gwnichol/Downloads/2020-12-02-raspios-buster-armhf-lite.img:/sdcard/filesystem.img spacepi/docker-spacepi pi2
