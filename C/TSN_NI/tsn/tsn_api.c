#include "tsn/tsn_api.h"
#include "tsn/tsn_config.h"
#include "tsn/tsn_queues.h"
#include <string.h>

#define htons(x) __builtin_bswap16(x)
#define htonl(x) __builtin_bswap32(x)
#define ntohs(x) __builtin_bswap16(x)

int TSNInit (uptr baseAddr, u64 sourceMAC, u32 sourceIPv4, ControlListEntry_t* sched0, ControlListEntry_t* sched1, u32 schedLen[2], u64 baseTime[2], u64 cycleTimeExt[2]) {
    // I guess this will set a couple global vars and initialize the handles to zero

    // set the addresses
    // for (int i=0; i<4; i++)
    // globalSourceIPv4 = htonl(sourceIPv4);
    // xil_printf("setting ip\n");
    globalSourceIPv4 = sourceIPv4;
    // for (int i=0; i<6; i++)
        // globalSourceMAC[i] = sourceMAC[i];
    globalSourceMAC = sourceMAC;
    // xil_printf("setting mac\n");
    // globalSourceMAC = ((u64)htonl(sourceMAC>>16)) | ((u64)htons(sourceMAC))<<32;;
    // for (int i=0; i<16; i++)
    //     globalSourceIPv6[i] = sourceIPv6[i];

    // set appHandles
    // xil_printf("initing apphandles\n");

    for (int i = 0; i < NUM_QUEUES; i++) appHandles[i] = 0;

    // xil_printf("calcing cycletime\n");
    // calculate cycle time
    u64 cycleTime[2] = {0};
    // xil_printf("first: %u, %lu, %u\n", schedLen[0], cycleTime[0],sched0[0].TimeInterval);
    for (int i = 0; i < schedLen[0]; i++)
        cycleTime[0] += sched0[i].TimeInterval;
    // xil_printf("second\n");
    for (int i = 0; i < schedLen[1]; i++)
        cycleTime[1] += sched1[i].TimeInterval;

    cycleTime[0] *= 8;
    cycleTime[1] *= 8;
    // disable gates

    // xil_printf("prepared schedule, disabling gates\n");
    disableGates(baseAddr);

    // init sched
    // xil_printf("initializing schedule\n");
    int returnVal = initSched(baseAddr, sched0, sched1, schedLen, baseTime, cycleTime, cycleTimeExt);
    if (returnVal != OK) return returnVal; 

    return OK;
}

TSNHandle_t getHandle(u8 handleFlags) {
    TSNHandle_t returnVal = {0,0};
    // take first available handle
    u8 handleIdx;
    for (handleIdx = 0; handleIdx < NUM_HANDLES; handleIdx++) {
        if (appHandles[handleIdx] == 0) break;
    }
    returnVal.queue = handleIdx;
    if (handleIdx < NUM_HANDLES) appHandles[handleIdx] = 1 | handleFlags; // 1 flag just means taken 
    return returnVal;
}

int giveHandle(TSNHandle_t handle) {
    // just set the handle back to zero
    // first check if handle is not zero already
    if (appHandles[handle.queue] == 0) return E_WRONG_HANDLE;
    appHandles[handle.queue] = 0;
    return OK;
}

