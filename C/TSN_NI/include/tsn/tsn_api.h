#include "tsn/tsn_config.h"
#include "tsn/tsn_qbv.h"
#include "types.h"

// This is the high-level API for accessing a TSN network through an endpoint equipped with TAS (802.1Qbv)

// what could be a good idea is to abstract the idea of traffic queues away and supply tasks with some kind of handle they use for transmission and reception of packets.
// right now we can have 1 task per queue, having more will be a challenge as we somehow need to keep a local buffer of packets, so we can see multiple packets at once, instead of seeing just if there is a packet in the buffer or not.
// For transmission the send function can just be used i guess.
// the handle will prolly correspond to a udp port, which is a 16 bit value i think

// Defines
#define MTU 1522
#define MAC_LEN 6 // bytes
#define Q_TAG_LEN 4
#define Q_TAG_OFFSET 2*MAC_LEN
#define ETH_TYPE_LEN 2
#define ETH_TYPE_OFFSET (Q_TAG_OFFSET + Q_TAG_LEN)
#define ETH_HDR_LEN (2*MAC_LEN + Q_TAG_LEN + ETH_TYPE_LEN) // 12+4+2=20

#define IPV4_HDR_BASE_LEN 20
#define IPV4_HDR_OFFSET ETH_HDR_LEN
#define IPV4_HDR_OFFSET_NO_Q (ETH_HDR_LEN-Q_TAG_LEN)
#define IPV4_PROT_UDP 17

#define UDP_HDR_LEN 8
#define UDP_HDR_OFFSET (IPV4_HDR_OFFSET + IPV4_HDR_BASE_LEN)
#define UDP_HDR_OFFSET_NO_Q (IPV4_HDR_OFFSET_NO_Q + IPV4_HDR_BASE_LEN)


#define HDR_LEN (ETH_HDR_LEN + IPV4_HDR_BASE_LEN + UDP_HDR_LEN) // 20+20+8=48
#define HDR_LEN_NO_Q (HDR_LEN - Q_TAG_LEN)


// some help
#define UINT48_MAX 0xFFFFFFFFFFFF
// ethertypes
// const static ETH_TYPE_QVLAN = htons(0x8100);
// const static ETH_TYPE_IPV4 = htons(0x0800);
// const static ETH_TYPE_PTP = htons(0x88f7);
// in little endian order (networking always shows big endian)
#define ETH_TYPE_QVLAN 0x0081
#define ETH_TYPE_IPV4 0x0008
#define ETH_TYPE_PTP 0xf788


// predefined handles
#define PTP_HANDLE_PORT UINT16_MAX
#define PTP_HANDLE_QUEUE 0
// lets start by defining the handle struct
typedef struct {
    u8 queue;
    u16 port;
} TSNHandle_t;

// globally store IP and MAC
static u32 globalSourceIPv4;
// static u8 globalSourceIPv6[2*8];

static u64 globalSourceMAC;

// 

// lookup table for handles
// one handle per queue right now, but will do a u8 for each queue if I ever wanted to have some flags
static u8 appHandles [NUM_QUEUES]; 
// Flags could be, e.g., protocol support.
// Thats a good idea actually:
// this way the receive function can filter out any packet thats unsupported
#define HANDLE_FLAG_UDP 1<<1
#define HANDLE_FLAG_PTP_L2 1<<2



// I guess we'll need some kind of initialization
// This will set host MAC and IP addresses
// as well as set the schedule, but dont turn it on again
int TSNInit (uptr baseAddr, u64 sourceMAC, u32 sourceIPv4, ControlListEntry_t* sched0, ControlListEntry_t* sched1, u32 schedLen[2], u64 baseTime[2], u64 cycleTimeExt[2]);

// processing handles
// since we will store some capability flags for each handle, getHandle should get these flags
TSNHandle_t getHandle(u8 handleFlags);
int giveHandle(TSNHandle_t handle);

typedef struct {
    u64 MAC;
    u32 IPv4Addr;
    u16 port;
} UDPLoc_t;
// I guess we'll need to create some kind of send function
// but in order to send stuff we need to put headers around the data
// we can initialize most of the header on startup, since only some fields change between calls
int createUDPHeader (u8* pktBuf, UDPLoc_t dest, TSNHandle_t appHandle, u8* data, u16 dataLen);
// lets create a function for that
int sendUDPPacket (uptr baseAddr, UDPLoc_t dest, TSNHandle_t appHandle, u8* data, u16 dataLen);


// receiving
#define E_DECODE_MAC_ADDR 255
#define E_DECODE_ETH_TYPE 254
#define E_DECODE_IPV4_PROT 253
typedef struct {
    TSNHandle_t appHandle;
    u8 hdrLen;
    u8 protFlags;
    UDPLoc_t source;
    u16 dataLen;
} ingressMD_t; // TODO: bad name
// to map an ingress packet to an apphandle, we need to "decode" the header
// it will perform some checks, whether or not to throw away the packet
// if the function returns with 255 as its queue, packet is discarded
ingressMD_t decodePktHdr(u8* pktBuf);
// also define some reasons for discarding a packet

// Receive packet from a queue based on the handle
int receivePkt(uptr baseAddress, TSNHandle_t handle, u8* data, u16* len, UDPLoc_t* source);


// schedule stuff

// it would be a good idea to be able to switch to schedule 0 or 1 specifically
int enableSchedIdx(uptr baseAddr, u8 schedIdx);

u8 getActiveSchedIdx(uptr baseAddr);

int loadSchedule(uptr baseAddr, ControlListEntry_t* sched, u32 schedLen, u64 baseTime, u64 cycleTimeExt);