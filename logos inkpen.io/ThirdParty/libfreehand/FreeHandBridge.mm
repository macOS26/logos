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
#include "RVNGStringVector.h"
#include "RVNGSVGDrawingGenerator.h"
#include <cstdlib>
#include <cstring>
#include <string>

int freehand_is_supported(const unsigned char *data, size_t length)
{
    if (!data || length == 0) return 0;
    librevenge::RVNGMemoryInputStream input(const_cast<unsigned char *>(data), (unsigned long)length);
    return libfreehand::FreeHandDocument::isSupported(&input) ? 1 : 0;
}

// libfreehand emits FreeHand blends as <pattern>s with base64 nested SVG, and emits
// regular gradient fills via xlink:href inheritance (grad1 defines stops, grad2 xlinks
// to grad1 with transform). InkPen's SVG parser supports neither, so paths fall back
// to solid black. Strip every fill: url(#...) so at least strokes remain visible.
static void stripUrlFills(std::string &svg)
{
    std::string::size_type pos = 0;
    const std::string needle = "fill: url(#";
    const std::string replacement = "fill: none";
    while ((pos = svg.find(needle, pos)) != std::string::npos) {
        std::string::size_type end = svg.find(')', pos);
        if (end == std::string::npos) break;
        svg.replace(pos, (end - pos) + 1, replacement);
        pos += replacement.size();
    }
}

int freehand_parse_to_svg(const unsigned char *data, size_t length, char **out_svg)
{
    if (!data || length == 0 || !out_svg) return 1;
    *out_svg = nullptr;

    librevenge::RVNGMemoryInputStream input(const_cast<unsigned char *>(data), (unsigned long)length);
    if (!libfreehand::FreeHandDocument::isSupported(&input)) return 2;

    librevenge::RVNGStringVector output;
    librevenge::RVNGSVGDrawingGenerator generator(output, "");
    if (!libfreehand::FreeHandDocument::parse(&input, &generator)) return 3;
    if (output.empty() || output[0].empty()) return 4;

    std::string svg;
    svg.reserve(output[0].size() + 128);
    svg.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n");
    svg.append(output[0].cstr());
    stripUrlFills(svg);

    char *buf = (char *)std::malloc(svg.size() + 1);
    if (!buf) return 5;
    std::memcpy(buf, svg.data(), svg.size());
    buf[svg.size()] = '\0';
    *out_svg = buf;
    return 0;
}

void freehand_free_svg(char *svg)
{
    if (svg) std::free(svg);
}
#pragma clang diagnostic pop
