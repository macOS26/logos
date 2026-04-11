#pragma once
#include <cstdint>

typedef int32_t UChar32;
typedef uint16_t UChar;

#define U8_MAX_LENGTH 4

#define U8_APPEND_UNSAFE(buf, i, c) do { \
    uint32_t __u8c = (uint32_t)(c); \
    if (__u8c < 0x80) { \
        (buf)[(i)++] = (uint8_t)__u8c; \
    } else if (__u8c < 0x800) { \
        (buf)[(i)++] = (uint8_t)((__u8c >> 6) | 0xC0); \
        (buf)[(i)++] = (uint8_t)((__u8c & 0x3F) | 0x80); \
    } else if (__u8c < 0x10000) { \
        (buf)[(i)++] = (uint8_t)((__u8c >> 12) | 0xE0); \
        (buf)[(i)++] = (uint8_t)(((__u8c >> 6) & 0x3F) | 0x80); \
        (buf)[(i)++] = (uint8_t)((__u8c & 0x3F) | 0x80); \
    } else { \
        (buf)[(i)++] = (uint8_t)((__u8c >> 18) | 0xF0); \
        (buf)[(i)++] = (uint8_t)(((__u8c >> 12) & 0x3F) | 0x80); \
        (buf)[(i)++] = (uint8_t)(((__u8c >> 6) & 0x3F) | 0x80); \
        (buf)[(i)++] = (uint8_t)((__u8c & 0x3F) | 0x80); \
    } \
} while(0)

#define U16_NEXT(s, i, length, c) do { \
    (c) = (s)[(i)++]; \
    if ((c) >= 0xD800 && (c) <= 0xDBFF && (i) < (length)) { \
        uint32_t __u16low = (s)[(i)]; \
        if (__u16low >= 0xDC00 && __u16low <= 0xDFFF) { \
            (c) = (((c) - 0xD800) << 10) + (__u16low - 0xDC00) + 0x10000; \
            (i)++; \
        } \
    } \
} while(0)
