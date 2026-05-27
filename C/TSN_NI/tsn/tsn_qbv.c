#include "tsn/tsn_qbv.h"
#include <stdio.h>

// functions relevant to r_FlagsAndGateStates
u32 getFlags(uptr baseAddress){
    return *((volatile u32*)baseAddress) & 0x3; // only first two bits represent flags for now
}

int enableGates(uptr baseAddress){
    u32 tmp = *((volatile u32*)baseAddress);
    *((volatile u32*)baseAddress) = tmp | 0x2; // second bit is GateEnabled
    return OK;
}

int disableGates(uptr baseAddress){
    // u32 tmp = *((volatile u32*)baseAddress);
    *((volatile u32*)baseAddress) = UINT32_MAX - 0x2; // second bit is GateEnabled
    return OK;
}

int setAdminStates(uptr baseAddress, u8 adminStates){
        // need to do two writes: one two zero out the field and one to add the states
        *((volatile u32*)baseAddress) &= UINT32_MAX - (UINT8_MAX<<2);
        *((volatile u32*)baseAddress) |= adminStates<<2;
    return OK;
}

u8 getAdminStates(uptr baseAddress){
    return (u8) (*((volatile u32*)baseAddress) >> 2); // conversion to u8 cuts of msbs
}

int configChange(uptr baseAddress){
    u32 tmp = *((volatile u32*)baseAddress);
    *((volatile u32*)baseAddress) = tmp | 1; // resets itself one clock after it is set
return OK;
}

// Functions relevant to Admin/Oper BaseTime
int SetAdminBaseTime(uptr baseAddress, u64 adminBaseTime){
    // first get WrStatus
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    // xil_printf("wrstatus: %u\n", status.WrStatus);
    if (status.WrStatus == 3) return E_WR_STATUS;
    else {
    *((volatile u32*)((baseAddress + ADMIN_BASE_TIME_0_OFFSET + (2-status.WrStatus)*8))) = adminBaseTime;
    *((volatile u32*)((baseAddress + ADMIN_BASE_TIME_0_OFFSET + (2-status.WrStatus)*8 + 4))) = adminBaseTime>>32;
    }
    return OK;
}
u64 GetAdminBaseTime(uptr baseAddress) {
    u64 baseTime = 0;
    u64 tmpTime = 0;
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return 0;
    else {
    uptr baseAddr = baseAddress + ADMIN_BASE_TIME_0_OFFSET + (2-status.WrStatus)*8;
    baseTime = *((volatile u32*) baseAddr);
    tmpTime = *((volatile u32*) (baseAddr+4));
    baseTime += (tmpTime<<32);

    }
    return baseTime;
}
u64 GetOperBaseTime(uptr baseAddress){
    u64 baseTime = 0;
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return 0;
    else {
    uptr baseAddr = baseAddress + ADMIN_BASE_TIME_0_OFFSET + (status.WrStatus-1)*8;
    baseTime = *((volatile u32*) baseAddr);
    u64 tmpTime = *((volatile u32*) (baseAddr+4));
    baseTime += (tmpTime<<32);
    }
    return baseTime;
}

// Functions relevant to cycle time
int SetAdminCycleTime(uptr baseAddress, u64 adminCycleTime){
    // first get WrStatus
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return E_WR_STATUS;
    else {
    *((volatile u32*)((baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + (2-status.WrStatus)*8))) = (u32) adminCycleTime;
    *((volatile u32*)((baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + (2-status.WrStatus)*8 + 4))) = (u32)(adminCycleTime>>32);
    }
    return OK;
}
u64 GetAdminCycleTime(uptr baseAddress){
    u64 cycleTime = 0;
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return 0;
    else {
    uptr baseAddr = baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + (2-status.WrStatus)*8;
    cycleTime = *((volatile u32*) baseAddr);
    u64 tmpTime = *((volatile u32*) (baseAddr+4));
    cycleTime += (tmpTime<<32);
    }
    return cycleTime;
}
u64 GetOperCycleTime(uptr baseAddress){
    u64 cycleTime = 0;
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return 0;
    else {
    uptr baseAddr = baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + (status.WrStatus-1)*8;
    cycleTime = *((volatile u32*) baseAddr);
    u64 tmpTime = *((volatile u32*) (baseAddr+4));
    cycleTime += (tmpTime<<32);
    }
    return cycleTime;
}

