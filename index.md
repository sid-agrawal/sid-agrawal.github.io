<img src="profile-pic-square.jpg" alt="drawing" height="150"  align="right" >
 

I am a second-year Ph.D. student at the [University of British Columbia](https://www.cs.ubc.ca/) in Canada and a member of the [Systopia Lab](https://systopia.cs.ubc.ca/) here. 
My advisor is [Prof. Margo Seltzer](https://www.seltzer.com/margo/).
I have worked as a [software engineer](https://www.linkedin.com/in/sidhartha-agrawal/) for eight years(Oracle, Arista in Canada and USA) 
and have begun my research journey in Jan 2021. 
In summer of 2022 I interned at [ARM Research](https://veracruz-project.github.io/) working seL4 and CHERI capabilities.
My primary research interest is in operating systems. 

<a id="org6d28e7e"></a>
# Research Projects

## General Purpose Isolation Mechanisms

After sixty years of operating system evolution, we continue to find new and different isolation mechanisms: threads, processes, containers, virtual machines, lightweight contexts. 
Even applications provide isolation mechanisms: a JVM is a user-level process that provides isolation units whose API is Java bytecodes; some browsers offer units of isolation between each browser tab.

We ask whether we really need to have N different isolation mechanisms or, instead, we could develop a framework in which all these different mechanisms represent points on a continuum. 
If we could do that, then perhaps A) we could implement such a unified framework, and B) the framework might allow us to discover new and useful isolation mechanisms (that could be created seamlessly rather than requiring an entirely new implementation).

The project has three main goals:
* Develop a theoretical model or framework to unify existing isolation mechanisms.
* Identify novel points in the model that are useful.
* Implement the model in seL4.

Below is an example on how we can view memory as a resource that be shared and isolated across different types of protection domains.
This is an evolving diagram, as we are still investigating if the "Security and Performance Guarantees" across any two
types of protection domains can be compared.

![image](memory-model.png)

## Conferences Attended
* [HPTS 2022](http://hpts.ws/index.html), Monterey, California, USA (Invitation Only)
* [Hot Carbon 2022](https://hotcarbon.org/), San Diego, California, USA
* [OSDI 2022](https://www.usenix.org/conference/osdi22), San Diego, California, USA
* [SOSP 2021](https://sosp2021.mpi-sws.org/): Virtually
* [HotOS 2021](https://sigops.org/s/conferences/hotos/2021/): Virtually

<a id="org538e7d9"></a>
## Coursework
- CPSC 508: Graduate Operating Systems [www](<https://www.seltzer.com/margo/teaching/CS508.21/index.html>)
- EEL 571S: Techniques for Simulating Novel Hardware Architectures in the Context of OS Research [www](<https://docs.google.com/document/d/1EAniq36LdA8tReo9KYm-bTFcrvbMwkutUSN8KiLYIiU/edit#heading=h.bdy4i2cqmbbn>)
- CPSC 513: Formal Verification [www](<https://www.cs.ubc.ca/~ajh/courses/cpsc513/index.html>)
- CPSC 538M: Security and Privacy in the Era of Side Channels(Audit) [www](<https://aasthakm.github.io/courses/cpsc538m.html>) 
- CPSC 538A: Operating Systems Design and Implementation using Barrelfish [www](<https://www.cs.ubc.ca/~achreto/teaching/538/>)

<a id="org2825255"></a>
# Contact
-   sid[at]sid-agrawal[dot]ca