// TODO: Can prolly precalculate part of the header
int createUDPHeader (u8* pktBuf, UDPLoc_t dest, TSNHandle_t appHandle, u8* data, u16 dataLen) {
    // static u16 IPv4ID = 0x3412;
    u16 IPv4ID = 0x3412;
    // packet starts with source and destination mac
    // ethernet header looks like this:
    // dest MAC (6B) | source MAC (6B) | QTag (4) | ethertype==0x0800|
    // MACs
    *((u64*)pktBuf) = ((u64)htonl(dest.MAC>>16)) | ((u64)htons(dest.MAC))<<32;
    *((u64*)(pktBuf+6)) = globalSourceMAC;
    // QTag:
    // | TPID==0x8100 (2B) | PCP (3b) | dei (1b) | VID (12b) |
    *((u16*)(pktBuf+Q_TAG_OFFSET)) = ETH_TYPE_QVLAN;
    *((u16*)(pktBuf+Q_TAG_OFFSET+2)) = (appHandle.queue<<(5)); // for now we dont do any other vlan tags
    // ethertype==IPV4
    *((u16*)(pktBuf+ETH_TYPE_OFFSET)) = ETH_TYPE_IPV4;

    // IPv4 has the following header;
    // | version (4b) | IHL (4b) | DSCP (6b) | ECN (2b) | Total length (16b)                 |
    // | Identification (16b)                           | flags (3b) | fragment offset (13b) |
    // |Time to live (8b) | protocol (8b)               | header checksum (16b)              |
    // |source address (32b)                                                                 |
    // |destination address (32b)                                                            |
    // | (options) (if IHL > 5) (up to 320 bits) (optional)                                  |
    // first word: version == 4, IHL == 5 (no options), TOS (DSCP,ECN) 
    const u32 totalIPv4Len = IPV4_HDR_BASE_LEN + UDP_HDR_LEN + dataLen;
    // printf("ipv4Len: %u, datalen: %u\n", totalIPv4Len, dataLen);
    const u8* IPv4Start = pktBuf + IPV4_HDR_OFFSET;
    *((u32*) IPv4Start) = (4<<4) | (5) | (htons(totalIPv4Len)<<16);
    // identification should be a unique number for this specific datagram, for the source IP, dest IP and protocol combination (always the same here)
    // For simplicity I will just use an increasing 16 bit counter, defined in a static variable?
    // flags: reserved (=0) | dont fragment (will set to 1) | more fragments (set to 0)
    // fragment offset can also be zero at all times
    *((u32*) (IPv4Start+4)) = (IPv4ID++) | (0b010<<(16+5));
    // // time to live (will just set this to max), protocol==UDP==17 | header checksum (computed after assembling the header, set to zero for now)
    *((u32*) (IPv4Start+8)) = 255 | (IPV4_PROT_UDP<<8);
    // source ip
    *((u32*) (IPv4Start+12)) = globalSourceIPv4;
    // destination IP
    *((u32*) (IPv4Start+16)) = dest.IPv4Addr;

    // from: https://www.packetmania.net/en/2021/12/26/IPv4-IPv6-checksum/
    u32 IPv4Checksum = 0;
    for (int i=0; i < IPV4_HDR_BASE_LEN; i+=2)
        // IPv4Checksum = onesComplementAdd(IPv4Checksum, *((u16*)(IPv4Start+i)));
        IPv4Checksum += *((u16*)(IPv4Start+i));
    IPv4Checksum = 0xFFFF - (((u16)IPv4Checksum) + (IPv4Checksum>>16));
    // printf("checksum: %X\n", IPv4Checksum);
    *((u16*)(IPv4Start+10)) = IPv4Checksum;

    // UDP header:
    // | source port (16b)  | dest port (16b)   |
    // | length (16b)       | checksum (16b)    |
    const u8* UDPStart = pktBuf + UDP_HDR_OFFSET;
    *((u32*) (UDPStart)) = htons(appHandle.port) | (((u32)htons(dest.port))<<16);
    // checksum is apparently optional, length is 8 + datalen
    *((u32*) (UDPStart+4)) = htons(8 + dataLen);

    // UDP checksum calculation is similar to IP
    u32 UDPChecksum = 0;
    // first sum the pseudo-header:
    // source and destination ip
    for (int i=0; i < 2*4; i+=2)
        UDPChecksum += *((u16*)(IPv4Start+12+i));
    // protocol shifted 8 bits
    UDPChecksum += (IPV4_PROT_UDP<<8);
    // oh sheet forgot the length
    UDPChecksum += *((u16*) (UDPStart+4));
    // UDP header
    for (int i=0; i < UDP_HDR_LEN; i+=2)
        UDPChecksum += *((u16*)(UDPStart+i));
        // data
    for (int i=0; i < dataLen; i+=2)
        UDPChecksum += *((u16*)(data+i));
    UDPChecksum = 0xFFFF - (((u16)UDPChecksum) + (UDPChecksum>>16));
    *((u16*)(UDPStart+6)) = UDPChecksum;
    return OK;
}

// length of data array needs to be a multiple of 4, so pad with zeros if needed
int sendUDPPacket (uptr baseAddr, UDPLoc_t dest, TSNHandle_t appHandle, u8* data, u16 dataLen) {
    // create a header buffer
    u8 hdrBuf [HDR_LEN] = {0};
    // First of all create the header
    const u16 len = dataLen + HDR_LEN; // is fixed, and unused currently

    // we need to verify that dataLen is a multiple of 4 (so padded with 0s if the actual packet isnt a multiple of 4)
    // if (dataLen%4 > 0) return E_DATA_LEN;
    // u16 dummyLen;
    createUDPHeader(hdrBuf, dest, appHandle, data, dataLen);
    
    // We now have the header at the beginning of hdrBuf
    // we have the data in a buffer, with HDR_LEN bytes empty at the beginning
    // We could also keep the buffers separate, and just read them separately in the send function
    // cant really use the defined send function, as it assumes all data is in a single buffer
    // start by writing the len
    setWrPktLen(baseAddr, appHandle.queue, (dataLen + HDR_LEN));

    // If we want to use memcpy, we need to take the buffer wraparound into consideration
    // buffer is of size WR_QUEUE_SIZE
    // first read the metadata
    OQMetadata_t metadata = getOQMetadata(baseAddr, appHandle.queue);
    // required to check
    if(metadata.fullMD || (metadata.wordsAvailable<len)) return E_SPACE_LEFT;
    // const uptr startOffset = baseAddr + WR_MEM_START_OFFSET + appHandle.queue*WR_QUEUE_SIZE;
    // uptr queueAddr;
    // first send the header
    copyToQueues(baseAddr, appHandle.queue, metadata.startAddr, hdrBuf, HDR_LEN);
    // then the data
    copyToQueues(baseAddr, appHandle.queue, metadata.startAddr+(HDR_LEN>>2), hdrBuf, dataLen);
    // write enable to fifo
    *((u32*)(baseAddr+WR_QUEUE_LEN_WE_OFFSET)) = 1<<appHandle.queue;

    return OK;
}

