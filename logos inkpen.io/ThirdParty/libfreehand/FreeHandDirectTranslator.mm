#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#pragma clang diagnostic ignored "-Wloop-analysis"
#pragma clang diagnostic ignored "-Wsign-conversion"
#pragma clang diagnostic ignored "-Wimplicit-int-conversion"
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#include "FreeHandBridge.h"
#include "libfreehand.h"
#include "FHCollector.h"
#include "FHParser.h"
#include "FHPath.h"
#include "FHTransform.h"
#include "FHTypes.h"
#include "InkpenCollectorView.h"
#include "RVNGMemoryStream.h"
#include "librevenge.h"

#include <cmath>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <vector>
#include <deque>
#include <set>

namespace {

struct FHResultPathElement
{
    int kind;          // FH_PATH_*
    double x, y;       // endpoint
    double x1, y1;     // first control (cubic/quad)
    double x2, y2;     // second control (cubic)
};

struct FHResultColor
{
    bool present;
    double r, g, b, a;
    FHResultColor() : present(false), r(0), g(0), b(0), a(1) {}
};

struct FHResultGradientStop
{
    double position;
    double r, g, b, a;
    FHResultGradientStop() : position(0), r(0), g(0), b(0), a(1) {}
};

/* Fill kinds come from FreeHandBridge.h (FH_FILL_NONE/SOLID/LINEAR/RADIAL). */

struct FHResultShape
{
    int kind;
    bool isClosed;
    bool evenOdd;
    std::vector<FHResultPathElement> elements;

    int fillKind;
    FHResultColor fill;
    std::vector<FHResultGradientStop> gradientStops;
    double fillAngle;
    double fillCenterX;
    double fillCenterY;

    FHResultColor stroke;
    double strokeWidth;
    double opacity;
    /* For group / clipGroup / compound containers: indices of member shapes
       within the same fh_result::shapes array. Children are always emitted
       before their container, so these indices are < containerIndex. */
    std::vector<size_t> memberIndices;

    FHResultShape()
        : kind(FH_SHAPE_KIND_PATH), isClosed(false), evenOdd(false),
          elements(),
          fillKind(FH_FILL_NONE), fill(), gradientStops(),
          fillAngle(0.0), fillCenterX(0.5), fillCenterY(0.5),
          stroke(), strokeWidth(0.0), opacity(1.0),
          memberIndices() {}
};

} // namespace

struct fh_result
{
    std::vector<FHResultShape> shapes;
    double pageWidth;
    double pageHeight;

    /* Diagnostic counts filled by the walker and logged by Swift. */
    size_t statPaths;
    size_t statGroups;
    size_t statClipGroups;
    size_t statCompositePaths;
    size_t statNewBlends;
    size_t statSymbolInstances;
    size_t statContentIdPaths;

    fh_result() : shapes(), pageWidth(0.0), pageHeight(0.0),
                  statPaths(0), statGroups(0), statClipGroups(0),
                  statCompositePaths(0), statNewBlends(0),
                  statSymbolInstances(0), statContentIdPaths(0) {}
};

