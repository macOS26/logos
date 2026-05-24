#ifndef LIBREVENGE_INTERNAL_H
#define LIBREVENGE_INTERNAL_H
#include "librevenge.h"
#define RVNG_NUM_ELEMENTS(array) (sizeof(array) / sizeof((array)[0]))
#ifdef DEBUG
#include <stdio.h>
#define RVNG_DEBUG_MSG(M) printf M
#else
#define RVNG_DEBUG_MSG(M)
#endif
class GenericException
{
};
#endif
