#ifndef INCLUDED_LIBREVENGE_LIBREVENGE_API_H
#define INCLUDED_LIBREVENGE_LIBREVENGE_API_H
#ifdef DLL_EXPORT
#ifdef LIBREVENGE_BUILD
#define REVENGE_API __declspec(dllexport)
#else
#define REVENGE_API __declspec(dllimport)
#endif
#else
#ifdef LIBREVENGE_VISIBILITY
#define REVENGE_API __attribute__((visibility("default")))
#else
#define REVENGE_API
#endif
#endif
#ifdef __GNUC__
#define REVENGE_ATTRIBUTE_PRINTF(fmt, arg) __attribute__((format(printf, fmt, arg)))
#else
#define REVENGE_ATTRIBUTE_PRINTF(fmt, arg)
#endif
#endif
