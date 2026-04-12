#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#pragma clang diagnostic ignored "-Wloop-analysis"
#pragma clang diagnostic ignored "-Wsign-conversion"
#pragma clang diagnostic ignored "-Wimplicit-int-conversion"
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#include "FreeHandBridge.h"
#include "libfreehand.h"
#include "RVNGMemoryStream.h"

int freehand_is_supported(const unsigned char *data, size_t length)
{
    if (!data || length == 0) return 0;
    librevenge::RVNGMemoryInputStream input(const_cast<unsigned char *>(data), (unsigned long)length);
    return libfreehand::FreeHandDocument::isSupported(&input) ? 1 : 0;
}
#pragma clang diagnostic pop
