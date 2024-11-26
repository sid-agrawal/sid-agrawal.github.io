---
layout: posts
title:  "Understanding the various mounts setup by a Docker container"
date: 2024-07-11
categories: Linux, Docker, mount, namespaces, mount_namespaces
---

Why does a docker container have so many mounts?

# Observed Behaviour
This week, as I was digging into `mount_spaces` on Linux, there were some things I couldn't quite explain. 
Let’s just talk about `procfs` mounts for now.

Running the following on the host machine:
```bash
host> mount | grep "^proc" on the host (with sudo) yields
host> proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
```

Which makes sense. The `/proc` is mounted once.

-----------------------------------------------------

But when I run the same command inside run a docker container:
```bash
host> docker run -it ubuntu bash
container> mount | grep "^proc"
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
proc on /proc/bus type proc (ro,nosuid,nodev,noexec,relatime)
proc on /proc/fs type proc (ro,nosuid,nodev,noexec,relatime)
proc on /proc/irq type proc (ro,nosuid,nodev,noexec,relatime)
proc on /proc/sys type proc (ro,nosuid,nodev,noexec,relatime)
proc on /proc/sysrq-trigger type proc (ro,nosuid,nodev,noexec,relatime)
```

I was confused to see `/proc` mounted so many times, also how does mounting `/proc` and `/proc/bus` work? 
Does it automatically expose the /bus part?

------------------------------------------------------------------------------------
Furthermore, I also a see a bunch of `tmpfs` mounts inside the container. 
I think I do know the purpose of this, these basically mask parts of the `/proc` that the docker shouldn’t access. 
Clearly they are related to things the container has no need to know such as power, or kernel memory, timers etc. 
```bash
container> mount | grep "^tmpfs"
tmpfs on /dev type tmpfs (rw,nosuid,size=65536k,mode=755,inode64)
tmpfs on /proc/asound type tmpfs (ro,relatime,inode64)
tmpfs on /proc/acpi type tmpfs (ro,relatime,inode64)
tmpfs on /proc/kcore type tmpfs (rw,nosuid,size=65536k,mode=755,inode64)
tmpfs on /proc/keys type tmpfs (rw,nosuid,size=65536k,mode=755,inode64)
tmpfs on /proc/timer_list type tmpfs (rw,nosuid,size=65536k,mode=755,inode64)
tmpfs on /proc/scsi type tmpfs (ro,relatime,inode64)
```



------------------------------------------------------------------------

If I run a privileged container. All, the extra `/proc` mounts go away.

```bash
host> docker run --privileged -it ubuntu bash
container> mount | grep "^proc"
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
```



# Investigation
To find out what is going on I decided to trace the `mount` syscalls called during the container creation.
These syscalls are not called by `docker run` as that is merely a CLI tool. The commands given to `docker run`,
are eventually related to `containerd` (which was PID 1927 on my system) and that is the one responsible for doing the `namespace` and `mount` setup.

Below is the `strace` command's output when running `docker run ubuntu bash` on a different terminal.

