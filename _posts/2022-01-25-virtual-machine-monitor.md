---
layout: posts
title:  "Virtual Machine Core Idea"
date: 2022-01-25
categories: virtual machine, hypervisor, vt-x 
---


While trying to find tutorials on how to implement a simple hypervisor,
most of the articles I found online were about using Intel's VT-X extensions --
called `Hardware extensions for virtualization` to implement a Virtual machine [1].
However, the idea of a virtual machine is so much older than the hardware extensions meant to make
virtualization more accessible. So, I wanted to get to the crux of what we are virtualizing
and how. Then later, see how hardware extensions for virtualization make it either easier
or speed things up.

I realized that the answer lies in how host OS deals with faults inside the process. If the faults
are handled a certain way, the process is running a normal application. If the fault is handled in
a slightly more complicated way - more on that below - it is a virtual machine.

This is an overly simplified view of things, and I intend to update this post as my understanding
evolves.

# Running an application
When we are running a normal application in the process -- and not a VM -- the OS needs to handle faults generated by the process, and it has to forward the appropriate interrupts to the process.

```c
switch exception_type:
	case syscall:
		do the right
		// This will start the user process at the next instruction. thing
		syscall_ret
	case page_fault:
		map the page
		restart from the faulting instruction
	case [... other signals ...]:
		[... other appropriate actions ...]
	default:
		kill the process
```

## VM scenario 1/3: Running on the same ISA but with no hardware extensions

In this scenario, the process is running a virtual machine. So, when the process executes a
privileged instruction the OS -- we will say host OS going forward -- will have to handle
it gracefully.

But!! Depending on whether the virtual machine is running the guestOS or a
user-process at a given instant, the response from the OS will have to be different.
That's why the host OS needs to maintain some additional state about the CPU running
the VM. This additional state is denoted by the dictionary `cpu_state` below.

Furthermore, there are certain actions that the processor does automatically, which have to be
mimicked by the host OS. For instance, when a user process issues a system call. The processor
automatically switches the address space and sets the kernel bit in the CPU. Similarly,
when the kernel returns from the system call, the hardware automatically switches back to
the user's address space and unsets the kernel bit in the CPU.

Systems calls and page faults are exceptions generated inside the VM going outward. But we also
need to consider how interrupts generated outside the VM will be guided to the guestOS or the
process inside the VM. When OS boots up - or some early on - it sets up the interrupt vector
table(IVT), which dictates where are the handlers for each type of interrupt. When the guest OS sets up the interrupt vector table, the host OS will intercept these requests and instead maintain a shadow IVT. Then when an interrupt needs to be sent to the VM, the host OS can change the IP of
the guest OS to that address stored in the IVT.

```c
// For each CPU, we need to maintain some state
dict cpu_state_type_1 {
   kernel_mode: true,
   cr3: bit-value, // root page table in Intel.
   IVT: {interruptID: starting address of handler}.
   [...]  // other privileged state
}

switch fault_type:
	case syscall:
		if vCPU_in_kernel_mode() {
			 // This shouldn't have happened, when the CPU is in kernel mode.
			 kill it
		} else {
			// change the vCPU to reflect that it is now in kernel mode.			
			set_vCPU_kernel_mode()
			restart app from kernel's syscall handler
		}
	 case syscall_ret:
		if vCPU_in_kernel_mode() {
			unset_vCPU_kernel_mode()
			restart app from 
		} else {
			    // this shouldn't have happened.
				kill it 
		}
	case update_cr3:
		if vCPU_in_kernel_mode() { // guestOS is manipulating PT
			update_cr3
            restart app from next instruction
		} else {
			kill it // this shouldn't have happened.
		}
    case page_fault:
		if vCPU_in_kernel_mode() { // The guestOS needs more guest physical memory.
			handle fault
	        restart VM from same instruction
		} else {	// A process inside the guestOS needs more physical memory.
	 		set kernel mode bit
			restart VM with IP set to guestOS's page fault handler
		}
	default:
		kill the process
```

## VM scenario 2/3: Running on the same ISA but with hardware extensions
In Intel with VT-x - Intel's version of hardware extensions for virtualization, there is root and non-root mode. The HV is meant to run in the root 
mode and the guestOS in the non-root mode. For the most part, in the non-root mode, the guestOS proceeds as if it was running on bare-metal. 
Access to privelaged state like CR3 register are not trapped to the HV.

This would mean that when the guest OS is executing, very few things will cause the hypervisor to get involved.
But someone (or something) still needs to keep track of the vCPU state, that burden is not shifted from the HV to the hardware.
When setting up the guestOS, the HV allocated a region of memory for saving the VM's information called the `guest area`. 
You can think of this as the `cpu_state` structure from above. The VMCS (Virtual Machine Control Structure) is a in-memory 
datastructure per VM, and it has pointer to the guest area.

I hope you can see where this is going. Now when a process inside the guestOS has a pagefault, the HV is no longer invoked,
the transition of the cVPU to kernel mode and the jump to the guest page-fault handler is automatically done by the hardware
based on the info in the `guest area`. Same is the case for other instructions executed inside the VM like `syscall`.

The HV still does get involved for other types of faults, for instance if the guestOS needs more guest physical memory.
That can also be automated by using Extended Page Tables(EPT), but we won't be talking about that. Rest assured, the HV
still has a role to play and still needs to maintain some state, but the function is reduced thanks to the hardware extensions.


```c
dict cpu_state_type2{
   // Some of this now managed by VMCS.
   [..]  // other priv state
}

switch fault_type:
	case VMEXIT: // 
		read the VMCS to find out the fault info
		resolve fault
		VMRESUME
	default:
			kill the process
```


## VM scenario 3/3: Running on a different ISA
This is mentioned here for posterity and quite different from the other two types of VM.
In this scenario, the instruction either privileged or not, are not run of the hardware because 
they are off a different arch. You cannot run ARM instructions on Intel hardware. 
So a simulator(for instance, QEMU[2]) reads the instructions one by one and simulates 
each one. The simulator maintains the complete state of the user-visible hardware. In reality, 
there are optimizations for translations that cache them. But for 
simplicity, think of it as one instruction is simulated using a simulator written in C/C++.



[1] [https://nixhacker.com/developing-hypervisior-from-scratch-part-1/](https://nixhacker.com/developing-hypervisior-from-scratch-part-1/) 

[2][QEMU](https://www.qemu.org/)



### Update history
* 25-01-2022: Original post 