namespace {

/* Resolve an attribute map (m_elements on FHPropList / FHGraphicStyle) by walking
   the parent chain. Returns the terminal value or 0 if not found. */
template <typename MapT>
unsigned resolveElement(const libfreehand::InkpenCollectorView &view,
                        const MapT &map,
                        unsigned startId,
                        unsigned attrId,
                        std::set<unsigned> &visited)
{
    unsigned curId = startId;
    while (curId && visited.find(curId) == visited.end())
    {
        visited.insert(curId);
        auto it = map.find(curId);
        if (it == map.end()) return 0;
        auto found = it->second.m_elements.find(attrId);
        if (found != it->second.m_elements.end()) return found->second;
        curId = it->second.m_parentId;
    }
    return 0;
}

unsigned resolveAttributeId(const libfreehand::InkpenCollectorView &view,
                            unsigned graphicStyleId,
                            unsigned attrTokenId)
{
    if (!attrTokenId || !graphicStyleId) return 0;

    std::set<unsigned> visited;
    if (view.graphicStyles)
    {
        unsigned v = resolveElement(view, *view.graphicStyles, graphicStyleId, attrTokenId, visited);
        if (v) return v;
    }
    visited.clear();
    if (view.propertyLists)
    {
        unsigned v = resolveElement(view, *view.propertyLists, graphicStyleId, attrTokenId, visited);
        if (v) return v;
    }
    return 0;
}

FHResultColor rgbFromColorId(const libfreehand::InkpenCollectorView &view, unsigned colorId, int depth)
{
    FHResultColor out;
    if (!colorId || depth > 8) return out;

    if (view.rgbColors)
    {
        auto it = view.rgbColors->find(colorId);
        if (it != view.rgbColors->end())
        {
            const libfreehand::FHRGBColor &c = it->second;
            out.r = double(c.m_red) / 65535.0;
            out.g = double(c.m_green) / 65535.0;
            out.b = double(c.m_blue) / 65535.0;
            out.a = 1.0;
            out.present = true;
            return out;
        }
    }
    if (view.tints)
    {
        auto it = view.tints->find(colorId);
        if (it != view.tints->end())
        {
            FHResultColor base = rgbFromColorId(view, it->second.m_baseColorId, depth + 1);
            if (base.present)
            {
                double t = double(it->second.m_tint) / 100.0;
                if (t < 0) t = 0;
                if (t > 1) t = 1;
                base.r = base.r * t + (1.0 - t);
                base.g = base.g * t + (1.0 - t);
                base.b = base.b * t + (1.0 - t);
                return base;
            }
        }
    }
    return out;
}

void buildGradientStopsFromMultiColor(const libfreehand::InkpenCollectorView &view,
                                       unsigned multiColorListId,
                                       std::vector<FHResultGradientStop> &out)
{
    if (!multiColorListId || !view.multiColorLists) return;
    auto it = view.multiColorLists->find(multiColorListId);
    if (it == view.multiColorLists->end()) return;
    for (const libfreehand::FHColorStop &src : it->second)
    {
        FHResultColor rgb = rgbFromColorId(view, src.m_colorId, 0);
        FHResultGradientStop stop;
        stop.position = src.m_position;
        if (stop.position < 0) stop.position = 0;
        if (stop.position > 1) stop.position = 1;
        stop.r = rgb.r; stop.g = rgb.g; stop.b = rgb.b; stop.a = rgb.a;
        out.push_back(stop);
    }
}

void buildGradientStopsFromPair(const libfreehand::InkpenCollectorView &view,
                                 unsigned color1Id, unsigned color2Id,
                                 std::vector<FHResultGradientStop> &out)
{
    FHResultColor c1 = rgbFromColorId(view, color1Id, 0);
    FHResultColor c2 = rgbFromColorId(view, color2Id, 0);
    FHResultGradientStop s0, s1;
    s0.position = 0.0; s0.r = c1.r; s0.g = c1.g; s0.b = c1.b; s0.a = c1.a;
    s1.position = 1.0; s1.r = c2.r; s1.g = c2.g; s1.b = c2.b; s1.a = c2.a;
    out.push_back(s0);
    out.push_back(s1);
}

/* Walk a FHTileFill's referenced group to find a representative color for the
   solid fallback. Uses the first BasicFill encountered in the group's children. */
FHResultColor firstBasicFillInGroup(const libfreehand::InkpenCollectorView &view, unsigned groupId, int depth);

FHResultColor firstBasicFillInPathStyle(const libfreehand::InkpenCollectorView &view, unsigned gsId)
{
    if (!gsId) return FHResultColor();
    unsigned fillRecId = resolveAttributeId(view, gsId, view.fillId);
    if (!fillRecId || !view.basicFills) return FHResultColor();
    auto it = view.basicFills->find(fillRecId);
    if (it == view.basicFills->end()) return FHResultColor();
    return rgbFromColorId(view, it->second.m_colorId, 0);
}

FHResultColor firstBasicFillInGroup(const libfreehand::InkpenCollectorView &view, unsigned groupId, int depth)
{
    if (!groupId || depth > 4 || !view.groups || !view.lists) return FHResultColor();
    auto git = view.groups->find(groupId);
    if (git == view.groups->end()) return FHResultColor();
    auto lit = view.lists->find(git->second.m_elementsId);
    if (lit == view.lists->end()) return FHResultColor();
    for (unsigned elemId : lit->second.m_elements)
    {
        if (view.paths)
        {
            auto pit = view.paths->find(elemId);
            if (pit != view.paths->end())
            {
                FHResultColor c = firstBasicFillInPathStyle(view, pit->second.getGraphicStyleId());
                if (c.present) return c;
            }
        }
        if (view.groups)
        {
            FHResultColor c = firstBasicFillInGroup(view, elemId, depth + 1);
            if (c.present) return c;
        }
    }
    return FHResultColor();
}

/* Resolve a graphicStyleId's fill into `shape`. Handles BasicFill as solid,
   LinearFill/RadialFill as gradients, TileFill/PatternFill/LensFill as
   dominant-color solid fallbacks. Leaves fillKind=FH_FILL_NONE when nothing
   resolves so callers can decide whether to drop the shape or apply a stroke. */
void resolveFillIntoShape(const libfreehand::InkpenCollectorView &view,
                          unsigned graphicStyleId,
                          FHResultShape &shape)
{
    if (!graphicStyleId) return;

    unsigned fillRecId = resolveAttributeId(view, graphicStyleId, view.fillId);
    if (!fillRecId) return;

    if (view.basicFills)
    {
        auto it = view.basicFills->find(fillRecId);
        if (it != view.basicFills->end())
        {
            shape.fill = rgbFromColorId(view, it->second.m_colorId, 0);
            if (shape.fill.present) shape.fillKind = FH_FILL_SOLID;
            return;
        }
    }
    if (view.linearFills)
    {
        auto it = view.linearFills->find(fillRecId);
        if (it != view.linearFills->end())
        {
            buildGradientStopsFromMultiColor(view, it->second.m_multiColorListId, shape.gradientStops);
            if (shape.gradientStops.empty())
                buildGradientStopsFromPair(view, it->second.m_color1Id, it->second.m_color2Id, shape.gradientStops);
            shape.fillAngle = 90.0 - it->second.m_angle; // FH degrees → InkPen convention
            shape.fillKind = FH_FILL_LINEAR;
            return;
        }
    }
    if (view.radialFills)
    {
        auto it = view.radialFills->find(fillRecId);
        if (it != view.radialFills->end())
        {
            buildGradientStopsFromMultiColor(view, it->second.m_multiColorListId, shape.gradientStops);
            if (shape.gradientStops.empty())
                buildGradientStopsFromPair(view, it->second.m_color1Id, it->second.m_color2Id, shape.gradientStops);
            shape.fillCenterX = it->second.m_cx;
            shape.fillCenterY = it->second.m_cy;
            shape.fillKind = FH_FILL_RADIAL;
            return;
        }
    }
    if (view.patternFills)
    {
        auto it = view.patternFills->find(fillRecId);
        if (it != view.patternFills->end())
        {
            shape.fill = rgbFromColorId(view, it->second.m_colorId, 0);
            if (shape.fill.present) shape.fillKind = FH_FILL_SOLID;
            return;
        }
    }
    if (view.lensFills)
    {
        auto it = view.lensFills->find(fillRecId);
        if (it != view.lensFills->end())
        {
            shape.fill = rgbFromColorId(view, it->second.m_colorId, 0);
            if (shape.fill.present) shape.fillKind = FH_FILL_SOLID;
            return;
        }
    }
    if (view.tileFills)
    {
        auto it = view.tileFills->find(fillRecId);
        if (it != view.tileFills->end())
        {
            shape.fill = firstBasicFillInGroup(view, it->second.m_groupId, 0);
            if (shape.fill.present) shape.fillKind = FH_FILL_SOLID;
            return;
        }
    }
}

struct StrokeResult
{
    FHResultColor color;
    double width;
    bool present;
    StrokeResult() : color(), width(0.0), present(false) {}
};

StrokeResult resolveStroke(const libfreehand::InkpenCollectorView &view, unsigned graphicStyleId)
{
    StrokeResult out;
    if (!graphicStyleId) return out;

    unsigned strokeRecId = resolveAttributeId(view, graphicStyleId, view.strokeId);
    if (!strokeRecId) return out;

    if (view.basicLines)
    {
        auto it = view.basicLines->find(strokeRecId);
        if (it != view.basicLines->end())
        {
            out.color = rgbFromColorId(view, it->second.m_colorId, 0);
            out.width = it->second.m_width;
            out.present = out.color.present || out.width > 0;
            return out;
        }
    }
    if (view.patternLines)
    {
        auto it = view.patternLines->find(strokeRecId);
        if (it != view.patternLines->end())
        {
            out.color = rgbFromColorId(view, it->second.m_colorId, 0);
            out.width = it->second.m_width;
            out.present = out.color.present || out.width > 0;
            return out;
        }
    }
    return out;
}

double resolveOpacity(const libfreehand::InkpenCollectorView &view, unsigned graphicStyleId)
{
    if (!graphicStyleId || !view.filterAttributeHolders || !view.opacityFilters)
        return 1.0;

    std::set<unsigned> visited;
    unsigned curId = graphicStyleId;
    while (curId && visited.find(curId) == visited.end())
    {
        visited.insert(curId);
        auto it = view.filterAttributeHolders->find(curId);
        if (it == view.filterAttributeHolders->end()) break;
        if (it->second.m_filterId)
        {
            auto op = view.opacityFilters->find(it->second.m_filterId);
            if (op != view.opacityFilters->end()) return op->second;
        }
        curId = it->second.m_parentId;
    }
    return 1.0;
}

/* FreeHand stores coordinates in inches. librevenge multiplies by 72 to convert
   to PostScript points when emitting SVG; the direct translator has to do the
   same scaling so shapes land in InkPen's point space. Also flips Y and offsets
   by the page origin so the result is top-left-origin (Y grows downward). */
static constexpr double FH_POINTS_PER_INCH = 72.0;

libfreehand::FHTransform makeNormalizeTransform(const libfreehand::FHPageInfo &page)
{
    return libfreehand::FHTransform(
        FH_POINTS_PER_INCH, 0.0,
        0.0, -FH_POINTS_PER_INCH,
        -FH_POINTS_PER_INCH * page.m_minX,
        FH_POINTS_PER_INCH * page.m_maxY
    );
}

/* Build a per-element FHResultPathElement list by calling FHPath::writeOut into
   a librevenge property list vector and reading back the path-action keys. */
void flattenPath(const libfreehand::FHPath &path,
                 const std::vector<libfreehand::FHTransform> &xforms,
                 const libfreehand::FHTransform &normalize,
                 FHResultShape &out)
{
    libfreehand::FHPath working(path);
    for (auto rit = xforms.rbegin(); rit != xforms.rend(); ++rit)
        working.transform(*rit);
    working.transform(normalize);

    librevenge::RVNGPropertyListVector vec;
    working.writeOut(vec);

    out.isClosed = working.isClosed();
    out.evenOdd = working.getEvenOdd();

    for (unsigned long i = 0; i < vec.count(); ++i)
    {
        const librevenge::RVNGPropertyList &node = vec[i];
        const librevenge::RVNGProperty *actionProp = node["librevenge:path-action"];
        if (!actionProp) continue;
        librevenge::RVNGString action = actionProp->getStr();
        if (action.empty()) continue;

        FHResultPathElement el;
        el.x = el.y = el.x1 = el.y1 = el.x2 = el.y2 = 0.0;

        char first = action.cstr()[0];
        switch (first)
        {
        case 'M':
            el.kind = FH_PATH_MOVE;
            if (auto *p = node["svg:x"]) el.x = p->getDouble();
            if (auto *p = node["svg:y"]) el.y = p->getDouble();
            break;
        case 'L':
            el.kind = FH_PATH_LINE;
            if (auto *p = node["svg:x"]) el.x = p->getDouble();
            if (auto *p = node["svg:y"]) el.y = p->getDouble();
            break;
        case 'C':
            el.kind = FH_PATH_CUBIC;
            if (auto *p = node["svg:x1"]) el.x1 = p->getDouble();
            if (auto *p = node["svg:y1"]) el.y1 = p->getDouble();
            if (auto *p = node["svg:x2"]) el.x2 = p->getDouble();
            if (auto *p = node["svg:y2"]) el.y2 = p->getDouble();
            if (auto *p = node["svg:x"]) el.x = p->getDouble();
            if (auto *p = node["svg:y"]) el.y = p->getDouble();
            break;
        case 'Q':
            el.kind = FH_PATH_QUAD;
            if (auto *p = node["svg:x1"]) el.x1 = p->getDouble();
            if (auto *p = node["svg:y1"]) el.y1 = p->getDouble();
            if (auto *p = node["svg:x"]) el.x = p->getDouble();
            if (auto *p = node["svg:y"]) el.y = p->getDouble();
            break;
        case 'A':
            // Phase 1: approximate an arc as a straight line to its endpoint.
            // Phase 2+ can flatten to cubic Beziers. Arcs are rare in FH files.
            el.kind = FH_PATH_LINE;
            if (auto *p = node["svg:x"]) el.x = p->getDouble();
            if (auto *p = node["svg:y"]) el.y = p->getDouble();
            break;
        case 'Z':
            el.kind = FH_PATH_CLOSE;
            break;
        default:
            continue;
        }
        out.elements.push_back(el);
    }
}

/* FH3-era files leave m_pageInfo uninitialized and store the real page bounds
   on m_fhTail.m_pageInfo instead. Pick the first one with non-zero extent so
   the Y-flip normalize transform pivots on the correct maxY. */
const libfreehand::FHPageInfo &effectivePageInfo(const libfreehand::InkpenCollectorView &v)
{
    const libfreehand::FHPageInfo *primary = v.pageInfo;
    bool primaryUsable = primary && (primary->m_maxX > primary->m_minX || primary->m_maxY > primary->m_minY);
    if (primaryUsable) return *primary;
    if (v.fhTail) return v.fhTail->m_pageInfo;
    static libfreehand::FHPageInfo zero;
    return zero;
}

struct WalkContext
{
    const libfreehand::InkpenCollectorView &view;
    libfreehand::FHTransform normalize;
    std::vector<libfreehand::FHTransform> xformStack;
    std::set<unsigned> visited;
    fh_result &result;

