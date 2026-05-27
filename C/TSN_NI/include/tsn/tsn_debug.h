#ifndef TSN_DEBUG_H
#define TSN_DEBUGH_H

#include "types.h"

int sendDebug(uptr baseAddress, u32* packet, u16 length);

// Receiving a packet. 
int receiveDebug(uptr baseAddress, u8* buffer, u8 queue, u16* len);

u32 readRegister(uptr baseAddress, uptr offset);

#endif