// Functions relevant to cycle time Extension
int SetAdminCycleTimeExtension(uptr baseAddress, u64 adminCycleTimeExtension){
    // first get WrStatus
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return E_WR_STATUS;
    else {
    *((volatile u32*)((baseAddress + ADMIN_CYCLE_TIME_EXT_0_OFFSET + (2-status.WrStatus)*8))) = (u32) adminCycleTimeExtension;
    *((volatile u32*)((baseAddress + ADMIN_CYCLE_TIME_EXT_0_OFFSET + (2-status.WrStatus)*8 + 4))) = (u32)(adminCycleTimeExtension>>32);
    }
    return OK;
}
u64 GetAdminCycleTimeExtension(uptr baseAddress){
    u64 cycleTime = 0;
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return 0;
    else {
    uptr baseAddr = baseAddress + ADMIN_CYCLE_TIME_EXT_0_OFFSET + (2-status.WrStatus)*8;
    cycleTime = *((volatile u32*) baseAddr);
    u64 tmpTime = *((volatile u32*) (baseAddr+4));
    cycleTime += (tmpTime<<32);
    }
    return cycleTime;
}
u64 GetOperCycleTimeExtension(uptr baseAddress){
    u64 cycleTime = 0;
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return 0;
    else {
    uptr baseAddr = baseAddress + ADMIN_CYCLE_TIME_EXT_0_OFFSET + (status.WrStatus-1)*8;
    cycleTime = *((volatile u32*) baseAddr);
    u64 tmpTime = *((volatile u32*) (baseAddr+4));
    cycleTime += (tmpTime<<32);
    }
    return cycleTime;
}

// Functions relevant to control list length
int SetAdminControlListLength(uptr baseAddress, u32 adminControlListLength) {
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    // xil_printf("status: %u\n", status.WrStatus);
    if (status.WrStatus == 3) return E_WR_STATUS;
    else {
        u32 val = adminControlListLength > GCL_LENGTH ? GCL_LENGTH : adminControlListLength;
        // if ((getFlags(baseAddress) & 0x1) == 0) 
        val = val<<((2-status.WrStatus)*16);
        // behaviour is changed so that HW will handle where to put it
        *((volatile u32*)(baseAddress + ADMIN_CTRL_LIST_LEN_OFFSET)) = val;
    }
    return OK;    
}
u32 GetAdminControlListLength(uptr baseAddress){
    u32 controlList = 0;
        WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return 0;
    else {
        uptr addr = baseAddress + ADMIN_CTRL_LIST_LEN_OFFSET;
        // read the register and shift the value right if WrStatus is 1 (not if it is 2)
        controlList = (*((volatile u32*) addr)) >> ((2-status.WrStatus)*16);
        // then mask it (only really have to do it if the shift didnt happen)
        controlList = controlList & 0xFFFF;
    }
    return controlList; 
}
u32 GetOperControlListLength(uptr baseAddress){
    u32 controlList = 0;
        WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return 0;
    else {
        uptr addr = baseAddress + ADMIN_CTRL_LIST_LEN_OFFSET;
        // read the register and shift the value right if WrStatus is 1 (not if it is 2)
        controlList = (*((volatile u32*) addr)) >> ((status.WrStatus-1)*16);
        // then mask it (only really have to do it if the shift didnt happen)
        controlList = controlList & 0xFFFF;
    }
    return controlList; 
}

// functions for reading and writing schedule
int SetAdminControlListEntry(uptr baseAddress, u32 idx, ControlListEntry_t listEntry){
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return E_WR_STATUS;
    else {
        uptr addr = baseAddress + ADMIN_CTRL_LIST_0_OFFSET + 4*(idx + GCL_LENGTH*(2-status.WrStatus));
        u32 interval = listEntry.TimeInterval & 0xFFFFFF; // only first 24 bits of interval
        *((volatile u32*) (addr)) = interval + ((u32)listEntry.GateStates<<24);
    }
    return OK; 
}

ControlListEntry_t GetAdminControlListEntry(uptr baseAddress, u32 idx){
    ControlListEntry_t listEntry = {0,0};
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return listEntry;
    else {
        u32 reg = *((volatile u32*) (baseAddress + ADMIN_CTRL_LIST_0_OFFSET + 4*(idx+GCL_LENGTH*(2-status.WrStatus))));
        listEntry.GateStates = reg>>24;
        listEntry.TimeInterval = reg & ((1<<24)-1);
    }
    return listEntry; 
}
ControlListEntry_t GetOperControlListEntry(uptr baseAddress, u32 idx){
    ControlListEntry_t listEntry = {0,0};
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return listEntry;
    else {
        u32 reg = *((volatile u32*) (baseAddress + ADMIN_CTRL_LIST_0_OFFSET + 4*(idx+GCL_LENGTH*(status.WrStatus-1))));
        listEntry.GateStates = reg>>24;
        listEntry.TimeInterval = reg & ((1<<24)-1);
    }
    return listEntry; 
}

// read WrStatus and ConfigChangeError
WrStatusCfgChgErr_t getWrStatusCfgChgErr(uptr baseAddress) {
    WrStatusCfgChgErr_t status;
    u32 reg = *((volatile u32*) (baseAddress + WR_STATUS_CFG_CHG_ERR_OFFSET));
    // xil_printf("reg: %X\n", reg);
    // xil_printf("addr: %X", baseAddress+WR_STATUS_CFG_CHG_ERR_OFFSET);
    status.WrStatus = reg & (3); // first two bits;
    status.ConfigChangeError = reg >> 2;
    return status;
}

