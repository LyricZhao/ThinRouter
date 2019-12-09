# include "checksum.h"
# include "forwarding.h"

uint8_t forward(uint8_t *packet, size_t len) {
  if (!validateIPChecksum(packet, len)) {
    return 0;
  }

  packet[8] -= 1;
  uint16_t checksum = getChecksum(packet);
  packet[10] = checksum >> 8;
  packet[11] = checksum & 0xff;
  return 1;
}