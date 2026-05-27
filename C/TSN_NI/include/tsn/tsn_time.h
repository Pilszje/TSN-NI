#ifndef TSN_TIME_H
#define TSN_TIME_H

#include "types.h"

// RTC and tsu stuff
// // First define offsets
// #define TIME_SYNC_CTRL_BITS_OFFSET 0x70
// // {tsu_rx_q_rd_en, tsu_tx_q_rd_en, rtc_offset_ld, rtc_adj_ld, rtc_period_ld, rtc_time_ld}
// #define RTC_TIME_LOAD_BIT 1<<2
// #define RTC_PERIOD_LOAD_BIT 1<<3
// #define RTC_FINE_LOAD_BIT 1<<4
// #define RTC_OFFSET_LOAD_BIT 1<<5
// #define TSU_RX_RE 1
// #define TSU_TX_RE 1<<1
// #define TSU_RX_EMPTY 1
// #define TSU_TX_EMPTY 1<<1
// #define RTC_TIME_LOAD_OFFSET 0x78
// #define RTC_PERIOD_LOAD_OFFSET 0x84
// #define RTC_FINE_TIME_LOAD_OFFSET 0x8C
// #define RTC_FINE_TIME_PERIOD_OFFSET 0x90
// #define RTC_LOAD_PTP_OFFSET_OFFSET 0x98
// // rtc time outputs
// #define RTC_TIME_PTP_OFFSET 0xA4
// #define RTC_SYNC_TIME_PTP_OFFSET 0xB0
// #define RTC_TIME_PTP_MINI_OFFSET 0xBC
// #define RTC_SYNC_TIME_PTP_MINI_OFFSET 0xC4
// // tsu
// #define TSU_RX_DATA_OFFSET 0x50
// #define TSU_TX_DATA_OFFSET 0x60
// #define TSU_MSGID_MASK_OFFSET 0x74
// #define TSU_MSGID_RX_SHIFT 0
// #define TSU_MSGID_TX_SHIFT 8



// Timestamp struct;
typedef struct {
    u64 seconds;
    u32 nanoSeconds;
} Timestamp_t;
// RTC can do a couple of things
// 1. direct time adjustment: ToD set up
int rtcLoadTime(uptr baseAddress, Timestamp_t time, u8 frac);
// 2. frequency adjustment: frequency set up for drift compensation
typedef struct {
    u8 nanoseconds;
    u32 nsFraction;
} RtcPeriod_t;

int rtcLoadPeriod(uptr baseAddress, RtcPeriod_t period);
// 3. precise time adjustment: small time difference adjustment with a time mark
int rtcFineTimeAdj(uptr baseAddress, RtcPeriod_t period, u32 countDown);
// 4. load offset (compared to synchronized time.)
int rtcLoadPtpOffset(uptr baseAddress, Timestamp_t timeStamp);
// time output: for internal with ns fraction
// Timestamp_t rtcGetLocalTime(uptr baseAddress);
// time output: for external with ptp standard
Timestamp_t rtcGetPtpTime(uptr baseAddress);
// timeoutput: sync ptp time
Timestamp_t rtcGetPtpSyncTime(uptr baseAddress);
u64 rtcGetPtpSyncTimeMini(uptr baseAddress);
u64 getCurTime(uptr baseAddress);

// timestamper reads
// FIFO elements are 128 bits wide and contain: {16'b0,ptp_ts, ptp_msgid, ptp_cksum, ptp_seqid};  // 16+80+4+12+16
// - ptp timestamp      -> 80 bits
// - ptp msgid          -> 4 bits
// - ptp checksum       -> 12 bits
// - ptp sequence id    -> 16 bits
// create a struct for that
typedef struct {
    Timestamp_t timestamp;
    u8 msgId;
    u16 checksum;
    u16 seqId;
} TSUTimestamp_t;

// first a function returning if the queues is empty or not
u32 TSUIsEmpty(uptr baseAddress);


// now a read function 
// will use the same function to read both rx and tx

/*
### Parameters:
- uptr baseAddress:   points to the start address of the TSN EP
    
- u8 TSUQueue:        Which queue to read, 1 for rx and 2 for tx (both not supported)

- TSUTimeStamp_t TSUTimestamp: return value 

### Returns:
- int: Whether a read was successfull or not
*/
int TSURead(uptr baseAddress, u8 TSUQueue, TSUTimestamp_t* TSUTimestamp);

int TSUSetMsgidMasks(uptr baseAddress, u8 rxMask, u8 txMask);

#endif