/* InkpenCollectorView — POD view over FHCollector's private maps for the direct translator.
   Populated by FHCollector::inkpenBuildView so the InkPen translator can walk FreeHand
   records without going through librevenge's SVG generator. Phase 1 only carries the
   maps needed for plain FHPath emission; later phases extend the struct. */

#ifndef INKPEN_COLLECTOR_VIEW_H
#define INKPEN_COLLECTOR_VIEW_H

#include <map>
#include "FHTypes.h"
#include "FHPath.h"
#include "FHTransform.h"

namespace libfreehand {

struct InkpenCollectorView
{
  const FHPageInfo *pageInfo;
  const FHTail *fhTail;
  const std::pair<unsigned, FHBlock> *block;

  const std::map<unsigned, FHList> *lists;
  const std::map<unsigned, FHLayer> *layers;
  const std::map<unsigned, FHPath> *paths;
  const std::map<unsigned, FHGroup> *groups;
  const std::map<unsigned, FHGroup> *clipGroups;
  const std::map<unsigned, FHCompositePath> *compositePaths;
  const std::map<unsigned, FHTransform> *transforms;
  const std::map<unsigned, FHGraphicStyle> *graphicStyles;
  const std::map<unsigned, FHPropList> *propertyLists;
  const std::map<unsigned, FHBasicFill> *basicFills;
  const std::map<unsigned, FHLinearFill> *linearFills;
  const std::map<unsigned, FHRadialFill> *radialFills;
  const std::map<unsigned, FHLensFill> *lensFills;
  const std::map<unsigned, FHTileFill> *tileFills;
  const std::map<unsigned, FHPatternFill> *patternFills;
  const std::map<unsigned, FHBasicLine> *basicLines;
  const std::map<unsigned, FHPatternLine> *patternLines;
  const std::map<unsigned, FHLinePattern> *linePatterns;
  const std::map<unsigned, FHRGBColor> *rgbColors;
  const std::map<unsigned, FHTintColor> *tints;
  const std::map<unsigned, std::vector<FHColorStop>> *multiColorLists;
  const std::map<unsigned, FHAttributeHolder> *attributeHolders;
  const std::map<unsigned, FHFilterAttributeHolder> *filterAttributeHolders;
  const std::map<unsigned, double> *opacityFilters;
  const std::map<unsigned, FHNewBlend> *newBlends;
  const std::map<unsigned, FHSymbolClass> *symbolClasses;
  const std::map<unsigned, FHSymbolInstance> *symbolInstances;

  /* Session token IDs assigned when the parser sees the "fill"/"stroke"/"content"
     attribute names. Needed to probe FHPropList::m_elements and FHGraphicStyle::m_elements. */
  unsigned fillId;
  unsigned strokeId;
  unsigned contentId;

  InkpenCollectorView()
    : pageInfo(nullptr), fhTail(nullptr), block(nullptr),
      lists(nullptr), layers(nullptr), paths(nullptr),
      groups(nullptr), clipGroups(nullptr), compositePaths(nullptr),
      transforms(nullptr), graphicStyles(nullptr), propertyLists(nullptr),
      basicFills(nullptr), linearFills(nullptr), radialFills(nullptr),
      lensFills(nullptr), tileFills(nullptr), patternFills(nullptr),
      basicLines(nullptr), patternLines(nullptr), linePatterns(nullptr),
      rgbColors(nullptr), tints(nullptr), multiColorLists(nullptr),
      attributeHolders(nullptr), filterAttributeHolders(nullptr), opacityFilters(nullptr),
      newBlends(nullptr), symbolClasses(nullptr), symbolInstances(nullptr),
      fillId(0), strokeId(0), contentId(0) {}
};

} // namespace libfreehand

#endif
