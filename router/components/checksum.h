# ifndef __CHECKSUM_H__
# define __CHECKSUM_H__

# include <stdint.h>
# include <stdlib.h>

# include "../utilities/utility.h"

uint8_t validateIPChecksum(uint8_t *packet, size_t len);

# endif