// ingressMD_t decodePktHdr(u8* pktBuf, u16 pktLen) {
ingressMD_t decodePktHdr(u8* pktBuf) {
    ingressMD_t hdr; // queue 255 means discard packet
    hdr.dataLen = 0;
    
    // first check the MAC
    const u64 destMAC = *((u64*)(pktBuf)) & UINT48_MAX;
    // printf("destMAC: %lX\n", destMAC);
    if (destMAC != globalSourceMAC) {
        hdr.appHandle.queue = E_DECODE_MAC_ADDR; // invalid packet
        return hdr;
    }
    hdr.source.MAC = *((u64*)(pktBuf+MAC_LEN)) & UINT48_MAX;

    // check ethertype
    // if PTP over ethernet -> put in queue 0 with reserved port for PTP
    // if Qtag -> 
    // if IPV4 -> set queue to zero
    // first obtain the ethertype
    const u16 etherType = *((u16*)(pktBuf+Q_TAG_OFFSET));
    u8 IPv4Prot;
    u8 IPv4ExtraLen;
    switch (etherType)
    {
    case ETH_TYPE_QVLAN:
        // now its only valid if there is ipv4 and udp (maybe ill add ipv6 later?)
        if (*((u16*)(pktBuf+ETH_TYPE_OFFSET)) != ETH_TYPE_IPV4) {
            hdr.appHandle.queue = E_DECODE_ETH_TYPE;
            break;
        }
        // then we check if UDP is in header
        // *((u32*) (IPv4Start+8)) = 255 | (IPV4_PROT_UDP<<8);
        IPv4Prot = (u8)((*(u32*)(pktBuf+IPV4_HDR_OFFSET+8))>>8);
        if (IPv4Prot != IPV4_PROT_UDP) {
            // printf("IPv4Prot: %u\n", IPv4Prot);
            hdr.appHandle.queue = E_DECODE_IPV4_PROT;
            break;
        }
        hdr.protFlags = HANDLE_FLAG_UDP;
        hdr.source.IPv4Addr = *((u32*)(pktBuf+IPV4_HDR_OFFSET+12));
        // check the IHL field for ipv4 header length
        // printf("IHL: %u\n",*(pktBuf+IPV4_HDR_OFFSET) & 0xF);
        IPv4ExtraLen = (((*(pktBuf+IPV4_HDR_OFFSET)) & 0xF) - 5)*8;
        // printf("ExtraLen: %u\n",IPv4ExtraLen);

        // if the stars align, we can extract the full handle
        hdr.appHandle.queue = (*((u8*)(pktBuf+Q_TAG_OFFSET+2)))>>5;
        // | source port (16b)  | dest port (16b)   |
        hdr.appHandle.port = ntohs((*((u32*)(pktBuf+UDP_HDR_OFFSET+IPv4ExtraLen)))>>16);
        // printf("port: %X\n", (u16)*(pktBuf+UDP_HDR_OFFSET+IPv4ExtraLen));
        hdr.source.port = ntohs(*((u16*)(pktBuf+UDP_HDR_OFFSET+IPv4ExtraLen)));
        hdr.hdrLen = HDR_LEN+IPv4ExtraLen;
        hdr.dataLen = ntohs(*((u16*)(pktBuf+UDP_HDR_OFFSET+IPv4ExtraLen+4)));
        break;

    case ETH_TYPE_IPV4:
        // we dont just drop the packet, we will put it in the queue 0 and use the UDP port
        // so first check for udp
        IPv4Prot = (u8)((*(u32*)(pktBuf+IPV4_HDR_OFFSET_NO_Q+8))>>8);

        if (IPv4Prot != IPV4_PROT_UDP) {
            hdr.appHandle.queue = E_DECODE_IPV4_PROT;
            break;
        }
        hdr.protFlags = HANDLE_FLAG_UDP;
        hdr.source.IPv4Addr = *((u32*)(pktBuf+IPV4_HDR_OFFSET_NO_Q+12));
        // check the IHL field for ipv4 header length
        IPv4ExtraLen = ((*(pktBuf+IPV4_HDR_OFFSET)) & 0xF) - 5;
        hdr.appHandle.queue = 0;
        hdr.appHandle.port = ntohs((*((u32*)(pktBuf+UDP_HDR_OFFSET_NO_Q+IPv4ExtraLen)))>>16);
        hdr.source.port = ntohs(*((u16*)(pktBuf+UDP_HDR_OFFSET_NO_Q+IPv4ExtraLen)));
        hdr.hdrLen = HDR_LEN_NO_Q+IPv4ExtraLen;
        // source of packet
        
        break;

    case ETH_TYPE_PTP:
        // set queue to 0 and port to predefined PTP port
        hdr.appHandle.queue = PTP_HANDLE_QUEUE;
        hdr.appHandle.port = PTP_HANDLE_PORT;
        hdr.protFlags = HANDLE_FLAG_PTP_L2;
        break;
    
    default:
        hdr.appHandle.queue = E_DECODE_ETH_TYPE;
        break;
    }
    // should I return some other stuff (hdr len, source ip and port?)
    return hdr;
}

