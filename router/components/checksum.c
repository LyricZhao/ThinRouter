# include "checksum.h"

uint16_t getChecksum(uint8_t *packet) {
  uint8_t ihl = (packet[0] & 0xf) << 2;
  uint32_t checksum = 0;
  for (uint8_t i = 0; i < ihl; i += 2) {
    if (i == 10) continue;
    checksum += PACKED8_16(packet[i], packet[i + 1]);
  }
  while (checksum >> 16) {
    checksum = (checksum >> 16) + (checksum & 0xffff);
  }
  checksum = 0xffff ^ checksum;
  return checksum;
}

uint8_t validateIPChecksum(uint8_t *packet, size_t len) {
  uint16_t old_checksum = PACKED8_16(packet[10], packet[11]);
  return getChecksum(packet) == old_checksum;
}