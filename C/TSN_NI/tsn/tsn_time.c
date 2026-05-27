#include "tsn/tsn_time.h"
#include "tsn/tsn_config.h"
// #include <stdio.h>

// 1. direct time adjustment: ToD set up
int rtcLoadTime(const uptr baseAddress, Timestamp_t time, u8 frac) {
    uptr start = baseAddress + RTC_TIME_LOAD_OFFSET;
    // load the time
    *((volatile u32*)start) = frac + (time.nanoSeconds<<8);
    *((volatile u32*)(start+4)) = ((time.nanoSeconds>>24)&((1<<6)-1)) + ((time.seconds<<6));
    *((volatile u32*)(start+8)) = (u32)(time.seconds>>26);
    // now signal to load
    *((volatile u32*)(baseAddress + TIME_SYNC_CTRL_BITS_OFFSET)) = RTC_TIME_LOAD_BIT;
    return OK;
}
// 2. frequency adjustment: frequency set up for drift compensation
int rtcLoadPeriod(const uptr baseAddress, RtcPeriod_t period) {
    uptr start = baseAddress + RTC_PERIOD_LOAD_OFFSET;
    // order is prolly fraction then nanoseconds
    *((volatile u32*)start) = period.nsFraction;
    *((volatile u32*)(start+4)) = period.nanoseconds;
    // signal to load
    *((volatile u32*)(baseAddress + TIME_SYNC_CTRL_BITS_OFFSET)) = RTC_PERIOD_LOAD_BIT;

    return OK;
}
// 3. precise time adjustment: small time difference adjustment with a time mark
int rtcFineTimeAdj(const uptr baseAddress, RtcPeriod_t period, u32 countdown) {
    uptr start = baseAddress + RTC_FINE_TIME_LOAD_OFFSET;
    *((volatile u32*)start) = countdown;
    *((volatile u32*)(start+4)) = period.nsFraction;
    *((volatile u32*)(start+8)) = period.nanoseconds;
    // signal load
    *((volatile u32*)(baseAddress + TIME_SYNC_CTRL_BITS_OFFSET)) = RTC_FINE_LOAD_BIT;
    return OK;
}

// 4. load offset (compared to synchronized time.)
int rtcLoadPtpOffset(const uptr baseAddress, Timestamp_t offset) {
    uptr start = baseAddress + RTC_LOAD_PTP_OFFSET_OFFSET;
    // load the time
    *((volatile u32*)start) = offset.nanoSeconds;
    *((volatile u32*)(start+4)) = (u32)(offset.seconds & UINT32_MAX);
    *((volatile u32*)(start+8)) = (u32)((offset.seconds>>32) & UINT16_MAX);
    // now signal to load
    *((volatile u32*)(baseAddress + TIME_SYNC_CTRL_BITS_OFFSET)) = RTC_OFFSET_LOAD_BIT;
    return OK;
}

// time output: for internal with ns fraction
// Currently dont have this on a register
// Timestamp_t rtcGetLocalTime(const uptr baseAddress) {
//     Timestamp_t returnVal = {0};
//     return returnVal;
// }
// time output: for external with ptp standard
Timestamp_t rtcGetPtpTime(const uptr baseAddress) {
    Timestamp_t returnVal;
    uptr start = baseAddress + RTC_TIME_PTP_OFFSET;
    // prolly first nanoseconds
    // TODO: is there any way to fix the time?? maybe a freeze time register 
    returnVal.nanoSeconds = *((volatile u32*)start);
    returnVal.seconds = *((volatile u32*)(start+4));
    returnVal.seconds |= ((u64)*((volatile u32*)(start+8)))<<32;

    // ((u64)*((volatile u32*)(start+8)))<<32;

    return returnVal;
}
// timeoutput: sync ptp time
Timestamp_t rtcGetPtpSyncTime(const uptr baseAddress){
    Timestamp_t returnVal;
    uptr start = baseAddress + RTC_SYNC_TIME_PTP_OFFSET;
    // prolly first nanoseconds
    // TODO: is there any way to fix the time?? maybe a freeze time register 
    returnVal.nanoSeconds = *((volatile u32*)start);
    returnVal.seconds = *((volatile u32*)(start+4));
    returnVal.seconds |= ((u64)*((volatile u32*)(start+8)))<<32;
    // ((u64)*((volatile u32*)(start+8)))<<32;
    return returnVal;
}

u64 rtcGetPtpSyncTimeMini(const uptr baseAddress){
    u64 returnVal;
    uptr start = baseAddress + RTC_SYNC_TIME_PTP_MINI_OFFSET;
    // prolly first nanoseconds
    // TODO: is there any way to fix the time?? maybe a freeze time register 
    returnVal = *((volatile u32*)start);
    returnVal += ((u64)*((volatile u32*)(start+4)))<<32;
    return returnVal;
}

u64 getCurTime(const uptr baseAddress){
    u64 returnVal;
    uptr start = baseAddress + CUR_TIME_OFFSET;
    // prolly first nanoseconds
    // TODO: is there any way to fix the time?? maybe a freeze time register 
    returnVal = *((volatile u32*)start);
    returnVal += ((u64)*((volatile u32*)(start+4)))<<32;
    return returnVal;
}

u32 TSUIsEmpty(const uptr baseAddress){
    const uptr regAddr = baseAddress + TIME_SYNC_CTRL_BITS_OFFSET;
    return ((*((volatile u32*)regAddr))) & 0b11; 
}

int TSURead(const uptr baseAddress, u8 TSUQueue, TSUTimestamp_t* TSUTimestamp) {
    // first check if queue is formatted okay
    if (TSUQueue > 2) return E_TSU_BAD_QUEUE;
    // Then check if the queue is empty
    u8 empty = TSUIsEmpty(baseAddress) & TSUQueue;
    if (empty>0) return E_TSU_EMPTY;
    
    // if not empty we can start reading;
    const uptr regAddr = baseAddress + TSU_RX_DATA_OFFSET + (TSUQueue-1)*16;
    u32 tmpRead = *((volatile u32*) regAddr); // this first 32 bits contains: {4'ptp_msgid, 12'ptp_cksum, 16'ptp_seqid}
    TSUTimestamp->seqId = tmpRead & UINT16_MAX;
    TSUTimestamp->checksum = (tmpRead>>16) & 0xFFF;
    TSUTimestamp->msgId = (tmpRead>>(16+12)) & 0xF;
    
    // next three contain the timestamp
    TSUTimestamp->timestamp.nanoSeconds = *((volatile u32*)(regAddr+4));
    TSUTimestamp->timestamp.seconds = *((volatile u32*)(regAddr+4+4));
    TSUTimestamp->timestamp.seconds |= ((u64)*((volatile u32*)(regAddr+4+8)))<<32;

    // signal read enable
    // printf("reVal: %u\n",TSU_RX_RE*(TSUQueue));
    *((volatile u32*)(baseAddress + TIME_SYNC_CTRL_BITS_OFFSET)) = TSU_RX_RE*(TSUQueue); //TSUQueue is either 1 or 2 for rx and tx respectively

    return OK;
}

int TSUSetMsgidMasks(uptr baseAddress, u8 rxMask, u8 txMask) {
    u16 maskVal = (((u16)txMask)<<8) + rxMask;
    // printf("mask: %u\n", maskVal);
    *((volatile u32*)(baseAddress + TSU_MSGID_MASK_OFFSET)) = maskVal;
    return OK;
}