```bash
host>  sudo strace -e clone -f -qqq -p 1927
[pid 407998] mount("", "/", 0xc0001d673c, MS_REC|MS_SLAVE, NULL) = 0
[pid 407998] mount("/var/lib/docker/overlay2/edec7a778b7d587e77d2c28d6f210f805754a7bfee173acd7d4d55a1147dad6e/merged", "/var/lib/docker/overlay2/edec7a778b7d587e77d2c28d6f210f805754a7bfee173acd7d4d55a1147dad6e/merged", 0xc0001d6750, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("proc", "/proc/self/fd/7", "proc", MS_NOSUID|MS_NODEV|MS_NOEXEC, NULL) = 0
[pid 407998] mount("tmpfs", "/proc/self/fd/7", "tmpfs", MS_NOSUID|MS_STRICTATIME, "mode=0755,mode=755,size=65536k") = 0
[pid 407998] mount("devpts", "/proc/self/fd/7", "devpts", MS_NOSUID|MS_NOEXEC, "newinstance,ptmxmode=0666,mode=0"...) = 0
[pid 407998] mount("sysfs", "/proc/self/fd/7", "sysfs", MS_RDONLY|MS_NOSUID|MS_NODEV|MS_NOEXEC, NULL) = 0
[pid 407998] mount("cgroup", "/proc/self/fd/7", "cgroup2", MS_RDONLY|MS_NOSUID|MS_NODEV|MS_NOEXEC, NULL) = 0
[pid 407998] mount("mqueue", "/proc/self/fd/7", "mqueue", MS_NOSUID|MS_NODEV|MS_NOEXEC, NULL) = 0
[pid 407998] mount("shm", "/proc/self/fd/7", "tmpfs", MS_NOSUID|MS_NODEV|MS_NOEXEC, "mode=1777,size=67108864") = 0
[pid 407998] mount("/var/lib/docker/containers/26cd3171448e956dddc1d397f115a21cfd0aea8830415b733e8c219e8d51d424/resolv.conf", "/proc/self/fd/7", 0xc0001d6de0, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("", "/proc/self/fd/7", 0xc0001d6de6, MS_REC|MS_PRIVATE, NULL) = 0
[pid 407998] mount("/var/lib/docker/containers/26cd3171448e956dddc1d397f115a21cfd0aea8830415b733e8c219e8d51d424/hostname", "/proc/self/fd/7", 0xc0001d6e69, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("", "/proc/self/fd/7", 0xc0001d6f0e, MS_REC|MS_PRIVATE, NULL) = 0
[pid 407998] mount("/var/lib/docker/containers/26cd3171448e956dddc1d397f115a21cfd0aea8830415b733e8c219e8d51d424/hosts", "/proc/self/fd/7", 0xc0001d6fda, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("", "/proc/self/fd/7", 0xc0001d702b, MS_REC|MS_PRIVATE, NULL) = 0
[pid 407998] mount("", ".", 0xc0001d71c4, MS_REC|MS_SLAVE, NULL) = 0
[pid 407998] mount("/dev/pts/0", "/dev/console", 0xc0001d71ea, MS_BIND, NULL) = 0
[pid 407998] mount("/proc/bus", "/proc/bus", 0xc0001d724a, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("/proc/bus", "/proc/bus", 0xc0001d726a, MS_RDONLY|MS_NOSUID|MS_NODEV|MS_NOEXEC|MS_REMOUNT|MS_BIND, NULL) = 0
[pid 407998] mount("/proc/fs", "/proc/fs", 0xc0001d7299, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("/proc/fs", "/proc/fs", 0xc0001d72b9, MS_RDONLY|MS_NOSUID|MS_NODEV|MS_NOEXEC|MS_REMOUNT|MS_BIND, NULL) = 0
[pid 407998] mount("/proc/irq", "/proc/irq", 0xc0001d72ba, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("/proc/irq", "/proc/irq", 0xc0001d730a, MS_RDONLY|MS_NOSUID|MS_NODEV|MS_NOEXEC|MS_REMOUNT|MS_BIND, NULL) = 0
[pid 407998] mount("/proc/sys", "/proc/sys", 0xc0001d733a, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("/proc/sys", "/proc/sys", 0xc0001d735a, MS_RDONLY|MS_NOSUID|MS_NODEV|MS_NOEXEC|MS_REMOUNT|MS_BIND, NULL) = 0
[pid 407998] mount("/proc/sysrq-trigger", "/proc/sysrq-trigger", 0xc0001d735b, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("/proc/sysrq-trigger", "/proc/sysrq-trigger", 0xc0001d735c, MS_RDONLY|MS_NOSUID|MS_NODEV|MS_NOEXEC|MS_REMOUNT|MS_BIND, NULL) = 0
[pid 407998] mount("/dev/null", "/proc/asound", 0xc0001d738a, MS_BIND, NULL) = -1 ENOTDIR (Not a directory)
[pid 407998] mount("tmpfs", "/proc/asound", "tmpfs", MS_RDONLY, NULL) = 0
[pid 407998] mount("/dev/null", "/proc/acpi", 0xc0001d73ca, MS_BIND, NULL) = -1 ENOTDIR (Not a directory)
[pid 407998] mount("tmpfs", "/proc/acpi", "tmpfs", MS_RDONLY, NULL) = 0
[pid 407998] mount("/dev/null", "/proc/kcore", 0xc0001d740a, MS_BIND, NULL) = 0
[pid 407998] mount("/dev/null", "/proc/keys", 0xc0001d742a, MS_BIND, NULL) = 0
[pid 407998] mount("/dev/null", "/proc/latency_stats", 0xc0001d744a, MS_BIND, NULL) = -1 ENOENT (No such file or directory)
[pid 407998] mount("/dev/null", "/proc/timer_list", 0xc0001d745a, MS_BIND, NULL) = 0
[pid 407998] mount("/dev/null", "/proc/timer_stats", 0xc0001d746a, MS_BIND, NULL) = -1 ENOENT (No such file or directory)
[pid 407998] mount("/dev/null", "/proc/sched_debug", 0xc0001d747a, MS_BIND, NULL) = -1 ENOENT (No such file or directory)
[pid 407998] mount("/dev/null", "/proc/scsi", 0xc0001d748a, MS_BIND, NULL) = -1 ENOTDIR (Not a directory)
[pid 407998] mount("tmpfs", "/proc/scsi", "tmpfs", MS_RDONLY, NULL) = 0
[pid 407998] mount("/dev/null", "/sys/firmware", 0xc0001d74ca, MS_BIND, NULL) = -1 ENOTDIR (Not a directory)
[pid 407998] mount("tmpfs", "/sys/firmware", "tmpfs", MS_RDONLY, NULL) = 0
[pid 407998] mount("/dev/null", "/sys/devices/virtual/powercap", 0xc0001d750a, MS_BIND, NULL) = -1 ENOTDIR (Not a directory)
[pid 407998] mount("tmpfs", "/sys/devices/virtual/powercap", "tmpfs", MS_RDONLY, NULL) = 0
```

