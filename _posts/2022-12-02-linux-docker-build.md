Steps to build the linux kernel in a docker container and install it on the host.
This is done so that it does not mess up the packages installed on the host.


## Setup a container

Build the image `linux-build-vm` based on this image.

```Dockerfile
FROM debian

RUN apt-get update
RUN apt-get install -y \
        bc \
        bison \
        build-essential \
        cpio \
        flex \
        libelf-dev \
        libncurses-dev \
        libssl-dev \
        vim-tiny
        git \ 
        fakeroot \ 
        build-essential \
        ncurses-dev \
        xz-utils \
        libssl-dev \ 
        bc  \
        flex \
        libelf-dev \
        openssl \
        zstd \
        bison

RUN mkdir /linux-src
CMD ["bash"]
```

```bash
host> docker build . -t linux-build-vm
```

## Get the code on the host

```bash
host> cd ~
host> wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.0.7.tar.xz
host> tar xvf linux-6.0.7.tar.xz
```

## Start the container

Share the linux src directory on the host with the container.

```bash
host> cd linux-6.0.7
host> sudo cp /boot/config-5.15.0-56-generic .config
host> docker run --rm -it -v `pwd`:/linux-src linux-build-vm
```

```bash
docker> cd /linux-src
docker> make menuconfig
docker> make bzImage
```

Back On the host
```bash
host> cd ~/linux-src
host> sudo make install
```

[1] https://phoenixnap.com/kb/build-linux-kernel
