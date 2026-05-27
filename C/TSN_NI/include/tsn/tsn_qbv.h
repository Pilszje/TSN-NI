#ifndef TSN_QBV_H
#define TSN_QBV_H

#include "types.h"
#include "tsn_config.h"

u32 getFlags(uptr baseAddress);
int enableGates(uptr baseAddress);
int disableGates(uptr baseAddress);
int setAdminStates(uptr baseAddress, u8 adminStates);
u8 getAdminStates(uptr baseAddress);
int configChange(uptr baseAddress);

// Functions relevant to Admin/Oper BaseTime
int SetAdminBaseTime(uptr baseAddress, u64 adminBaseTime);
u64 GetAdminBaseTime(uptr baseAddress);
u64 GetOperBaseTime(uptr baseAddress);

// Functions relevant to cycle time
int SetAdminCycleTime(uptr baseAddress, u64 adminCycleTime);
u64 GetAdminCycleTime(uptr baseAddress);
u64 GetOperCycleTime(uptr baseAddress);

// Functions relevant to cycle time Extension
int SetAdminCycleTimeExtension(uptr baseAddress, u64 adminCycleTimeExtension);
u64 GetAdminCycleTimeExtension(uptr baseAddress);
u64 GetOperCycleTimeExtension(uptr baseAddress);

// Functions relevant to control list length
int SetAdminControlListLength(uptr baseAddress, u32 adminControlListLength);
u32 GetAdminControlListLength(uptr baseAddress);
u32 GetOperControlListLength(uptr baseAddress);

// functions for reading and writing schedule stuff
typedef struct {
    u8 GateStates;
    u32 TimeInterval;
}ControlListEntry_t;
int SetAdminControlListEntry(uptr baseAddress, u32 idx, ControlListEntry_t listEntry);
ControlListEntry_t GetAdminControlListEntry(uptr baseAddress, u32 idx);
ControlListEntry_t GetOperControlListEntry(uptr baseAddress, u32 idx);

int setAdminControlList(uptr baseAddress, ControlListEntry_t* sched, uint32_t schedLen, uint64_t baseTime, uint64_t cycleTime, uint64_t cycleTimeExt);

// read WrStatus and ConfigChangeError
typedef struct {
    u8 WrStatus;
    u32 ConfigChangeError;
}WrStatusCfgChgErr_t;
WrStatusCfgChgErr_t getWrStatusCfgChgErr(uptr baseAddress);

int initSched(uintptr_t baseAddress, ControlListEntry_t* sched0, ControlListEntry_t* sched1, uint32_t schedLen[2],
    uint64_t baseTime[2], uint64_t cycleTime[2], uint64_t cycleTimeExt[2]);

void setMediaDependentOverhead(uptr baseAddress, u16 MediaDependentOverhead);
u16 getMediaDependentOverhead(uptr baseAddress);
#endif