There are 43 calls to mount.
It seems like we are trying to hide parts of the `/proc` and `/sys` because the original mount of type `procfs` or `sysfs`
doesn't have way of restricting that. 

# Explanation
Docker inspect tells us that there are `Masked Paths` and `Readonly Paths`.
```json
     "MaskedPaths": [
        "/proc/asound",
        "/proc/acpi",
        "/proc/kcore",
        "/proc/keys",
        "/proc/latency_stats",
        "/proc/timer_list",
        "/proc/timer_stats",
        "/proc/sched_debug",
        "/proc/scsi",
        "/sys/firmware",
        "/sys/devices/virtual/powercap"
      ],
      "ReadonlyPaths": [
        "/proc/bus",
        "/proc/fs",,
        "/proc/irq",
        "/proc/sys-trigger",
        "/proc/sysrq-trigger"
      ]
```

This lines up with : https://github.com/moby/moby/blob/master/oci/defaults.go#L105

```go
        Linux: &specs.Linux{
            MaskedPaths: []string{
                "/proc/asound",
                "/proc/acpi",
                "/proc/kcore",
                "/proc/keys",
                "/proc/latency_stats",
                "/proc/timer_list",
                "/proc/timer_stats",
                "/proc/sched_debug",
                "/proc/scsi",
                "/sys/firmware",
                "/sys/devices/virtual/powercap",
            },
            ReadonlyPaths: []string{
                "/proc/bus",
                "/proc/fs",
                "/proc/irq",
                "/proc/sys",
                "/proc/sysrq-trigger",
            },
```

1. So the masked paths are overridden with a `tmpfs`. That makes sense, I suppose.
2. The read-only paths are first remounted as a subpath, i.e., we want to make just `/proc/bus` readonly, 
from the orig mount `/proc`. Then, it is again remounted as a readonly mount. Still not sure why two steps are needed. But sure.

```bash
[pid 407998] mount("/proc/bus", "/proc/bus", 0xc0001d724a, MS_BIND|MS_REC, NULL) = 0
[pid 407998] mount("/proc/bus", "/proc/bus", 0xc0001d726a, MS_RDONLY|MS_NOSUID|MS_NODEV|MS_NOEXEC|MS_REMOUNT|MS_BIND, NULL) = 0
```

When running a `--privileged` container, there is no need to hide parts of the `/proc` of `/sys` from the host,
and hence we do not see these masked and readonly paths.
Both `procfs` and `sysfs` are interfaces to the kernel, and they expose both read-only, write, and config options.
However, the way to mount these has no way to specifing not mounting sub-parts, hence we do this extra steps.

# Taking a step back
So far, I have come across the following kernel interfaces:
1. `syscall`: Good old-fashioned way to ask the kernel to do something.
2. `procfs` and `sysfs`: Read, or write kernel data structures.
3. `ioctl`: The proverbial kitchen sink.

And the following ways to restrict them:
1. `user permission`: Enough has been said on this.
2. `Linux Capability`: A way to group syscalls and then enable/disable each group individually.
3. `seccomp`: A way to do more fine-grained control of which syscalls are allowed, that can further tuned by BPF filters.
4. `Hiding parts of /proc and /sys`: This is what we covered in this post.