    /* Diagnostic counters for debugging what the walker is finding. */
    size_t statPaths;
    size_t statGroups;
    size_t statClipGroups;
    size_t statCompositePaths;
    size_t statNewBlends;
    size_t statSymbolInstances;
    size_t statContentIdPaths;

    WalkContext(const libfreehand::InkpenCollectorView &v, fh_result &r)
        : view(v), normalize(makeNormalizeTransform(effectivePageInfo(v))),
          xformStack(), visited(), result(r),
          statPaths(0), statGroups(0), statClipGroups(0), statCompositePaths(0),
          statNewBlends(0), statSymbolInstances(0), statContentIdPaths(0) {}
};

/* Forward decls for the mutually-recursive walkers. */
void walkSomething(unsigned id, WalkContext &ctx);
size_t walkPath(const libfreehand::FHPath *path, WalkContext &ctx);
size_t walkGroup(const libfreehand::FHGroup *group, WalkContext &ctx, bool asClipGroup);
size_t walkCompositePath(const libfreehand::FHCompositePath *cp, WalkContext &ctx);
size_t walkNewBlend(const libfreehand::FHNewBlend *nb, WalkContext &ctx);
size_t walkSymbolInstance(const libfreehand::FHSymbolInstance *sym, WalkContext &ctx);
void walkListElements(unsigned listId, std::vector<size_t> &childIndices, WalkContext &ctx);
void walkLeafElementsForClipGroup(unsigned elementsListId, std::vector<size_t> &out, WalkContext &ctx);

size_t emitPathShape(const libfreehand::FHPath *path, WalkContext &ctx, bool forceCompound)
{
    if (!path || path->empty()) return SIZE_MAX;

    FHResultShape shape;
    shape.kind = forceCompound ? FH_SHAPE_KIND_COMPOUND_PATH : FH_SHAPE_KIND_PATH;

    std::vector<libfreehand::FHTransform> xforms = ctx.xformStack;
    if (path->getXFormId() && ctx.view.transforms)
    {
        auto xt = ctx.view.transforms->find(path->getXFormId());
        if (xt != ctx.view.transforms->end())
            xforms.push_back(xt->second);
    }

    flattenPath(*path, xforms, ctx.normalize, shape);
    if (shape.elements.empty()) return SIZE_MAX;

    unsigned gsId = path->getGraphicStyleId();
    resolveFillIntoShape(ctx.view, gsId, shape);
    StrokeResult st = resolveStroke(ctx.view, gsId);
    shape.stroke = st.color;
    shape.strokeWidth = st.width * FH_POINTS_PER_INCH;
    shape.opacity = resolveOpacity(ctx.view, gsId);

    ctx.result.shapes.push_back(shape);
    return ctx.result.shapes.size() - 1;
}

size_t walkPath(const libfreehand::FHPath *path, WalkContext &ctx)
{
    ctx.statPaths++;
    /* Check if the path's graphic style has a contentId — meaning FH wants to
       render nested content (e.g., a tile fill group) clipped by this path.
       Count it so we can diagnose whether CrnkBait uses this pattern. */
    if (path && ctx.view.contentId)
    {
        unsigned gsId = path->getGraphicStyleId();
        std::set<unsigned> visited;
        if (ctx.view.propertyLists)
        {
            unsigned contentId = resolveElement(ctx.view, *ctx.view.propertyLists, gsId, ctx.view.contentId, visited);
            if (contentId) ctx.statContentIdPaths++;
        }
    }
    return emitPathShape(path, ctx, false);
}

size_t walkCompositePath(const libfreehand::FHCompositePath *cp, WalkContext &ctx)
{
    if (!cp || !ctx.view.lists) return SIZE_MAX;
    ctx.statCompositePaths++;

    auto listIt = ctx.view.lists->find(cp->m_elementsId);
    if (listIt == ctx.view.lists->end()) return SIZE_MAX;

    /* Merge all child FHPath geometries into one FHPath so the composite renders
       as a single CGPath with its fill rule applied. This mirrors how the SVG
       parser flattens multi-move-to paths into compound shapes. */
    libfreehand::FHPath merged;
    bool anyEvenOdd = false;
    unsigned inheritGsId = cp->m_graphicStyleId;

    for (unsigned elemId : listIt->second.m_elements)
    {
        if (!ctx.view.paths) continue;
        auto pathIt = ctx.view.paths->find(elemId);
        if (pathIt == ctx.view.paths->end()) continue;

        libfreehand::FHPath child(pathIt->second);
        if (child.getEvenOdd()) anyEvenOdd = true;
        if (child.getXFormId() && ctx.view.transforms)
        {
            auto xt = ctx.view.transforms->find(child.getXFormId());
            if (xt != ctx.view.transforms->end())
                child.transform(xt->second);
        }
        merged.appendPath(child);
        if (!inheritGsId) inheritGsId = child.getGraphicStyleId();
    }

    if (merged.empty()) return SIZE_MAX;
    merged.setEvenOdd(anyEvenOdd);
    merged.setGraphicStyleId(inheritGsId);
    return emitPathShape(&merged, ctx, true);
}

/* Recursively walks the elements of a clip group, flattening nested Groups and
   nested ClipGroups so the result is a flat list of leaf shape indices (paths,
   composite paths, blends, symbol instances). Native InkPen clipping groups
   require the mask + content all to be direct child shapes, never a group.
   The first leaf in the flat list is FreeHand's clip mask (FH convention). */
void walkLeafElementsForClipGroup(unsigned elementsListId, std::vector<size_t> &out, WalkContext &ctx)
{
    if (!ctx.view.lists) return;
    auto listIt = ctx.view.lists->find(elementsListId);
    if (listIt == ctx.view.lists->end()) return;
    for (unsigned elemId : listIt->second.m_elements)
    {
        /* Nested Group → descend into its elements directly, preserving xform. */
        if (ctx.view.groups)
        {
            auto git = ctx.view.groups->find(elemId);
            if (git != ctx.view.groups->end())
            {
                bool pushed = false;
                if (git->second.m_xFormId && ctx.view.transforms)
                {
                    auto xt = ctx.view.transforms->find(git->second.m_xFormId);
                    if (xt != ctx.view.transforms->end())
                    {
                        ctx.xformStack.push_back(xt->second);
                        pushed = true;
                    }
                }
                walkLeafElementsForClipGroup(git->second.m_elementsId, out, ctx);
                if (pushed) ctx.xformStack.pop_back();
                continue;
            }
        }
        /* Nested ClipGroup inside a ClipGroup → also flatten. Native InkPen
           clipping groups can't contain other clipping groups as members. */
        if (ctx.view.clipGroups)
        {
            auto git = ctx.view.clipGroups->find(elemId);
            if (git != ctx.view.clipGroups->end())
            {
                bool pushed = false;
                if (git->second.m_xFormId && ctx.view.transforms)
                {
                    auto xt = ctx.view.transforms->find(git->second.m_xFormId);
                    if (xt != ctx.view.transforms->end())
                    {
                        ctx.xformStack.push_back(xt->second);
                        pushed = true;
                    }
                }
                walkLeafElementsForClipGroup(git->second.m_elementsId, out, ctx);
                if (pushed) ctx.xformStack.pop_back();
                continue;
            }
        }
        /* Leaf or other type — walk normally and collect emitted indices.
           Containers (e.g., newBlend's group wrapper, symbolInstance's class
           group) are already populated with children that were emitted BEFORE
           the container in this batch — so those children are already in
           `out` via this loop's earlier leaf branch. Draining the container
           means simply clearing its memberIndices so Swift drops it, without
           re-adding the children (which would create duplicates). */
        size_t before = ctx.result.shapes.size();
        walkSomething(elemId, ctx);
        for (size_t k = before; k < ctx.result.shapes.size(); ++k)
        {
            int kind = ctx.result.shapes[k].kind;
            if (kind == FH_SHAPE_KIND_GROUP || kind == FH_SHAPE_KIND_CLIP_GROUP)
            {
                ctx.result.shapes[k].memberIndices.clear();
            }
            else
            {
                out.push_back(k);
            }
        }
    }
}

size_t walkGroup(const libfreehand::FHGroup *group, WalkContext &ctx, bool asClipGroup)
{
    if (!group || !ctx.view.lists) return SIZE_MAX;

    if (asClipGroup) ctx.statClipGroups++;
    else ctx.statGroups++;

    auto listIt = ctx.view.lists->find(group->m_elementsId);
    if (listIt == ctx.view.lists->end()) return SIZE_MAX;

    bool pushed = false;
    if (group->m_xFormId && ctx.view.transforms)
    {
        auto xt = ctx.view.transforms->find(group->m_xFormId);
        if (xt != ctx.view.transforms->end())
        {
            ctx.xformStack.push_back(xt->second);
            pushed = true;
        }
    }

    std::vector<size_t> childIndices;

    if (asClipGroup)
    {
        /* Clipping group: gather ONLY flat leaves. Native InkPen requires the
           mask (first leaf) and every clipped content shape to be direct child
           shapes of the clip group — never nested groups. */
        walkLeafElementsForClipGroup(group->m_elementsId, childIndices, ctx);
    }
    else
    {
        /* Regular group: walk children in document order and keep them nested,
           including clip-group children, so the resulting z-order matches the
           original FreeHand file. Leaves owned by a clip-group child must NOT
           also be added as peers of this regular group — that would duplicate
           them, render the content unclipped underneath the clipped copy, and
           confuse the Layers panel's UUID lookup. */
        for (unsigned elemId : listIt->second.m_elements)
        {
            size_t before = ctx.result.shapes.size();
            walkSomething(elemId, ctx);
            size_t after = ctx.result.shapes.size();

            /* Mark everything a nested clip group owns so we skip those indices. */
            std::set<size_t> ownedByClipGroup;
            for (size_t k = before; k < after; ++k)
            {
                if (ctx.result.shapes[k].kind == FH_SHAPE_KIND_CLIP_GROUP)
                {
                    for (size_t m : ctx.result.shapes[k].memberIndices)
                        ownedByClipGroup.insert(m);
                }
            }

            for (size_t k = before; k < after; ++k)
            {
                if (ownedByClipGroup.count(k)) continue;
                childIndices.push_back(k);
            }
        }
    }

    if (pushed) ctx.xformStack.pop_back();

    if (childIndices.empty()) return SIZE_MAX;

    /* Skip trivial single-child groups — they just add noise in the Layers panel. */
    if (childIndices.size() == 1 && !asClipGroup) return childIndices.back();

    FHResultShape container;
    container.kind = asClipGroup ? FH_SHAPE_KIND_CLIP_GROUP : FH_SHAPE_KIND_GROUP;
    container.memberIndices = childIndices;
    container.opacity = resolveOpacity(ctx.view, group->m_graphicStyleId);
    ctx.result.shapes.push_back(container);
    return ctx.result.shapes.size() - 1;
}

void walkSomething(unsigned id, WalkContext &ctx)
{
    if (!id) return;
    if (ctx.visited.find(id) != ctx.visited.end()) return;
    ctx.visited.insert(id);

    if (ctx.view.paths)
    {
        auto it = ctx.view.paths->find(id);
        if (it != ctx.view.paths->end()) { walkPath(&it->second, ctx); goto done; }
    }
    if (ctx.view.groups)
    {
        auto it = ctx.view.groups->find(id);
        if (it != ctx.view.groups->end()) { walkGroup(&it->second, ctx, false); goto done; }
    }
    if (ctx.view.clipGroups)
    {
        auto it = ctx.view.clipGroups->find(id);
        if (it != ctx.view.clipGroups->end()) { walkGroup(&it->second, ctx, true); goto done; }
    }
    if (ctx.view.compositePaths)
    {
        auto it = ctx.view.compositePaths->find(id);
        if (it != ctx.view.compositePaths->end()) { walkCompositePath(&it->second, ctx); goto done; }
    }
    if (ctx.view.newBlends)
    {
        auto it = ctx.view.newBlends->find(id);
        if (it != ctx.view.newBlends->end()) { walkNewBlend(&it->second, ctx); goto done; }
    }
    if (ctx.view.symbolInstances)
    {
        auto it = ctx.view.symbolInstances->find(id);
        if (it != ctx.view.symbolInstances->end()) { walkSymbolInstance(&it->second, ctx); goto done; }
    }
    /* Text / images / pathText / displayText come in Phase 3. */
done:
    ctx.visited.erase(id);
}

/* Helper: walk every element in a given FHList, collecting child indices. */
void walkListElements(unsigned listId, std::vector<size_t> &childIndices, WalkContext &ctx)
{
    if (!listId || !ctx.view.lists) return;
    auto listIt = ctx.view.lists->find(listId);
    if (listIt == ctx.view.lists->end()) return;
    for (unsigned elemId : listIt->second.m_elements)
    {
        size_t before = ctx.result.shapes.size();
        walkSomething(elemId, ctx);
        for (size_t k = before; k < ctx.result.shapes.size(); ++k)
            childIndices.push_back(k);
    }
}

/* FHNewBlend: libfreehand doesn't interpolate — it just emits the three source
   lists as a group. We replicate that: walk list1 + list2 + list3, wrap the
   resulting shapes in a group container. */
size_t walkNewBlend(const libfreehand::FHNewBlend *nb, WalkContext &ctx)
{
    if (!nb) return SIZE_MAX;
    ctx.statNewBlends++;

    std::vector<size_t> childIndices;
    walkListElements(nb->m_list1Id, childIndices, ctx);
    walkListElements(nb->m_list2Id, childIndices, ctx);
    walkListElements(nb->m_list3Id, childIndices, ctx);

    if (childIndices.empty()) return SIZE_MAX;
    if (childIndices.size() == 1) return childIndices.back();

    FHResultShape container;
    container.kind = FH_SHAPE_KIND_GROUP;
    container.memberIndices = childIndices;
    container.opacity = resolveOpacity(ctx.view, nb->m_graphicStyleId);
    ctx.result.shapes.push_back(container);
    return ctx.result.shapes.size() - 1;
}

/* FHSymbolInstance: recurse into the symbol class's group with the instance's
   transform pushed onto the xform stack. Phase 2 treats every instance as a
   full clone of its symbol — no shared-symbol deduplication. */
size_t walkSymbolInstance(const libfreehand::FHSymbolInstance *sym, WalkContext &ctx)
{
    if (!sym || !ctx.view.symbolClasses) return SIZE_MAX;
    ctx.statSymbolInstances++;

    auto classIt = ctx.view.symbolClasses->find(sym->m_symbolClassId);
    if (classIt == ctx.view.symbolClasses->end()) return SIZE_MAX;

    ctx.xformStack.push_back(sym->m_xForm);

    size_t before = ctx.result.shapes.size();
    walkSomething(classIt->second.m_groupId, ctx);
    std::vector<size_t> childIndices;
    for (size_t k = before; k < ctx.result.shapes.size(); ++k)
        childIndices.push_back(k);

    ctx.xformStack.pop_back();

    if (childIndices.empty()) return SIZE_MAX;
    if (childIndices.size() == 1) return childIndices.back();

    FHResultShape container;
    container.kind = FH_SHAPE_KIND_GROUP;
    container.memberIndices = childIndices;
    container.opacity = resolveOpacity(ctx.view, sym->m_graphicStyleId);
    ctx.result.shapes.push_back(container);
    return ctx.result.shapes.size() - 1;
}

void walkLayerTree(const libfreehand::InkpenCollectorView &view, fh_result &result)
{
    if (!view.pageInfo) return;
    WalkContext ctx(view, result);

    /* m_block → layerListId → FHList of layer IDs → each FHLayer → m_elementsId → FHList of element IDs. */
    if (view.block && view.lists && view.layers)
    {
        unsigned layerListId = view.block->second.m_layerListId;
        auto layerListIt = view.lists->find(layerListId);
        if (layerListIt != view.lists->end())
        {
            for (unsigned layerId : layerListIt->second.m_elements)
            {
                auto layerIt = view.layers->find(layerId);
                if (layerIt == view.layers->end()) continue;
                if (layerIt->second.m_visibility == 0) continue; // Hidden layer.

                auto elemListIt = view.lists->find(layerIt->second.m_elementsId);
                if (elemListIt == view.lists->end()) continue;
                for (unsigned elemId : elemListIt->second.m_elements)
                    walkSomething(elemId, ctx);
            }
        }
    }

    /* Fallback: if no layer tree was walked (unusual FH files), walk every path directly. */
    if (result.shapes.empty() && view.paths)
    {
        for (auto it = view.paths->begin(); it != view.paths->end(); ++it)
            walkPath(&it->second, ctx);
    }

    /* Copy diagnostic counters from the walker context to the result. */
    result.statPaths = ctx.statPaths;
    result.statGroups = ctx.statGroups;
    result.statClipGroups = ctx.statClipGroups;
    result.statCompositePaths = ctx.statCompositePaths;
    result.statNewBlends = ctx.statNewBlends;
    result.statSymbolInstances = ctx.statSymbolInstances;
    result.statContentIdPaths = ctx.statContentIdPaths;

    const libfreehand::FHPageInfo &page = effectivePageInfo(view);
    result.pageWidth = (page.m_maxX - page.m_minX) * FH_POINTS_PER_INCH;
    result.pageHeight = (page.m_maxY - page.m_minY) * FH_POINTS_PER_INCH;

    /* Auto-fit: some FH files place content on the "pasteboard" outside the page
       box, so after the Y-flip the shapes land at negative X or Y. Compute the
       combined bbox of every emitted path element and, if it starts above/left
       of the page origin, translate everything so (minX, minY) = (0, 0). */
    double minX = std::numeric_limits<double>::infinity();
    double minY = std::numeric_limits<double>::infinity();
    for (const FHResultShape &shape : result.shapes)
    {
        for (const FHResultPathElement &el : shape.elements)
        {
            if (el.kind == FH_PATH_CLOSE) continue;
            if (el.x < minX) minX = el.x;
            if (el.y < minY) minY = el.y;
            if (el.kind == FH_PATH_CUBIC)
            {
                if (el.x1 < minX) minX = el.x1;
                if (el.y1 < minY) minY = el.y1;
                if (el.x2 < minX) minX = el.x2;
                if (el.y2 < minY) minY = el.y2;
            }
            else if (el.kind == FH_PATH_QUAD)
            {
                if (el.x1 < minX) minX = el.x1;
                if (el.y1 < minY) minY = el.y1;
            }
        }
    }
    double dx = (minX < 0) ? -minX : 0.0;
    double dy = (minY < 0) ? -minY : 0.0;
    if (dx > 0 || dy > 0)
    {
        for (FHResultShape &shape : result.shapes)
        {
            for (FHResultPathElement &el : shape.elements)
            {
                if (el.kind == FH_PATH_CLOSE) continue;
                el.x += dx; el.y += dy;
                if (el.kind == FH_PATH_CUBIC)
                {
                    el.x1 += dx; el.y1 += dy;
                    el.x2 += dx; el.y2 += dy;
                }
                else if (el.kind == FH_PATH_QUAD)
                {
                    el.x1 += dx; el.y1 += dy;
                }
            }
        }
    }
}

} // namespace

