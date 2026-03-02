/*
 * Standalone C implementations of crc10, crc13, crc14
 * for ARM64 cross-compilation (replaces Boost-dependent C++ versions).
 *
 * These implement the same augmented CRC algorithm as
 * boost::augmented_crc<N, POLY>(data, length).
 *
 * Algorithm: bit-by-bit augmented CRC (MSB first).
 * The data includes CRC bytes appended at the end (set to 0 for generation).
 */

#include <string.h>

/* Generic augmented CRC, bit-by-bit, MSB first */
static unsigned long augmented_crc(int bits, unsigned long poly,
                                   const unsigned char *data, int length)
{
    unsigned long crc = 0;
    unsigned long mask = (1UL << bits) - 1;
    unsigned long topbit = 1UL << (bits - 1);
    int i, j;

    for (i = 0; i < length; i++) {
        for (j = 7; j >= 0; j--) {
            int bit = (data[i] >> j) & 1;
            int overflow = (crc & topbit) != 0;
            crc = ((crc << 1) | bit) & mask;
            if (overflow) {
                crc ^= poly;
            }
        }
    }
    return crc & mask;
}

/* CRC-10, polynomial 0x08f */
short crc10(const unsigned char *data, int length)
{
    return (short)augmented_crc(10, 0x08f, data, length);
}

int crc10_check(const unsigned char *data, int length)
{
    return augmented_crc(10, 0x08f, data, length) == 0;
}

/* CRC-13, polynomial 0x15D7 */
short crc13(const unsigned char *data, int length)
{
    return (short)augmented_crc(13, 0x15D7, data, length);
}

int crc13_check(const unsigned char *data, int length)
{
    return augmented_crc(13, 0x15D7, data, length) == 0;
}

/* CRC-14, polynomial 0x2757 */
short crc14(const unsigned char *data, int length)
{
    return (short)augmented_crc(14, 0x2757, data, length);
}

int crc14_check(const unsigned char *data, int length)
{
    return augmented_crc(14, 0x2757, data, length) == 0;
}
