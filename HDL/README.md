This folder contains the hardware description for the network interface in <code>EP/</code> and accompanying testbenches in <code>TB/</code>.
Testbenches can be simulated with Verilator using the <code>Makefile</code>.

# File descriptions
|Name|Description|
|----|-----------|
|<code>axis_qvlan_up_conv.sv</code>|Widens an AXIS stream and extracts the PCP field if Q-tag is present in the frame|
|<code>axis_width_conv_down.sv</code>|Narrows an AXIS stream|
|<code>cycle_timer_sm.sv</code>|Implementation of the Cycle Timer state machine as seen in 8.6.9.1 of 802.1Q|
|<code>easyaxil.sv</code>|AXI-Lite slave interface, containing configuration registers and access to I/O. Courtesy of ZipCPU|
|<code>easylmb.sv</code>|Adaption of <code>easyaxil</code> for the LMB seen on a Microblaze|
|<code>fan_ctl_reg.sv</code>|Simple PWM controller to control the annoyingly loud Kria fan|
|<code>fifo_async.sv</code>|Asynchronous FIFO for clock domain crossing|
|<code>fifo_fallthrough.sv</code>|First-Word-Fall-Through (FWFT) FIFO which immediately presents data, once it is available|
|<code>fifo.sv</code>|just a FIFO|
|<code>guardband.sv</code>|Calculates for each egress queue, whether the next frame still fits within the current gate entry|
|<code>input_queues.sv</code>|Ingress queues, per priority|
|<code>list_config_sm.sv</code>|Implementation of the List Config state machine as seen in 8.6.9.3 of 802.1Q|
|<code>list_execute_sm.sv</code>|Implementation of the List Execute state machine as seen in 8.6.9.3 of 802.1Q|
|<code>output_queues_mem.sv</code>|Egress queues, one per priority|
|<code>pkt_gen.sv</code>|A simple packet generator for testing purposes|
|<code>simple_dual_bram.v</code>|RAM generator (hopefully)|
|<code>skidbuffer.v</code>|AXI-lite optimization, courtesy of ZipCPU|
|<code>transmission_selection_sm.sv</code>|Implements the Scheduled traffic state machines, as seen in 8.6.9 of 802.1Q|
|<code>transmission_selection.sv</code>|Top level of the TAS scheduler|
|<code>ts_probe.sv</code>|captures timestamp on a trigger. For testing and debug purposes|
|<code>TSN_ep_lmb.v</code>|Top-level module using the LMB bus|
|<code>TSN_ep.v</code>|Top-level module using the AXI-lite interface|
|<code>time_sync/ptp_parser_axis.v</code>|AXIS version of the PTP parser|
|<code>time_sync/ptp_parser.v</code>|Parses PTP frames to extract metadata and attach a timestamp|
|<code>time_sync/ptp_queue.v</code>|Queue to store PTP frame metadata and timestamps|
|<code>time_sync/super_rtc.sv</code>|Real-Time Clock|
|<code>time_sync/time_sync_hw.sv</code>|Top-level of all time synchronization hardware|
|<code>time_sync/tsu_axis.v</code>|TimeStamper Unit: Sniffs an ingress/egress AXIS interface for PTP frames and places frame metadata along with a timestamp into a queue|
|<code>time_sync/tsu_gmii.sv</code>|Same as above, but sniffing GMII instead of AXIS|


# TODO
- [ ] Check code documentation
- [ ] combine two version of the top level module into one
- [ ] general cleanup
- [ ] Look for optimization possibilities
