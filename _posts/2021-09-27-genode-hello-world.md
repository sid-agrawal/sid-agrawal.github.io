---
layout: posts
title:  "Genode: Running out of capabilities on 64-bit platforms"
date: 2021-09-27
categories: sel4, virtual memory
---

I am using Genode(with seL4) as the OS platform for demonstrating my [research ideas](http://sid-agrawal.ca). As with starting with a new platform I have run into some hurdles.

## Running the hello_tutorial

The hello_tutorial job on qemu did not finish to completing and timed out. Below are my steps on ubuntu 20.04.1. I am using the [Genode development container](https://genodians.org/skalk/2020-09-29-docker-devel), so the tools should not an issue. I also tried it outside the container, with the same result.

```bash
git clone git://github.com/genodelabs/genode.git 
cd genode
tool/ports/prepare_port sel4
tool/ports/prepare_port grub2
tool/create_builddir x86_64
cd x86_64/build/
# Change build/x86_64/etc/build.conf. 
# Change kernel to sel4 and add hello_tutorial
diff etc/build.conf.old etc/build.conf
20c20
< #KERNEL ?= nova
---
> KERNEL ?= sel4
85a86
> REPOSITORIES += $(GENODE_DIR)/repos/hello_tutorial

make
make hello
make run/hello 
```

> This times out as shown below.
> 

```bash
[init -> hello_server] creating root component [0m [0m
[init -> hello_client] upgrading quota donation for PD session (0 bytes, 4 caps) [0m [0m
[init] child "hello_server" requests resources: cap_quota=3 [0m [0m
[init] child "hello_client" requests resources: ram_quota=0, cap_quota=4 [0m [0m
Error: Test execution timed out
```

## Response from Genode Dev

> Thanksfully the Genode Mailing List was able to help out!!
> 

They were able to reproduce the issue and pointed out that the issue is related to the used platform. As the log output states "hello_server" is requesting more resources and requires cap_quota (capability quota) increased during an operation that requires 3 caps. A look into the init configuration (see hello.run) reveals the following.

```xml
<!-- all components get 50 capabilities per default -->
<default caps="50"/>
```

Now you may grant the component some more caps to make it run successully by changing to the hello_server start node and running

```xml
<start name="hello_server" caps="54">
```

```bash
make run/hello KERNEL=sel4
```

This results in additional resource requests

```bash
[init] child "hello_server" requests resources: ram_quota=0, cap_quota=4
```

The reason is that the seL4 platforms works quite different from NOVA and expectedly Linux, which results in a higher capability consumption of the used software stack.

The following start nodes render the scenario working again.

```bash
<start name="hello_server" caps="58">
...
<start name="hello_client" caps="51">
```

Please see Chapters "Resource trading" [1] and "Resource assignment" [2] in the Genode Foundations book for a thorough explanation.

[1] [https://genode.org/documentation/genode-foundations/21.05/architecture/Resource_trading.html](https://genode.org/documentation/genode-foundations/21.05/architecture/Resource_trading.html)

[2] [https://genode.org/documentation/genode-foundations/21.05/system_configuration/The_init_component.html#Resource_assignment](https://genode.org/documentation/genode-foundations/21.05/system_configuration/The_init_component.html#Resource_assignment)