#ifndef FREEHAND_BRIDGE_H
#define FREEHAND_BRIDGE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int freehand_is_supported(const unsigned char *data, size_t length);

/* Direct FH → InkPen translator (Phase 1). Returns opaque result handle via out param.
   0 on success, nonzero rc: 1 bad args, 2 not supported, 3 parse failed, 5 OOM.
   Result must be released with fh_result_free. */
typedef struct fh_result fh_result;

int freehand_parse_to_shapes(const unsigned char *data, size_t length, fh_result **out_result);
void fh_result_free(fh_result *result);

double fh_result_page_width(const fh_result *r);
double fh_result_page_height(const fh_result *r);
size_t fh_result_shape_count(const fh_result *r);

/* Walker diagnostic counters: counts of each FH record type the walker visited. */
size_t fh_result_stat_paths(const fh_result *r);
size_t fh_result_stat_groups(const fh_result *r);
size_t fh_result_stat_clip_groups(const fh_result *r);
size_t fh_result_stat_composite_paths(const fh_result *r);
size_t fh_result_stat_new_blends(const fh_result *r);
size_t fh_result_stat_symbol_instances(const fh_result *r);
size_t fh_result_stat_content_id_paths(const fh_result *r);

/* Shape kinds. Phase 1 only emits kPath. Later phases add group / compound / text / image. */
enum {
    FH_SHAPE_KIND_PATH = 0,
    FH_SHAPE_KIND_GROUP = 1,
    FH_SHAPE_KIND_CLIP_GROUP = 2,
    FH_SHAPE_KIND_COMPOUND_PATH = 3,
    FH_SHAPE_KIND_TEXT = 4,
    FH_SHAPE_KIND_IMAGE = 5
};

int fh_result_shape_kind(const fh_result *r, size_t index);

/* Path element kinds mirroring librevenge's path-action strings. */
enum {
    FH_PATH_MOVE = 0,
    FH_PATH_LINE = 1,
    FH_PATH_CUBIC = 2,
    FH_PATH_QUAD = 3,
    FH_PATH_CLOSE = 4
};

/* Path accessors. All coordinates are already normalized to InkPen's
   top-left-origin point space (Y flipped, page origin offset applied). */
int fh_result_shape_is_closed(const fh_result *r, size_t index);
int fh_result_shape_even_odd(const fh_result *r, size_t index);
size_t fh_result_shape_path_element_count(const fh_result *r, size_t index);
int fh_result_shape_path_element_kind(const fh_result *r, size_t index, size_t elIndex);
double fh_result_shape_path_element_coord(const fh_result *r, size_t index, size_t elIndex, int which);
/* which: 0=x 1=y 2=x1 3=y1 4=x2 5=y2 */

/* Fill kinds. NONE means no fill resolved. SOLID uses fill_r/g/b/a.
   LINEAR/RADIAL use gradient stops plus angle (linear) or center (radial). */
enum {
    FH_FILL_NONE = 0,
    FH_FILL_SOLID = 1,
    FH_FILL_LINEAR = 2,
    FH_FILL_RADIAL = 3
};

int fh_result_shape_fill_kind(const fh_result *r, size_t index);
int fh_result_shape_has_fill(const fh_result *r, size_t index);
double fh_result_shape_fill_r(const fh_result *r, size_t index);
double fh_result_shape_fill_g(const fh_result *r, size_t index);
double fh_result_shape_fill_b(const fh_result *r, size_t index);
double fh_result_shape_fill_a(const fh_result *r, size_t index);
double fh_result_shape_fill_angle(const fh_result *r, size_t index);
double fh_result_shape_fill_center_x(const fh_result *r, size_t index);
double fh_result_shape_fill_center_y(const fh_result *r, size_t index);
size_t fh_result_shape_gradient_stop_count(const fh_result *r, size_t index);
double fh_result_shape_gradient_stop_position(const fh_result *r, size_t index, size_t stopIndex);
double fh_result_shape_gradient_stop_r(const fh_result *r, size_t index, size_t stopIndex);
double fh_result_shape_gradient_stop_g(const fh_result *r, size_t index, size_t stopIndex);
double fh_result_shape_gradient_stop_b(const fh_result *r, size_t index, size_t stopIndex);
double fh_result_shape_gradient_stop_a(const fh_result *r, size_t index, size_t stopIndex);

/* Stroke — solid color + width only in Phase 1. */
int fh_result_shape_has_stroke(const fh_result *r, size_t index);
double fh_result_shape_stroke_r(const fh_result *r, size_t index);
double fh_result_shape_stroke_g(const fh_result *r, size_t index);
double fh_result_shape_stroke_b(const fh_result *r, size_t index);
double fh_result_shape_stroke_a(const fh_result *r, size_t index);
double fh_result_shape_stroke_width(const fh_result *r, size_t index);

double fh_result_shape_opacity(const fh_result *r, size_t index);

/* Group / clipGroup / compound containers: member indices point to peer shapes
   earlier in the same flat shape array (children always emitted before parents). */
size_t fh_result_shape_member_count(const fh_result *r, size_t index);
size_t fh_result_shape_member_index(const fh_result *r, size_t index, size_t memberIndex);

#ifdef __cplusplus
}
#endif

#endif
