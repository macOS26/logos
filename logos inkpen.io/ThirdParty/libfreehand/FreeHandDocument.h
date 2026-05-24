#ifndef __FREEHANDDOCUMENT_H__
#define __FREEHANDDOCUMENT_H__
#include "librevenge.h"
#ifdef DLL_EXPORT
#ifdef LIBFREEHAND_BUILD
#define FHAPI __declspec(dllexport)
#else
#define FHAPI __declspec(dllimport)
#endif
#else
#ifdef LIBFREEHAND_VISIBILITY
#define FHAPI __attribute__((visibility("default")))
#else
#define FHAPI
#endif
#endif
namespace libfreehand
{
class FreeHandDocument
{
public:
  static FHAPI bool isSupported(librevenge::RVNGInputStream *input);
  static FHAPI bool parse(librevenge::RVNGInputStream *input, librevenge::RVNGDrawingInterface *painter);
};
}
#endif
