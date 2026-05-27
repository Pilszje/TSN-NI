#include "tsn/tsn_queues.h"
#include "tsn/tsn_config.h"

OQMetadata_t getOQMetadata (const uptr baseAddr, u8 queue) {
    OQMetadata_t returnVal;
    u32 reg =  *((volatile u32*) (baseAddr + WR_QUEUE_METADATA_OFFSET + 4*queue));
    // printf("reg: %08X\n", reg);
    returnVal.wordsAvailable = reg & (2048-1); // first 11 bits
    returnVal.fullMD = (reg>>11) & 1;
    returnVal.startAddr = reg>>12;
    return returnVal;
}

int setWrPktLen (const uptr baseAddr, u8 queue, u16 len) {
    uintptr_t addr = baseAddr + WR_QUEUE_LEN_OFFSET + 4*queue;
    // printf("WRLen: 0x%X\n", len);
    *((volatile u32*) addr) = (u32)len;
    return OK;
}

// helper for writing data
void copyToQueues(uptr baseAddr, u8 queue, u16 startAddr, u8* data, u16 len) {
    const uptr queueStart = baseAddr + WR_MEM_START_OFFSET + queue*WR_QUEUE_SIZE;
    uptr queueIdx;
    for (int i = 0; i < len; i+=4) {
        queueIdx = ((startAddr+(i>>2))%WR_QUEUE_SIZE)<<2;
        *((volatile u32*)(queueStart + queueIdx)) = *((u32*)(data+i));
    }
}
// helper for reading data
void copyFromQueues(uptr baseAddr, u8 queue, u16 startAddr, u8* data, u16 len) {
    const uptr queueStart = baseAddr + R_MEM_START_OFFSET + queue*R_QUEUE_SIZE;
    uptr queueIdx;
    for (int i = 0; i < len; i+=4) {
        queueIdx = ((startAddr+(i>>2))%R_QUEUE_SIZE)<<2;
        *((u32*)(data+i)) = *((volatile u32*)(queueStart + queueIdx));
    }
}

u32 copyWordFromIQ(uptr baseAddr, u8 queue, u16 offset) {
    // xil_printf("addr: 0x%08X\n", baseAddr + R_MEM_START_OFFSET + queue*R_QUEUE_SIZE+(offset<<2));
    return *((volatile u32*)(baseAddr + R_MEM_START_OFFSET + queue*R_QUEUE_SIZE+ offset));
}



IQMetadata_t getIQMetadata (const uptr baseAddr, u8 queue) {
    IQMetadata_t returnVal = {0};
    u32 reg =  *((volatile u32*) (baseAddr + R_QUEUE_METADATA_OFFSET + 4*queue));
    // printf("reg: 0x%X\n",reg);
    // returnVal.startAddr = reg & ((1<<QUEUE_DEPTH) - 1); // first 11 bits
    // returnVal.last_bytes = (reg>>QUEUE_DEPTH) & 0b11;
    // returnVal.lenWords = (reg>>(QUEUE_DEPTH+2)) & ((1<<(9))-1);
    // returnVal.empty = reg>>(QUEUE_DEPTH+2+9) & 1;
    returnVal.startAddr = reg & ((1<<IQ_MD_START_ADR_WIDTH) - 1); // first 11 bits
    returnVal.last_bytes = (reg>>IQ_MD_START_LAST_BYTES_OFFSET) & 0b11;
    returnVal.lenWords = (reg>>(IQ_MD_START_LEN_WORDS_OFFSET)) & ((1<<IQ_MD_START_LEN_WORDS_WIDTH)-1);
    returnVal.empty = reg>>(IQ_MD_START_EMPTY_OFFSET) & 1;
    return returnVal;
}

u32 IQEmpty (const uptr baseAddr) {
    return *((volatile u32*) (baseAddr + R_EMPTY_OFFSET));
}

void OQWriteEnable (uptr baseAddr, u8 queueVector) {
        *((volatile u32*)(baseAddr+WR_QUEUE_LEN_WE_OFFSET)) = queueVector;
}
int IQReadEnable (uptr baseAddr, u8 queueVector) {
    *((volatile u32*)(baseAddr+R_QUEUE_DONE_OFFSET)) = queueVector;
    return OK;
}