int setAdminControlList(uptr baseAddress, ControlListEntry_t* sched, u32 schedLen, uint64_t baseTime, uint64_t cycleTime, uint64_t cycleTimeExt) {
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddress);
    if (status.WrStatus == 3) return E_WR_STATUS;

    // params
    *((volatile u32*)((baseAddress + ADMIN_BASE_TIME_0_OFFSET + (2-status.WrStatus)*8))) = baseTime;
    *((volatile u32*)((baseAddress + ADMIN_BASE_TIME_0_OFFSET + (2-status.WrStatus)*8 + 4))) = baseTime>>32;
    *((volatile u32*)((baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + (2-status.WrStatus)*8))) = cycleTime;
    *((volatile u32*)((baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + (2-status.WrStatus)*8 + 4))) = cycleTime>>32;
    *((volatile u32*)((baseAddress + ADMIN_CYCLE_TIME_EXT_0_OFFSET + (2-status.WrStatus)*8))) = cycleTimeExt;
    *((volatile u32*)((baseAddress + ADMIN_CYCLE_TIME_EXT_0_OFFSET + (2-status.WrStatus)*8 + 4))) = cycleTimeExt>>32;

    // len
    u32 lenVal = schedLen > GCL_LENGTH ? GCL_LENGTH : schedLen;
    lenVal = lenVal<<((2-status.WrStatus)*16);
    u32 lenReg = *((volatile u32*)(baseAddress + ADMIN_CTRL_LIST_LEN_OFFSET)) & (0xFFFF<<((status.WrStatus-1)*16));
    *((volatile u32*)(baseAddress + ADMIN_CTRL_LIST_LEN_OFFSET)) = lenReg | lenVal;

    // write schedule
    const uptr schedOffset = (2-status.WrStatus)*GCL_LENGTH*4;
    for (u32 i = 0; i<schedLen; i++)
        *((volatile u32*) (baseAddress + ADMIN_CTRL_LIST_0_OFFSET + schedOffset + 4*i)) = ((sched[i].TimeInterval & 0x00ffffff) + (sched[i].GateStates<<24));
    return OK;
}

// Some more abstraction:
// function to initialize all regs: requires GateEnabled to be low
int initSched(uintptr_t baseAddress, ControlListEntry_t* sched0, ControlListEntry_t* sched1, u32 schedLen[2],
    uint64_t baseTime[2], uint64_t cycleTime[2], uint64_t cycleTimeExt[2]) {
        // first check if gate is disabled
        if ( *((volatile u32*) baseAddress) & 0x2) return E_GATE_ENABLED;
        else {
            // write basetime, cycletime, cycleTimeExtension
            for (u32 i = 0; i<2; i++) {
                // printf("cycletime[%u]: %lu\n", i, cycleTime[i]);
                // printf("debug: %lu\n", (baseAddress + ADMIN_BASE_TIME_0_OFFSET + 8*i));
                 *((volatile u32*) (baseAddress + ADMIN_BASE_TIME_0_OFFSET + 8*i)) = ((u32) baseTime[i]);
                *((volatile u32*) (baseAddress + ADMIN_BASE_TIME_0_OFFSET + 4 + 8*i)) = ((u32) (baseTime[i]>>32));
                // printf("debug: %lu", (baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + 8*i));
                *((volatile u32*) (baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + 8*i)) = ((u32) cycleTime[i]);
                *((volatile u32*) (baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + 4 + 8*i)) = ((u32) (cycleTime[i]>>32));
                *((volatile u32*) (baseAddress + ADMIN_CYCLE_TIME_EXT_0_OFFSET + 8*i)) = ((u32) cycleTimeExt[i]);
                *((volatile u32*) (baseAddress + ADMIN_CYCLE_TIME_EXT_0_OFFSET + 4 + 8*i)) = ((u32) (cycleTimeExt[i]>>32));
                // printf("cycletimeext[%u]: %u\n", i, *((volatile u32*) (baseAddress + ADMIN_CYCLE_TIME_0_OFFSET + 8*i)));

            }
            // write schedLen
            u32 schedLenReg = (schedLen[1]<<16) + schedLen[0];
            // u32 schedLenReg = schedLen[0];
            *((volatile u32*) (baseAddress + ADMIN_CTRL_LIST_LEN_OFFSET)) = schedLenReg;
            // write schedule
            for (u32 i = 0; i<schedLen[0]; i++)
                *((volatile u32*) (baseAddress + ADMIN_CTRL_LIST_0_OFFSET + 4*i)) = ((sched0[i].TimeInterval & 0x00ffffff) + (sched0[i].GateStates<<24));
            for (u32 i = 0; i<schedLen[1]; i++)
                *((volatile u32*) (baseAddress + ADMIN_CTRL_LIST_1_OFFSET + 4*i)) = ((sched1[i].TimeInterval & 0x00ffffff) + (sched1[i].GateStates<<24));
        }
        return OK;
}

void setMediaDependentOverhead(uptr baseAddress, u16 MediaDependentOverhead) {
    *((volatile u32*) (baseAddress + MEDIA_DEP_OVERHEAD_OFFSET)) = (u32) MediaDependentOverhead;
}

u16 getMediaDependentOverhead(uptr baseAddress) {
    return *((volatile u32*) (baseAddress + MEDIA_DEP_OVERHEAD_OFFSET));
}