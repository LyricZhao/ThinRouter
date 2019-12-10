# ifndef __CHECKSUM_H__
# define __CHECKSUM_H__

# include <stdint.h>
# include <stdlib.h>

# include "../include/utility.h"

uint16_t getChecksum(uint8_t *packet);
uint8_t validateIPChecksum(uint8_t *packet, size_t len);

# endif