int receivePkt(uptr baseAddr, TSNHandle_t handle, u8* data, u16* len, UDPLoc_t* source) {
    // first of all receive a full packet from the ep
    // but we first need the queue metadata
    IQMetadata_t metadata = getIQMetadata(baseAddr, handle.queue);
    // check if the queue is empty
    if (metadata.empty) return E_R_EMPTY;
    // now we can start copying
    copyFromQueues(baseAddr, handle.queue, metadata.startAddr, data, metadata.lenWords<<2);
    // do read enable
    IQReadEnable(baseAddr, handle.queue);
    // calculate len in bytes (maybe change the HW to do this)
    // u16 pktLen = (metadata.lenWords<<2) + metadata.last_bytes;

    // process the header
    ingressMD_t ingressMD = decodePktHdr(data);
    // first check if queue and port are the same as the handle
    // will only check queue for now
    if (ingressMD.appHandle.queue > 7) return ingressMD.appHandle.queue;
    if (ingressMD.appHandle.queue != handle.queue) return E_WRONG_HANDLE;
    // if (ingressMD.appHandle.port != handle.port | ingressMD.appHandle.queue != handle.queue) return E_WRONG_HANDLE;
    // also check if the traffic is udp
    if (ingressMD.protFlags & (appHandles[handle.queue] == 0)) return E_INCOMPATIBLE_PROT;

    // now we can remove the header by doing a memcpy of the data
    // memmove because overlap
    memmove((void*) data, (void*) (data+ingressMD.hdrLen), (size_t) ingressMD.dataLen);
    // and attach the source and len
    *len = ingressMD.dataLen;
    *source = ingressMD.source;

    return OK;
}

int enableSchedIdx(uptr baseAddr, u8 schedIdx) {
    // first check if schedIdx is valid value
    if (schedIdx > 1) return E_INVALID_SCHED_IDX;
    // we'll first need to know what the current schedule is ()
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddr);
    // now check if wrstatus is on the idx we want, if not we also need to signal config change alongside enable gates
    // ill do both in one call
    u32 writeVal = 2; // for enabling gates
    if (status.WrStatus-1 != schedIdx) writeVal |= 1; // for config change
    // now write
    *((volatile u32*) baseAddr) |= writeVal;
    
    return OK;
}

u8 getActiveSchedIdx(uptr baseAddr) {
    WrStatusCfgChgErr_t status = getWrStatusCfgChgErr(baseAddr);
    return status.WrStatus-1;
}

int loadSchedule(uptr baseAddr, ControlListEntry_t* sched, u32 schedLen, u64 baseTime, u64 cycleTimeExt) {
    // calculate cycletime and set control list entries
    u64 cycleTime = 0;
    int returnVal;
    for (u32 i = 0; i<schedLen; i++) {
        cycleTime += sched[i].TimeInterval;
        returnVal |= SetAdminControlListEntry(baseAddr, i, sched[i]);
    }
    if (returnVal != OK) return E_WR_STATUS;
    SetAdminBaseTime(baseAddr, baseTime);
    SetAdminControlListLength(baseAddr, schedLen);
    SetAdminCycleTime(baseAddr, cycleTime);
    SetAdminCycleTimeExtension(baseAddr, cycleTimeExt);

    return OK;
}

