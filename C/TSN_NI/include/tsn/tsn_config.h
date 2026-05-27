#ifndef TSN_CONFIG_H
#define TSN_CONFIG_H


// QBV definitions
#define GCL_LENGTH 16
#define GCL_LENGTH_WIDTH 4
#define NUM_QUEUES 8
// address offsets
#define FLAGS_GATES_OFFSET 0x0
#define ADMIN_BASE_TIME_0_OFFSET 0x4
#define ADMIN_BASE_TIME_1_OFFSET 0xC
#define ADMIN_CYCLE_TIME_0_OFFSET 0x14
#define ADMIN_CYCLE_TIME_1_OFFSET 0x1C
#define ADMIN_CYCLE_TIME_EXT_0_OFFSET 0x24
#define ADMIN_CYCLE_TIME_EXT_1_OFFSET 0x2C
#define ADMIN_CTRL_LIST_LEN_OFFSET 0x34
#define MEDIA_DEP_OVERHEAD_OFFSET 0x3C
// read only
#define WR_STATUS_CFG_CHG_ERR_OFFSET 0x38
#define CUR_GCL_ENTRY_OFFSET 0x40
#define CUR_TIME_OFFSET 0x44
// start of schedule
#define ADMIN_CTRL_LIST_0_OFFSET 0x400
#define ADMIN_CTRL_LIST_1_OFFSET (ADMIN_CTRL_LIST_0_OFFSET + (GCL_LENGTH*4))

// I/O queues definitions
// queue parameters
#define QUEUE_DEPTH 10
// write queues
#define WR_MEM_START_OFFSET 0x8000
#define WR_MEM_SIZE         0x8000 // in bytes
#define WR_QUEUE_SIZE       0x1000 // in bytes
#define WR_QUEUE_LEN_OFFSET 0x100
#define WR_QUEUE_LEN_WE_OFFSET 0xD8
// metadata base
#define WR_QUEUE_METADATA_OFFSET 0xE0

// read queues
#define R_MEM_START_OFFSET  0x10000
#define R_MEM_SIZE          0x8000 // in bytes
#define R_QUEUE_SIZE        0x1000 // in bytes
#define R_QUEUE_LEN         1024 // in words
#define R_QUEUE_DONE_OFFSET 0x140
#define R_EMPTY_OFFSET      0x140
#define R_QUEUE_METADATA_OFFSET 0x120
// Reads the length of current packet
#define R_QUEUE_LEN_OFFSET 0x0

#define IQ_MD_START_ADR_OFFSET 0
#define IQ_MD_START_ADR_WIDTH QUEUE_DEPTH
#define IQ_MD_START_LAST_BYTES_OFFSET QUEUE_DEPTH
#define IQ_MD_START_LAST_BYTES_WIDTH 2
#define IQ_MD_START_LEN_WORDS_OFFSET (IQ_MD_START_LAST_BYTES_OFFSET + IQ_MD_START_LAST_BYTES_WIDTH)
#define IQ_MD_START_LEN_WORDS_WIDTH 9
#define IQ_MD_START_EMPTY_OFFSET (IQ_MD_START_LEN_WORDS_OFFSET + IQ_MD_START_LEN_WORDS_WIDTH)

// rtc and tsu definitions
// First define offsets
#define TIME_SYNC_CTRL_BITS_OFFSET 0x70
// {tsu_rx_q_rd_en, tsu_tx_q_rd_en, rtc_offset_ld, rtc_adj_ld, rtc_period_ld, rtc_time_ld}
#define RTC_TIME_LOAD_BIT 1<<2
#define RTC_PERIOD_LOAD_BIT 1<<3
#define RTC_FINE_LOAD_BIT 1<<4
#define RTC_OFFSET_LOAD_BIT 1<<5
#define TSU_RX_RE 1
#define TSU_TX_RE 1<<1
#define TSU_RX_EMPTY 1
#define TSU_TX_EMPTY 1<<1
#define RTC_TIME_LOAD_OFFSET 0x78
#define RTC_PERIOD_LOAD_OFFSET 0x84
#define RTC_FINE_TIME_LOAD_OFFSET 0x8C
#define RTC_FINE_TIME_PERIOD_OFFSET 0x90
#define RTC_LOAD_PTP_OFFSET_OFFSET 0x98
// rtc time outputs
#define RTC_TIME_PTP_OFFSET 0xA4
#define RTC_SYNC_TIME_PTP_OFFSET 0xB0
#define RTC_TIME_PTP_MINI_OFFSET 0xBC
#define RTC_SYNC_TIME_PTP_MINI_OFFSET 0xC4
// rtc sync mode
#define RTC_SYNC_MODE_REG_OFFSET 0x1B8

