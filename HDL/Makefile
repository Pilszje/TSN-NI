WNO = -Wno-UNUSEDPARAM -Wno-PINCONNECTEMPTY -Wno-UNUSEDSIGNAL  -Wno-UNDRIVEN
# WNO = 
INCLUDE_DIR = -y EP/*/ -y EP/*/*/ -y EP/ -y TB -y taxi_mac
TOP_FILE = TB/test.sv
EXTRA_ARGS = +1364-2005ext+v2005

VERILATOR_ARGS = --binary -j 0 -Wall -o out --trace -fno-dead-assigns  $(WNO) $(INCLUDE_DIR)

queues: TOP_FILE = TB/output_queues_tb.sv
queues : build_generic

queues_mem: TOP_FILE = TB/output_queues_mem_tb.sv
queues_mem : build_generic

test_logic : TOP_FILE = TB/test_logic_tb.sv
test_logic : build_generic

list_execute : TOP_FILE = TB/list_execute_sm_tb.sv
list_execute : build_generic

calc_start_cycle : TOP_FILE = TB/calc_start_cycle_tb.sv
calc_start_cycle : build_generic

cycle_timer_sm : TOP_FILE = TB/cycle_timer_sm_tb.sv
# cycle_timer_sm : TOP_FILE = EP/cycle_timer_sm.sv
cycle_timer_sm : build_generic

list_config : TOP_FILE = TB/list_config_sm_tb.sv
list_config : build_generic

transmission_selection : TOP_FILE = TB/transmission_selection_tb.sv
transmission_selection : build_generic

transmission_selection_sm : TOP_FILE = TB/transmission_selection_sm_tb.sv
transmission_selection_sm : build_generic

axis_width_conv_down : TOP_FILE = TB/axis_width_conv_down_tb.sv
axis_width_conv_down : build_generic

axis_width_conv_up : TOP_FILE = TB/axis_width_conv_up_tb.sv
axis_width_conv_up : build_generic

axis_up_down_test : TOP_FILE = TB/axis_up_down_test_tb.sv
axis_up_down_test : build_generic

ep : TOP_FILE = TB/TSN_ep_tb.sv
# ep : WNO += -Wno-UNDRIVEN
ep : WNO += -Wno-SYNCASYNCNET -Wno-BLKSEQ -Wno-UNDRIVEN -Wno-GENUNNAMED -Wno-PROCASSINIT
ep : build_generic

ep_lmb : TOP_FILE = TB/TSN_ep_lmb_tb.sv
# ep_lmb : WNO += -Wno-UNDRIVEN
ep_lmb : WNO += -Wno-SYNCASYNCNET -Wno-BLKSEQ -Wno-UNDRIVEN -Wno-GENUNNAMED -Wno-PROCASSINIT
ep_lmb : build_generic

easyaxil : TOP_FILE = EP/easyaxil.sv
easyaxil : build_generic

# mac_1g : TOP_FILE = taxi_mac/mac_1g_top_wrapper.v
# mac_1g : build_generic

fifo : TOP_FILE = TB/fifo_tb.sv
fifo : build_generic

fifo_async : TOP_FILE = TB/fifo_async_tb.sv
fifo_async : build_generic

mac : TOP_FILE = TB/mac_tb.sv
mac : WNO += -Wno-SYNCASYNCNET -Wno-BLKSEQ -Wno-UNDRIVEN -Wno-GENUNNAMED -Wno-PROCASSINIT
mac : build_generic

test : TOP_FILE = TB/test.sv
test : build_generic

rtc : TOP_FILE = TB/rtc_tb.sv
rtc : build_generic

tsu_rgmii : TOP_FILE = TB/tsu_rgmii_tb.sv
tsu_rgmii : build_generic

tsu_gmii : TOP_FILE = TB/tsu_gmii_tb.sv
tsu_gmii : build_generic

rgmii_to_sdr_1g : TOP_FILE = TB/rgmii_to_sdr_1g_tb.sv
rgmii_to_sdr_1g : build_generic

axis_qvlan_up_conv : TOP_FILE = TB/axis_qvlan_up_conv_tb.sv
axis_qvlan_up_conv : build_generic

input_queues : TOP_FILE = TB/input_queues_tb.sv
input_queues : build_generic

axis_ts_probe : TOP_FILE = TB/axis_ts_probe_tb.sv
axis_ts_probe : build_generic

pkt_gen : TOP_FILE = TB/pkt_gen_tb.sv
pkt_gen : build_generic

lmb_test : TOP_FILE = TB/lmb_test_tb.sv
lmb_test : build_generic

fan_ctl : TOP_FILE = TB/fan_ctl_tb.sv
fan_ctl : build_generic


build_generic : 
	verilator $(TOP_FILE) $(VERILATOR_ARGS)  

run : 
	./obj_dir/out

gtkwave :
	gktwave obj_dir/out.vcd
clean:
	rm -r obj_dir
	rm vcd/*