extern "C" {

int freehand_parse_to_shapes(const unsigned char *data, size_t length, fh_result **out_result)
{
    if (!data || length == 0 || !out_result) return 1;
    *out_result = nullptr;

    librevenge::RVNGMemoryInputStream input(const_cast<unsigned char *>(data), (unsigned long)length);
    if (!libfreehand::FreeHandDocument::isSupported(&input)) return 2;

    input.seek(0, librevenge::RVNG_SEEK_SET);

    libfreehand::FHCollector collector;
    libfreehand::FHParser parser;

    try {
        if (!parser.parse(&input, &collector)) return 3;
    } catch (...) {
        return 3;
    }

    libfreehand::InkpenCollectorView view;
    collector.inkpenBuildView(view);

    fh_result *result = new (std::nothrow) fh_result();
    if (!result) return 5;

    try {
        walkLayerTree(view, *result);
    } catch (...) {
        delete result;
        return 3;
    }

    *out_result = result;
    return 0;
}

void fh_result_free(fh_result *result)
{
    delete result;
}

double fh_result_page_width(const fh_result *r) { return r ? r->pageWidth : 0.0; }
double fh_result_page_height(const fh_result *r) { return r ? r->pageHeight : 0.0; }
size_t fh_result_shape_count(const fh_result *r) { return r ? r->shapes.size() : 0; }

size_t fh_result_stat_paths(const fh_result *r) { return r ? r->statPaths : 0; }
size_t fh_result_stat_groups(const fh_result *r) { return r ? r->statGroups : 0; }
size_t fh_result_stat_clip_groups(const fh_result *r) { return r ? r->statClipGroups : 0; }
size_t fh_result_stat_composite_paths(const fh_result *r) { return r ? r->statCompositePaths : 0; }
size_t fh_result_stat_new_blends(const fh_result *r) { return r ? r->statNewBlends : 0; }
size_t fh_result_stat_symbol_instances(const fh_result *r) { return r ? r->statSymbolInstances : 0; }
size_t fh_result_stat_content_id_paths(const fh_result *r) { return r ? r->statContentIdPaths : 0; }

int fh_result_shape_kind(const fh_result *r, size_t index)
{
    if (!r || index >= r->shapes.size()) return -1;
    return r->shapes[index].kind;
}

int fh_result_shape_is_closed(const fh_result *r, size_t index)
{
    if (!r || index >= r->shapes.size()) return 0;
    return r->shapes[index].isClosed ? 1 : 0;
}

int fh_result_shape_even_odd(const fh_result *r, size_t index)
{
    if (!r || index >= r->shapes.size()) return 0;
    return r->shapes[index].evenOdd ? 1 : 0;
}

size_t fh_result_shape_path_element_count(const fh_result *r, size_t index)
{
    if (!r || index >= r->shapes.size()) return 0;
    return r->shapes[index].elements.size();
}

int fh_result_shape_path_element_kind(const fh_result *r, size_t index, size_t elIndex)
{
    if (!r || index >= r->shapes.size()) return -1;
    const auto &els = r->shapes[index].elements;
    if (elIndex >= els.size()) return -1;
    return els[elIndex].kind;
}

double fh_result_shape_path_element_coord(const fh_result *r, size_t index, size_t elIndex, int which)
{
    if (!r || index >= r->shapes.size()) return 0.0;
    const auto &els = r->shapes[index].elements;
    if (elIndex >= els.size()) return 0.0;
    const FHResultPathElement &el = els[elIndex];
    switch (which)
    {
    case 0: return el.x;
    case 1: return el.y;
    case 2: return el.x1;
    case 3: return el.y1;
    case 4: return el.x2;
    case 5: return el.y2;
    default: return 0.0;
    }
}

int fh_result_shape_fill_kind(const fh_result *r, size_t index)
{
    if (!r || index >= r->shapes.size()) return FH_FILL_NONE;
    return r->shapes[index].fillKind;
}
int fh_result_shape_has_fill(const fh_result *r, size_t index)
{
    if (!r || index >= r->shapes.size()) return 0;
    return r->shapes[index].fill.present ? 1 : 0;
}
double fh_result_shape_fill_r(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].fill.r : 0.0; }
double fh_result_shape_fill_g(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].fill.g : 0.0; }
double fh_result_shape_fill_b(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].fill.b : 0.0; }
double fh_result_shape_fill_a(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].fill.a : 1.0; }
double fh_result_shape_fill_angle(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].fillAngle : 0.0; }
double fh_result_shape_fill_center_x(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].fillCenterX : 0.5; }
double fh_result_shape_fill_center_y(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].fillCenterY : 0.5; }

