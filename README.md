# TSN-NI
This project contains the (System)Verilog hardware description for a TSN capable Ethernet network interface, currently implementing Time-Aware Shaping (TAS), along with a small software library for interfacing with it.

## Structure
Any software can be found in <code>c/</code>. 
Any hardware can be found in <code>HDL/</code>

## Building hardware
Note: Hardware has only been tested on an AMD Kria KR260 development board. 
<code>HDL/EP/TSN_ep.v</code> contains the top-level module of the network interface, which can be added to Vivado as a verilog module.\
### Ports
- two AXIS interfaces for Ingress and Egress traffic to/from the MAC
- Two GMII interfaces for sniffing PTP traffic between PHY and MAC
- AXI-lite interface for access from the host.


## Software
Software for the network interface consists of a library split over a number of include files.


## TODO
- [ ] Expand documentation
- [ ] Clean up the repo
- [ ] Optimizations
