#ifndef INCLUDED_LIBREVENGE_STREAM_LIBREVENGE_STREAM_API_H
#define INCLUDED_LIBREVENGE_STREAM_LIBREVENGE_STREAM_API_H
#ifdef DLL_EXPORT
#ifdef LIBREVENGE_STREAM_BUILD
#define REVENGE_STREAM_API __declspec(dllexport)
#else
#define REVENGE_STREAM_API __declspec(dllimport)
#endif
#else
#ifdef LIBREVENGE_STREAM_VISIBILITY
#define REVENGE_STREAM_API __attribute__((visibility("default")))
#else
#define REVENGE_STREAM_API
#endif
#endif
#endif