size_t fh_result_shape_gradient_stop_count(const fh_result *r, size_t i)
{
    if (!r || i >= r->shapes.size()) return 0;
    return r->shapes[i].gradientStops.size();
}
double fh_result_shape_gradient_stop_position(const fh_result *r, size_t i, size_t s)
{
    if (!r || i >= r->shapes.size()) return 0;
    const auto &stops = r->shapes[i].gradientStops;
    return s < stops.size() ? stops[s].position : 0.0;
}
double fh_result_shape_gradient_stop_r(const fh_result *r, size_t i, size_t s)
{
    if (!r || i >= r->shapes.size()) return 0;
    const auto &stops = r->shapes[i].gradientStops;
    return s < stops.size() ? stops[s].r : 0.0;
}
double fh_result_shape_gradient_stop_g(const fh_result *r, size_t i, size_t s)
{
    if (!r || i >= r->shapes.size()) return 0;
    const auto &stops = r->shapes[i].gradientStops;
    return s < stops.size() ? stops[s].g : 0.0;
}
double fh_result_shape_gradient_stop_b(const fh_result *r, size_t i, size_t s)
{
    if (!r || i >= r->shapes.size()) return 0;
    const auto &stops = r->shapes[i].gradientStops;
    return s < stops.size() ? stops[s].b : 0.0;
}
double fh_result_shape_gradient_stop_a(const fh_result *r, size_t i, size_t s)
{
    if (!r || i >= r->shapes.size()) return 0;
    const auto &stops = r->shapes[i].gradientStops;
    return s < stops.size() ? stops[s].a : 1.0;
}

