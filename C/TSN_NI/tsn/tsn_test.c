#include "tsn/tsn_test.h"
#include "tsn/tsn_config.h"
// #include "stdio.h"

// checking if probes are valid
u32 getTsProbeValid (uptr baseAddr) {
    // read from valid 
   return *((volatile u32*) (baseAddr + TS_PROBE_VALID_RE_OFFSET)); 
}

// reading from a ts probe
void readTsProbe (uptr baseAddr, u8 probeIdx, Timestamp_t* ts) {
    // Timestamp_t returnVal;
    // first read the three registers
    uptr start = baseAddr + TS_PROBE_TS_OFFSET + 4*(TS_PROBE_TS_WIDTH*probeIdx);
    // if (probeIdx==OUT_DONE_TS_PROBE_IDX) start = baseAddr + TS_PROBE_OUT_DONE_OFFSET;
    // printf("addr: %X\n", TS_PROBE_TS_OFFSET + 4*(TS_PROBE_TS_WIDTH*probeIdx));
    ts->nanoSeconds = *((volatile u32*)start); 
    ts->seconds = *((volatile u32*)(start+4));
    ts->seconds |= ((u64)*((volatile u32*)(start+8)))<<32;
    // printf("ns: %u\n", ts->nanoSeconds);
    // printf("s: %lu\n", ts->seconds);

    // then do read enable on the idx
    *((volatile u32*)(baseAddr + TS_PROBE_VALID_RE_OFFSET)) = 1<<probeIdx;
    return;
}
// reading from a ts probe
u64 readSmallTsProbe (uptr baseAddr, u8 probeIdx) {
    // Timestamp_t returnVal;
    // first read the three registers
    u64 ts = 0;
    uptr start = baseAddr + TS_PROBE_TS_OFFSET + 4*(TS_PROBE_TS_WIDTH*probeIdx);
    // if (probeIdx==OUT_DONE_TS_PROBE_IDX) start = baseAddr + TS_PROBE_OUT_DONE_OFFSET;
    // printf("addr: %X\n", TS_PROBE_TS_OFFSET + 4*(TS_PROBE_TS_WIDTH*probeIdx));
    ts = *((volatile u32*)start); 
    ts |= ((u64)*((volatile u32*)(start+4)))<<32;
    // ts->seconds |= ((u64)*((volatile u32*)(start+8)))<<32;
    // printf("ns: %u\n", ts->nanoSeconds);
    // printf("s: %lu\n", ts->seconds);

    // then do read enable on the idx
    *((volatile u32*)(baseAddr + TS_PROBE_VALID_RE_OFFSET)) = 1<<probeIdx;
    return ts;
}

u64 readSmallPTP (uptr baseAddr) {
    uptr start = baseAddr + RTC_TIME_PTP_OFFSET;
    u64 ts;
    ts = *((volatile u32*)start);
    ts += ((u64)*((volatile u32*)(start+4)))<<32;
    return ts;
}

// getting all timestamp probes
int getTsProbes (uptr baseAddr, Timestamp_t* timestamps) {
    // first check if all timestamps are valid
    const u32 valid = getTsProbeValid(baseAddr);
    if (valid < ((1<<6)-1)) {
        // printf("not all probes valid: 0x%02lX", valid);
        return E_TS_PROBE_INVALID;
    }
    // then read them all
    for (int i = 0; i < NUM_TS_PROBES; i++) {
        readTsProbe(baseAddr, i, timestamps+i);
    }
    return OK;
}

// pkt gen stuff
void pktGenSetParams(uptr baseAddr, u32 interval, u16 lenWords, u8 queue, u8 otherQueue, u8 burstLen) {
    uptr startAddr = baseAddr + PKT_GEN_PARAMS_OFFSET;
    // 0x190 ->(r/w) {genBurstlen,genWQueue,genLength,genRstnStats,genotherQueue,genEnabled,genLoadParams}
    u32 oldVal = *((volatile u32*) startAddr);
    u32 val = 1 + (oldVal & (1<<PKT_GEN_PARAMS_ENABLED_IDX)) + // enabled bit
            ((otherQueue>0)<<PKT_GEN_PARAMS_OTHERQUEUE_IDX) + // 
            ((lenWords & 0x1FF)<<PKT_GEN_PARAMS_PKTLEN_IDX) +
            ((queue&0b111)<<PKT_GEN_PARAMS_QUEUE_IDX) +
            (burstLen<<PKT_GEN_PARAMS_BURSTLEN_IDX);
    *((volatile u32*)(startAddr+4)) = interval;
    *((volatile u32*)startAddr) = val;
    // printf("params val: %08X\n", val);
    // printf("len: %X\n", (lenWords & 0x1FF)<<PKT_GEN_PARAMS_PKTLEN_IDX);
    return;
}

void pktGenEnable(uptr baseAddr) {
    uptr startAddr = baseAddr + PKT_GEN_PARAMS_OFFSET;
    *((volatile u32*)startAddr) |= (1<<PKT_GEN_PARAMS_ENABLED_IDX) + 1;
    return;
}
void pktGenDisable(uptr baseAddr) {
    uptr startAddr = baseAddr + PKT_GEN_PARAMS_OFFSET;
    u32 val = *((volatile u32*)startAddr) & (UINT32_MAX - (1<<PKT_GEN_PARAMS_ENABLED_IDX));
    *((volatile u32*)startAddr) = (val | 1);
    return;
}

void pktGenResetStats(uptr baseAddr) {
    uptr startAddr = baseAddr + PKT_GEN_PARAMS_OFFSET;
    *((volatile u32*)startAddr) |= 1<<PKT_GEN_PARAMS_RSTSTATS_IDX;
    return;
}

pktGenStats pktGenGetStats(uptr baseAddr) {
    uptr startAddr = baseAddr + PKT_GEN_OK_TRANS_OFFSET;
    pktGenStats returnVal;
    returnVal.OKTransmissions = *((volatile u32*)startAddr);
    returnVal.NOKTransmissions = *((volatile u32*)(startAddr+4));
    return returnVal;
}


int enableSyncMode (uptr baseAddr) {
    uptr startAddr = baseAddr + RTC_SYNC_MODE_REG_OFFSET;
    if (*((u32*)startAddr) > 0) return 1;
    *(u32*)startAddr = 2;
    return 0;
}
int disableSyncMode (uptr baseAddr) {
    uptr startAddr = baseAddr + RTC_SYNC_MODE_REG_OFFSET;
    if (*((u32*)startAddr) < 1) return 1;
    *(u32*)startAddr = 0;
    return 0;
}

void rstRTC(uptr baseAddr) {
    uptr startAddr = baseAddr + RTC_SYNC_MODE_REG_OFFSET;
    // if (*((u32*)startAddr) < 1) return 1;
    *(u32*)startAddr |= (*(u32*)startAddr<<1) + 1;
}