// tsu
#define TSU_RX_DATA_OFFSET 0x50
#define TSU_TX_DATA_OFFSET 0x60
#define TSU_MSGID_MASK_OFFSET 0x74
#define TSU_MSGID_RX_SHIFT 0
#define TSU_MSGID_TX_SHIFT 8

// pktGen
#define PKT_GEN_PARAMS_OFFSET 0x1A8
#define PKT_GEN_INTERVAL_OFFSET 0x1AC
#define PKT_GEN_OK_TRANS_OFFSET 0x1B0
#define PKT_GEN_NOK_TRANS_OFFSET 0x1B4

// 0x19C		->(r/w)	{genBurstlen,genWQueue,genLength,genRstnStats,genAllQueues,genEnabled,genLoadParams}
#define PKT_GEN_PARAMS_LOAD_IDX 0
#define PKT_GEN_PARAMS_ENABLED_IDX 1
#define PKT_GEN_PARAMS_OTHERQUEUE_IDX 2
#define PKT_GEN_PARAMS_RSTSTATS_IDX 3
#define PKT_GEN_PARAMS_PKTLEN_IDX 4
#define PKT_GEN_PARAMS_QUEUE_IDX (PKT_GEN_PARAMS_PKTLEN_IDX + 9)
#define PKT_GEN_PARAMS_BURSTLEN_IDX (PKT_GEN_PARAMS_QUEUE_IDX + 3)

// handle definitions
#define NUM_HANDLES NUM_QUEUES

// ts probes
#define NUM_TS_PROBES           12
#define IN_TS_PROBE_IDX         0 
#define IQ_TS_PROBE_IDX         1 
#define IQ_DONE_TS_PROBE_IDX    2 
#define OQ_TS_PROBE_IDX         3 
#define TS_TS_PROBE_IDX         4 
#define WC_TS_PROBE_IDX         5 
#define OUT_TS_PROBE_IDX        6
#define OUT_DONE_TS_PROBE_IDX   7
#define GATE_TS_PROBE_IDX       8
#define EXT_PROBE_IDX           9
#define TX_MAC_PROBE_IDX       10
#define RX_MAC_PROBE_IDX       11


#define TS_PROBE_VALID_RE_OFFSET    0x200
#define TS_PROBE_TS_OFFSET          0x204
#define TS_PROBE_TS_WIDTH           3

// debug regs
#define SM_STATUS_OFFSET    0x1E4
#define DEBUG_OQ_OFFSET     0x1E8
#define DEBUG_TS_OFFSET     0x1EC
#define DEBUG_WC_OFFSET     0x1F0
#define DEBUG_INT_OFFSET    0x1F4
#define DEBUG_OUTW_OFFSET   0x1F8
#define DEBUG_OUT_OFFSET    0x1FC

// return values
#define OK 0
#define E_WR_STATUS 1
#define E_GATE_ENABLED 2
#define E_SPACE_LEFT 3
#define E_R_EMPTY 4
#define E_TSU_EMPTY 5 // TSU queue is empty
#define E_TSU_BAD_QUEUE 6 // TSU queue is formatted wrong
#define E_DATA_LEN 7
#define E_WRONG_HANDLE 8
#define E_INCOMPATIBLE_PROT 9
#define E_INVALID_SCHED_IDX 10
#define E_TS_PROBE_INVALID 11


#endif