int fh_result_shape_has_stroke(const fh_result *r, size_t index)
{
    if (!r || index >= r->shapes.size()) return 0;
    return r->shapes[index].stroke.present ? 1 : 0;
}
double fh_result_shape_stroke_r(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].stroke.r : 0.0; }
double fh_result_shape_stroke_g(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].stroke.g : 0.0; }
double fh_result_shape_stroke_b(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].stroke.b : 0.0; }
double fh_result_shape_stroke_a(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].stroke.a : 1.0; }
double fh_result_shape_stroke_width(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].strokeWidth : 0.0; }

double fh_result_shape_opacity(const fh_result *r, size_t i) { return (r && i < r->shapes.size()) ? r->shapes[i].opacity : 1.0; }

size_t fh_result_shape_member_count(const fh_result *r, size_t index)
{
    if (!r || index >= r->shapes.size()) return 0;
    return r->shapes[index].memberIndices.size();
}

size_t fh_result_shape_member_index(const fh_result *r, size_t index, size_t memberIndex)
{
    if (!r || index >= r->shapes.size()) return SIZE_MAX;
    const auto &members = r->shapes[index].memberIndices;
    if (memberIndex >= members.size()) return SIZE_MAX;
    return members[memberIndex];
}

} // extern "C"

#pragma clang diagnostic pop
