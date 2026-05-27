#ifndef TSN_TEST_H
#define TSN_TEST_H

#include "tsn/tsn_time.h"

// functions used in experimentation

// typedef __attribute__((packed)) struct {
//     u32 nanoSeconds;
//     u32 seconds;
// } smallTs_t;

// checking if probes are valid
u32 getTsProbeValid (uptr baseAddr);

// reading from a ts probe
void readTsProbe (uptr baseAddr, u8 probeIdx, Timestamp_t* ts);
u64 readSmallTsProbe (uptr baseAddr, u8 probeIdx);
u64 readSmallPTP (uptr baseAddr);

// getting all timestamp probes
int getTsProbes (uptr baseAddr, Timestamp_t* Timestamps);

// pkt gen stuff
void pktGenSetParams(uptr baseAddr, u32 interval, u16 lenWords, u8 queue, u8 otherQueue, u8 burstLen);

void pktGenEnable(uptr baseAddr);
void pktGenDisable(uptr baseAddr);

typedef struct {
    u32 OKTransmissions;
    u32 NOKTransmissions;
} pktGenStats;
void pktGenResetStats(uptr baseAddr);
pktGenStats pktGenGetStats(uptr baseAddr);

int enableSyncMode (uptr baseAddr);
int disableSyncMode (uptr baseAddr);
void rstRTC(uptr baseAddr);

#endif