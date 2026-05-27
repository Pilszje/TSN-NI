#ifndef TSN_QUEUES_H
#define TSN_QUEUES_H

#include "types.h"

// Write queues
typedef struct {
    u16 wordsAvailable;
    u8 fullMD;
    u16 startAddr;
} OQMetadata_t;
OQMetadata_t getOQMetadata (uptr baseAddr, u8 queue);

// set the queue and packet length for packet to be written
int setWrPktLen (uptr baseAddr, u8 queue, u16 len);

// helpers for copying data
void copyToQueues(uptr baseAddr, u8 queue, u16 startAddr, u8* data, u16 len);
void copyFromQueues(uptr baseAddr, u8 queue, u16 startAddr, u8* data, u16 len);

u32 copyWordFromIQ(uptr baseAddr, u8 queue, u16 startAddr);

// Read queues
typedef struct {
    u16 startAddr;
    u8 last_bytes;
    u16 lenWords;
    u8 empty;
} IQMetadata_t;
IQMetadata_t getIQMetadata (uptr baseAddr, u8 queue);
u32 IQEmpty (const uptr baseAddr);

void OQWriteEnable (uptr baseAddr, u8 queueVector);
int IQReadEnable (uptr baseAddr, u8 queueVector);

#endif