#pragma once
#include <cstdint>

typedef void* cmsHPROFILE;
typedef void* cmsHTRANSFORM;

#define TYPE_CMYK_16 0
#define TYPE_RGB_16 0
#define INTENT_PERCEPTUAL 0

static inline cmsHPROFILE cmsOpenProfileFromMem(const void*, uint32_t) { return (cmsHPROFILE)1; }
static inline cmsHPROFILE cmsCreate_sRGBProfile(void) { return (cmsHPROFILE)1; }
static inline cmsHTRANSFORM cmsCreateTransform(cmsHPROFILE, int, cmsHPROFILE, int, int, int) { return (cmsHTRANSFORM)1; }
static inline void cmsCloseProfile(cmsHPROFILE) {}
static inline void cmsDeleteTransform(cmsHTRANSFORM) {}

static inline void cmsDoTransform(cmsHTRANSFORM, const void* in, void* out, uint32_t) {
    const uint16_t* cmyk = (const uint16_t*)in;
    uint16_t* rgb = (uint16_t*)out;
    double c = cmyk[0] / 65535.0;
    double m = cmyk[1] / 65535.0;
    double y = cmyk[2] / 65535.0;
    double k = cmyk[3] / 65535.0;
    double r = (1.0 - c) * (1.0 - k);
    double g = (1.0 - m) * (1.0 - k);
    double b = (1.0 - y) * (1.0 - k);
    rgb[0] = (uint16_t)(r * 65535.0);
    rgb[1] = (uint16_t)(g * 65535.0);
    rgb[2] = (uint16_t)(b * 65535.0);
}
