# ifndef __PROTOCOL_H__
# define __PROTOCOL_H__

# include <arpa/inet.h>
# include <stdio.h>
# include <stdint.h>
# include <stdlib.h>

# include "../include/utility.h"
# include "../include/rip_pack.h"

uint8_t validateMask(uint32_t mask);
uint8_t disassemble(const uint8_t *packet, uint32_t len, RipPacket *output);
uint32_t assemble(const RipPacket *rip, uint8_t *buffer);

# endif