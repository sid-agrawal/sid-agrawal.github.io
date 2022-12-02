# Build the linux kernel in a docker container


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
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.0.7.tar.xz
tar xvf linux-6.0.7.tar.xz
```

## Start the container with a shared dir






[1] https://phoenixnap.com/kb/build-linux-kernel
