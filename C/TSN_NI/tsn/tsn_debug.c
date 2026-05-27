#include "tsn/tsn_debug.h"
#include "tsn/tsn_queues.h"
#include "tsn/tsn_config.h"
#include <stdio.h>
#include <time.h>

#define MIN(a, b) ((a) < (b) ? (a) : (b))

// reading raw registers
u32 readRegister(uptr baseAddress, uptr offset) {
    return *((u32*) (baseAddress + offset));
}

// Sending a packet
int sendDebug(const uptr baseAddress, u32* packet, u16 length) {
    // what to do: 
    // check if packet is valid?
    // - if VLAN tag is present, retrieve priority
    // vlan tag is present if ethertype is 0x8100
    // ethertype is the byte 12-13
    u16 etherType = *((u16*) (packet + 3));
    // xil_printf("ethertype: 0x%X\n", etherType);
    // printf("ethertype: 0x%X\n", etherType);
    u8 queue = 0; // default to best effort
    if (etherType == 0x0081) {
        // queue is now stored in idx 14 at upper 3 bits
        queue = ((u8*)packet)[14]>>5;
    }
    // xil_printf("queue: %u\n", queue);
    // printf("send queue: %u\n", queue);
    // - if enough space, write packet to queue
    OQMetadata_t metadata = getOQMetadata(baseAddress, queue);
    // xil_printf("w_avail: %u\n", metadata.wordsAvailable);
    // xil_printf("startAddr: 0x%X\n", metadata.startAddr);
    // xil_printf("full: %u\n", metadata.fullMD);
    // return error if we cannot write
    if ((metadata.wordsAvailable == 0) | metadata.fullMD) {
        // printf("not enough space\n");
        return E_SPACE_LEFT;
        xil_printf("no space left\n");
    }

    // first write size
    setWrPktLen(baseAddress, queue, length);
 
    // now send data
    uptr queueStartOffset = baseAddress+WR_MEM_START_OFFSET + (((uptr)queue)<<12);
    // xil_printf("queueStart: 0x%08X\n", queueStartOffset);

    u32 lenWords = length>>2;
    uptr queueAddr;
    for (u32 i = 0; i<lenWords; i++) {
        queueAddr = (((metadata.startAddr+i)<<2)%WR_QUEUE_SIZE); // wraparound
        *((volatile u32*) (queueStartOffset + queueAddr)) = packet[i];
    }
    // xil_printf("first addr: 0x%08X\n", queueStartOffset + ((metadata.startAddr<<2)%WR_QUEUE_SIZE));
    // xil_printf("last addr: 0x%08X\n", queueStartOffset + (((metadata.startAddr + lenWords-1)<<2)%WR_QUEUE_SIZE));
    // xil_printf("last addr: ")
    // will try this with memcpy now

    // queueAddr = (((metadata.startAddr))%WR_QUEUE_SIZE)<<2; // wraparound
    // u16 lenAligned = (length & (UINT16_MAX-3)) + ((length & 0b11) > 0)*4; // just rounds up to mutliple of 4
    // printf("lenAligned: %u\n", lenAligned);
    // memcpy((void*) queueStartOffset+queueAddr, (u32*) packet, lenAligned);

    // u32 lastWord = 0;
    // u32 startIdx = length - length%4;
    // // printf("assembling last word\n");
    // for (u32 i = 0; i < length%4; i++) {
    //     // printf("byte: 0x%X\n", ((u32)packet[startIdx+i])<<i*8);
    //     lastWord += ((u32)packet[startIdx+i])<<i*8;
    // }

    // // // printf("writing last word to addr: 0x%lX\n", WR_MEM_START_OFFSET+(((uptr)queue)<<12) +  (metadata.startAddr<<2) + startIdx);
    // // // printf("lastword data: 0x%X, %u\n", lastWord, startIdx);
    // // write last data
    // queueAddr = (((metadata.startAddr<<2) + 4*lenWords)%WR_QUEUE_SIZE)<<2;
    // *((volatile u32*)(queueStartOffset + queueAddr)) = lastWord;
    
    // printf("write enable tos fifo\n");
    // write enable to fifo
    *((volatile u32*)(baseAddress+WR_QUEUE_LEN_WE_OFFSET)) = 1<<queue;

    return OK;
}

// returns the packet length
int receiveDebug(const uptr baseAddress, u8* buffer, u8 queue, u16* len) {
    // what to do
    // read metadata
    IQMetadata_t metadata = {0};
    metadata = getIQMetadata(baseAddress, queue);
    // printf("startAddr: %u, len %u, empty: %u, lastBytes: %u\n",metadata.startAddr, metadata.lenWords, metadata.empty,metadata.last_bytes);

    if (metadata.empty) return E_R_EMPTY;
    // put packet into the buffer
    // u32 startAddr = (metadata.startAddr<<2) + (queue<<12);
    // printf("startAddr: %X\n",startAddr);
    const uptr queueBase = baseAddress + R_MEM_START_OFFSET + (queue<<12);
    for (u32 i = 0; i< metadata.lenWords; i++)
    ((u32*)buffer)[i] = *((u32*) queueBase + ((metadata.startAddr + i)%R_QUEUE_LEN));
    
    // new way
    // clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &start);
    // // first detect if you wrap around
    // u8 wrapAmount = metadata.startAddr+metadata.lenWords %R_QUEUE_LEN;
    // if (wrapAmount < metadata.startAddr) {
    //     for (u32 i=metadata.startAddr; i<R_QUEUE_LEN; i++)
    //         ((u32*)buffer)[i] = *((u32*) queueBase + i);
        
    //     u32 wrapStart = metadata.lenWords - wrapAmount;
    //     for (u32 i=0; i<wrapAmount; i++)
    //     ((u32*)buffer)[wrapStart+i] = *((u32*) queueBase + i);
        
    // }
    // else {
    //     for (u32 i = 0; i< metadata.lenWords; i++)
    //     ((u32*)buffer)[i] = *((u32*) queueBase + (metadata.startAddr + i));
    // }
    // clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &stop);
    
    // signal done
    *((volatile u32*)(baseAddress+R_QUEUE_DONE_OFFSET)) = 1<<queue;
    *len = (metadata.lenWords-1)*4 + metadata.last_bytes + 1;
    return OK;
}