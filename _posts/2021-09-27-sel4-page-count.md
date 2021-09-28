---
layout: posts
title:  "seL4: Page count mismatch in sel4utlils vpace library"
date: 2021-09-27
categories: sel4, virtual memory
---

I was looking at the [sel4utils/vspace](https://github.com/seL4/seL4_libs/tree/master/libsel4utils) library and 
noticed a mismatch in the number of pages allocated as per the two data structures which keep track of the 
address space. Below I have laid out my test setup, steps to reproduce and finally the exact questions.

In my test setup(which is copied from `sel4test` system), the root task(driver) starts another process(test app) 
using `sel4utils_spawn_process_v`.(inside basic_run_test). Then in the root task we do a walk of the child task's 
address space structures maintained by `sel4utils/vspace` library. 

The 2 structures I am walking are:
- The linked list of reservations: [src](https://github.com/seL4/seL4_libs/blob/master/libsel4utils/include/sel4utils/vspace.h#L76): 
Here we traverse a linked list and count the number of pages which have been allocated.
- The tree which keeps the caps of pages mapped so far(sort of like the shadow page table). 
[src](https://github.com/seL4/seL4_libs/blob/master/libsel4utils/include/sel4utils/vspace.h#L71). 
Here we traverse the multi-level shadow page table hierarchy to count the pages the library has mapped.

I find that the number of pages I get from the 2 walks are not equal. I understand that neither of 
the above are reflective of the true state of the address space as that is only known to the kernel. So, 
it is simply possible that in some code path, the library inserts an entry in to one of the structures 
and not the other. I have used Intel 32-bit platform to keep the page table structure simple for this query.

Here is the code to walk the [vspace](https://github.com/sid-agrawal/seL4_libs/blob/0d37c61f89dc335a5905f5625be3125e2afe42f3/libsel4utils/src/vspace/vspace.c#L903):

```c
int sel4utils_walk_vspace(vspace_t *vspace, vka_t *vka) {
    sel4utils_alloc_data_t *data = get_alloc_data(vspace);

    int index = 0;
    sel4utils_res_t *sel4_res = data->reservation_head;

    printf("===========Start of interesting output================\n");
    printf("VSPACE_NUM_LEVELS %d\n", VSPACE_NUM_LEVELS);
    
    /* walk all the reservations */
    printf("\nReservations from  sel4utils_alloc_data->reservation_head:\n");
    while (sel4_res != NULL) {
        long int sz = (sel4_res->end - sel4_res->start ) / (4 * 1024);
        printf("\t[%d] %p->%p %lu pages malloced(%u)\n", index, sel4_res->start, sel4_res->end, sz, sel4_res->malloced);
        index++;
        sel4_res = sel4_res->next;
    }

    int num_empty = 0;
    int num_reserved =0;
    int num_used =0;
    int i = 0;

    /* Walk all the page tables */
    printf("\n\nIntel-32 Page Table Hierarcy from sel4utils_alloc_data->top_level->table \n");
    if (data->top_level)
    {
        for (i = 0; i < BIT(VSPACE_LEVEL_BITS); i++)
        {
            if (data->top_level->table[i] == RESERVED)
            {
                num_reserved++;
            }
            else if (data->top_level->table[i] == EMPTY)
            {
                num_empty++;
            }
            else
            {
                num_used++;
                vspace_bottom_level_t *bottom_table = (vspace_bottom_level_t *)data->top_level->table[i];

                int L2_num_empty = 0;
                int L2_num_reserved = 0;
                int L2_num_used = 0;
                int ii = 0;
                for (ii = 0; ii < BIT(VSPACE_LEVEL_BITS); ii++)
                {
                    uintptr_t cap = bottom_table->cap[ii];

                    if (cap == RESERVED)
                    {
                        L2_num_reserved++;
                    }
                    else if (cap == EMPTY)
                    {
                        L2_num_empty++;
                    }
                    else
                    {
                        L2_num_used++;
                    }
                }
                printf("PDE-Index(%d) \n\t" \
                       "NUM-PTE: %5d Empty: %5d \tReserved: %5d \tUsed: %5d\n",
                       i, ii, L2_num_empty, L2_num_reserved, L2_num_used, ii);
            }
        }
        printf("===========Start of interesting output================\n");
        //printf("L1\t E: %d R: %d U: %d Count: %d\n", num_empty, num_reserved, num_used, i);
    }
     return index;
}
```

Test Environment:

- The docker environment was set up using instruction from [Using Docker for seL4](https://docs.sel4.systems/projects/dockerfiles/).
- QEMU on Ubuntu 20.04 on 64-bit Intel machine

Below is the steps to reproduce the issue:

```bash
# Setup the project using a manifest repo. 
# The structure of the project is borrowed from sel4test.
# The manifest points two repo's which are not original sel4 repos:

# - seL4_libs: The new walker helper is here
# - sel4-gpi: The test code is here

mkdir sel4-gpi-system
cd sel4-gpi-system
repo init -u https://github.com/sid-agrawal/sel4-gpi-manifest -b refs/tags/v3.0 
repo sync
container # Jump to the docker sel4 dev environment, omit if you do not care
mkdir build  
cd build
../init-build.sh -DPLATFORM=ia32 -DSIMULATION=TRUE 
ninja  && ./simulate

# To exit Qemu
Ctrl-A X
```

The output from the test code is:

```bash
===========Start of interesting output================
VSPACE_NUM_LEVELS 2

Reservations from  sel4utils_alloc_data->reservation_head:
        [0] 0x10001000->0x10012000 17 pages malloced(1)

Intel-32 Page Table Hierarcy from sel4utils_alloc_data->top_level->table 
PDE-Index(32) 
        NUM-PTE:  1024 Empty:   637     Reserved:     0         Used:   387
PDE-Index(64) 
        NUM-PTE:  1024 Empty:  1005     Reserved:     1         Used:    18
===========Start of interesting output================
```

The first part of the output shows the size of the reservation is a number of 4 KB pages which is 17 pages.  
We see that the vspace has only 1 reservation which is 17 pages long and is malloced.  This itself is a little 
odd; I was expecting multiple reservations for code, stack, RO-data etc.

The second part of the output shows the page directory and table entries. Here we see that the 2 
PDE are in use with a total of 405(18 + 387) PTEs used in total.

### Questions
Why is there is a discrepancy in the number of pages used?
- Does the library allocate a bunch of pages(387) which do not belong to any reservation?
- As far as the single page difference of 17 Vs 18 can be explained by the 
  driver sharing a page with the test-app.

### Answer
I will update the answers as I find them. :-)