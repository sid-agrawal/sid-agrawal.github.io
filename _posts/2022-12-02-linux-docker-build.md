Steps to build the linux kernel in a docker container and install it on the host.
This is done so that it does not mess up the packages installed on the host.


## Setup a container

Build
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
docker build . -t linux-build-vm
```

## Get the code

```bash
cd ~
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.0.7.tar.xz
tar xvf linux-6.0.7.tar.xz
```

## Start the container with a shared dir

```bash
cd linux-6.0.7
sudo cp /boot/config-5.15.0-56-generic .config
docker run --rm -it -v `pwd`:/linux-src linux-build-vm
```

Inside docker
```bash
docker> cd /linux-src
docker> make menuconfig
docker> make bzImage
```


Back On the host
```bash
cd ~/linux-src
sudo make install
```




[1] https://phoenixnap.com/kb/build-linux-kernel
