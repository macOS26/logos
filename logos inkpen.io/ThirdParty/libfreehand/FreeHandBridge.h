#ifndef FREEHAND_BRIDGE_H
#define FREEHAND_BRIDGE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int freehand_is_supported(const unsigned char *data, size_t length);

int freehand_parse_to_svg(const unsigned char *data, size_t length, char **out_svg);

void freehand_free_svg(char *svg);

#ifdef __cplusplus
}
#endif

#endif
