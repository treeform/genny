#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "pixie.h"

#ifndef PIXIE_ROOT
#define PIXIE_ROOT "../pixie"
#endif

#define FONT_PATH PIXIE_ROOT "/tests/fonts/Inter-Regular.ttf"
#define IMAGE_PATH PIXIE_ROOT "/tests/images/turtle.png"

static void approx(float value, float expected) {
    assert(fabsf(value - expected) < 0.0001f);
}

static void approx_eps(float value, float expected, float eps) {
    assert(fabsf(value - expected) <= eps);
}

static void assert_color(Color actual, Color expected) {
    approx(actual.r, expected.r);
    approx(actual.g, expected.g);
    approx(actual.b, expected.b);
    approx(actual.a, expected.a);
}

static void assert_buffer_len_gt(GennyBuffer buffer, intptr_t min_len) {
    assert(buffer != NULL);
    assert(pixie_genny_buffer_len(buffer) > min_len);
    pixie_genny_buffer_unref(buffer);
}

static void assert_buffer_contains(GennyBuffer buffer, const char *needle) {
    assert(buffer != NULL);
    assert(strstr(pixie_genny_buffer_data(buffer), needle) != NULL);
    pixie_genny_buffer_unref(buffer);
}

static void assert_buffer_equals(GennyBuffer buffer, const char *expected) {
    assert(buffer != NULL);
    intptr_t len = pixie_genny_buffer_len(buffer);
    assert(len == (intptr_t)strlen(expected));
    assert(memcmp(pixie_genny_buffer_data(buffer), expected, (size_t)len) == 0);
    pixie_genny_buffer_unref(buffer);
}

int main() {
    const char *ppm = "P3\n2 1\n255\n255 0 0 0 255 0\n";

    assert(DEFAULT_MITER_LIMIT == 4.0f);
    assert(AUTO_LINE_HEIGHT == -1.0f);
    assert(PNG_FORMAT == 0);
    assert(LINEAR_GRADIENT_PAINT == 3);

    Color red = pixie_parse_color("#ff0000");
    Color green = pixie_parse_color("#00ff00");
    Color mixed = pixie_mix(red, green, 0.25f);
    approx(mixed.r, 0.75f);
    approx(mixed.g, 0.25f);

    Mat3 mat = pixie_translate(3, 4);
    Mat3 identity = pixie_translate(0, 0);
    assert(mat.values[6] == 3);
    assert(pixie_inverse(mat).values[6] == -3);
    Vec2 a = pixie_vec2(1, 2);
    Vec2 b = pixie_vec2(3, 4);
    Vec2 sum = pixie_vec2_add(a, b);
    assert(sum.x == 4);
    assert(sum.y == 6);
    Vec2 product = pixie_vec2_mul(a, b);
    assert(product.x == 3);
    assert(product.y == 8);
    Vec2 scaled = pixie_vec2_float32_mul(a, 2.0f);
    assert(scaled.x == 2);
    assert(scaled.y == 4);
    Vec2 moved = pixie_mat3_vec2_mul(mat, a);
    assert(moved.x == 4);
    assert(moved.y == 6);
    assert(pixie_rect_eq(pixie_snap_to_pixels(pixie_rect(1, 2, 3, 4)), pixie_rect(1, 2, 3, 4)));
    assert(pixie_miter_limit_to_angle(2) > 0);
    assert(pixie_angle_to_miter_limit(1) > 0);

    SeqFloat32 dashes = pixie_new_seq_float32();
    pixie_seq_float32_add(dashes, 1.5f);
    pixie_seq_float32_add(dashes, 2.5f);
    pixie_seq_float32_set(dashes, 1, 3.5f);
    assert(pixie_seq_float32_len(dashes) == 2);
    approx(pixie_seq_float32_get(dashes, 1), 3.5f);

    Image image = pixie_new_image(4, 3);
    assert(pixie_image_get_width(image) == 4);
    assert(pixie_image_get_height(image) == 3);
    assert_buffer_len_gt(pixie_image_encode_base64(image), 20);
    pixie_image_fill(image, red);
    assert(pixie_image_is_one_color(image));
    assert(pixie_image_is_opaque(image));
    assert_color(pixie_image_get_color(image, 1, 1), red);
    pixie_image_set_color(image, 0, 0, green);
    assert(!pixie_image_is_one_color(image));
    Image image_copy = pixie_image_copy(image);
    assert(pixie_image_get_width(image_copy) == pixie_image_get_width(image));

    Paint solid = pixie_new_paint(SOLID_PAINT);
    pixie_paint_set_color(solid, red);
    pixie_image_paint_fill(image, solid);
    pixie_image_apply_opacity(image, 0.5f);
    approx_eps(pixie_image_get_color(image, 0, 0).a, 0.5f, 0.01f);
    pixie_image_invert(image);
    pixie_image_blur(image, 1, red);

    Image resized = pixie_image_resize(image, 6, 5);
    assert(pixie_image_get_width(resized) == 6);
    assert(pixie_image_get_height(resized) == 5);
    pixie_image_rotate90(resized);
    assert(pixie_image_get_width(resized) == 5);
    assert(pixie_image_get_height(resized) == 6);
    assert(pixie_image_get_width(pixie_image_sub_image(resized, 0, 0, 2, 2)) == 2);
    assert(pixie_image_get_height(pixie_image_rect_sub_image(resized, pixie_rect(0, 0, 1, 1))) == 1);
    assert(pixie_image_get_width(pixie_image_shadow(resized, pixie_vec2(1, 2), 3, 4, red)) == pixie_image_get_width(resized));
    assert(pixie_image_get_width(pixie_image_super_image(resized, -1, -1, pixie_image_get_width(resized) + 2, pixie_image_get_height(resized) + 2)) == pixie_image_get_width(resized) + 2);
    assert(pixie_image_opaque_bounds(resized).w > 0);

    Paint paint = pixie_new_paint(SOLID_PAINT);
    pixie_paint_set_kind(paint, LINEAR_GRADIENT_PAINT);
    pixie_paint_set_blend_mode(paint, MULTIPLY_BLEND);
    pixie_paint_set_opacity(paint, 0.5f);
    pixie_paint_set_color(paint, green);
    pixie_paint_set_image_mat(paint, pixie_scale(2, 3));
    assert(pixie_paint_get_kind(paint) == LINEAR_GRADIENT_PAINT);
    approx(pixie_paint_get_opacity(paint), 0.5f);
    pixie_paint_gradient_handle_positions_add(paint, pixie_vec2(0.25f, 0));
    pixie_paint_gradient_handle_positions_add(paint, pixie_vec2(0.75f, 1));
    pixie_paint_gradient_handle_positions_set(paint, 1, pixie_vec2(0.8f, 1));
    assert(pixie_paint_gradient_handle_positions_len(paint) == 2);
    approx(pixie_paint_gradient_handle_positions_get(paint, 1).x, 0.8f);
    pixie_paint_gradient_stops_add(paint, pixie_color_stop(red, 0));
    pixie_paint_gradient_stops_add(paint, pixie_color_stop(green, 1));
    assert(pixie_paint_gradient_stops_len(paint) == 2);
    assert_color(pixie_paint_gradient_stops_get(paint, 1).color, green);

    Path path = pixie_new_path();
    pixie_path_move_to(path, 1, 1);
    pixie_path_line_to(path, 2, 2);
    pixie_path_bezier_curve_to(path, 1, 2, 3, 4, 5, 6);
    pixie_path_quadratic_curve_to(path, 1, 2, 3, 4);
    pixie_path_elliptical_arc_to(path, 1, 2, 3, 0, 1, 4, 5);
    pixie_path_arc(path, 1, 2, 3, 0, 1, 0);
    pixie_path_arc_to(path, 1, 2, 3, 4, 5);
    pixie_path_rect(path, 0, 0, 3, 4, 1);
    pixie_path_rounded_rect(path, 0, 0, 3, 4, 1, 1, 1, 1, 1);
    pixie_path_ellipse(path, 1, 2, 3, 4);
    pixie_path_circle(path, 1, 2, 3);
    pixie_path_polygon(path, 1, 2, 3, 5);
    pixie_path_close_path(path);
    assert(pixie_path_compute_bounds(path, identity).w > 0);

    Path rect_path = pixie_new_path();
    pixie_path_rect(rect_path, 0, 0, 10, 10, 1);
    SeqFloat32 solid_dashes = pixie_new_seq_float32();
    assert(pixie_path_fill_overlaps(rect_path, pixie_vec2(5, 5), identity, NON_ZERO));
    assert(pixie_path_stroke_overlaps(rect_path, pixie_vec2(0, 5), identity, 2, BUTT_CAP, MITER_JOIN, DEFAULT_MITER_LIMIT, solid_dashes));

    Typeface typeface = pixie_read_typeface(FONT_PATH);
    assert_buffer_contains(pixie_typeface_get_file_path(typeface), "Inter-Regular.ttf");
    pixie_typeface_set_file_path(typeface, FONT_PATH);
    assert(pixie_typeface_has_glyph(typeface, 'A'));
    assert(pixie_typeface_get_advance(typeface, 'A') > 0);
    assert(pixie_path_compute_bounds(pixie_typeface_get_glyph_path(typeface, 'A'), identity).w > 0);

    Font font = pixie_typeface_new_font(typeface);
    pixie_font_set_size(font, 24);
    pixie_font_set_line_height(font, AUTO_LINE_HEIGHT);
    pixie_font_set_paint(font, solid);
    pixie_font_set_text_case(font, UPPER_CASE);
    pixie_font_set_underline(font, 1);
    pixie_font_set_strikethrough(font, 1);
    pixie_font_set_no_kerning_adjustments(font, 1);
    pixie_font_paints_add(font, solid);
    assert(pixie_font_paints_len(font) >= 1);
    assert(pixie_font_scale(font) > 0);
    assert(pixie_font_default_line_height(font) > 0);
    assert(pixie_font_layout_bounds(font, "abcd").x > 0);
    assert(pixie_arrangement_layout_bounds(pixie_font_typeset(font, "abcd", pixie_vec2(100, 100), LEFT_ALIGN, TOP_ALIGN, 1)).x > 0);

    Span span = pixie_new_span("hi", font);
    pixie_span_set_text(span, "hello");
    SeqSpan spans = pixie_new_seq_span();
    pixie_seq_span_add(spans, span);
    Arrangement arrangement = pixie_seq_span_typeset(spans, pixie_vec2(100, 100), CENTER_ALIGN, BOTTOM_ALIGN, 1);
    assert_buffer_equals(pixie_span_get_text(pixie_seq_span_get(spans, 0)), "hello");
    assert(pixie_arrangement_layout_bounds(arrangement).x > 0);
    assert(pixie_seq_span_layout_bounds(spans).y > 0);
    assert(pixie_arrangement_compute_bounds(arrangement, mat).x > 0);

    Image canvas = pixie_new_image(64, 64);
    pixie_image_fill(canvas, pixie_parse_color("#ffffff"));
    pixie_image_fill_text(canvas, font, "abc", mat, pixie_vec2(60, 60), LEFT_ALIGN, TOP_ALIGN);
    pixie_image_arrangement_fill_text(canvas, arrangement, mat);
    pixie_image_stroke_text(canvas, font, "abc", mat, 2, pixie_vec2(60, 60), LEFT_ALIGN, TOP_ALIGN, BUTT_CAP, MITER_JOIN, DEFAULT_MITER_LIMIT, dashes);
    pixie_image_arrangement_stroke_text(canvas, arrangement, mat, 2, BUTT_CAP, MITER_JOIN, DEFAULT_MITER_LIMIT, dashes);
    pixie_image_fill_path(canvas, rect_path, solid, mat, NON_ZERO);
    pixie_image_stroke_path(canvas, rect_path, solid, mat, 2, BUTT_CAP, MITER_JOIN, DEFAULT_MITER_LIMIT, dashes);

    Context ctx = pixie_new_context(80, 80);
    pixie_context_set_global_alpha(ctx, 0.75f);
    pixie_context_set_line_width(ctx, 2);
    pixie_context_set_miter_limit(ctx, 5);
    pixie_context_set_line_cap(ctx, ROUND_CAP);
    pixie_context_set_line_join(ctx, BEVEL_JOIN);
    pixie_context_set_font(ctx, FONT_PATH);
    pixie_context_set_font_size(ctx, 24);
    pixie_context_set_text_align(ctx, RIGHT_ALIGN);
    assert(pixie_context_get_text_align(ctx) == RIGHT_ALIGN);
    assert(pixie_context_measure_text(ctx, "abcd").width > 0);
    pixie_context_set_transform(ctx, mat);
    assert(pixie_context_get_transform(ctx).values[6] == 3);
    pixie_context_transform(ctx, pixie_scale(2, 2));
    pixie_context_reset_transform(ctx);
    pixie_context_set_line_dash(ctx, solid_dashes);
    pixie_context_begin_path(ctx);
    pixie_context_rect(ctx, 0, 0, 10, 10);
    assert(pixie_context_is_point_in_path(ctx, 5, 5, NON_ZERO));
    assert(pixie_context_path_is_point_in_path(ctx, rect_path, 5, 5, NON_ZERO));
    assert(pixie_context_is_point_in_stroke(ctx, 0, 5));
    assert(pixie_context_path_is_point_in_stroke(ctx, rect_path, 0, 5));
    pixie_context_set_line_dash(ctx, dashes);
    assert(pixie_seq_float32_len(pixie_context_get_line_dash(ctx)) == 2);
    pixie_context_move_to(ctx, 1, 1);
    pixie_context_line_to(ctx, 2, 2);
    pixie_context_bezier_curve_to(ctx, 1, 2, 3, 4, 5, 6);
    pixie_context_quadratic_curve_to(ctx, 1, 2, 3, 4);
    pixie_context_arc(ctx, 1, 2, 3, 0, 1, 0);
    pixie_context_arc_to(ctx, 1, 2, 3, 4, 5);
    pixie_context_rounded_rect(ctx, 0, 0, 3, 4, 1, 1, 1, 1);
    pixie_context_ellipse(ctx, 1, 2, 3, 4);
    pixie_context_circle(ctx, 1, 2, 3);
    pixie_context_polygon(ctx, 1, 2, 3, 5);
    pixie_context_close_path(ctx);
    pixie_context_fill(ctx, NON_ZERO);
    pixie_context_path_fill(ctx, rect_path, EVEN_ODD);
    pixie_context_clip(ctx, NON_ZERO);
    pixie_context_path_clip(ctx, rect_path, EVEN_ODD);
    pixie_context_stroke(ctx);
    pixie_context_path_stroke(ctx, rect_path);
    pixie_context_draw_image(ctx, canvas, 1, 2);
    pixie_context_draw_image2(ctx, canvas, 1, 2, 3, 4);
    pixie_context_draw_image3(ctx, canvas, 1, 2, 3, 4, 5, 6, 7, 8);
    pixie_context_clear_rect(ctx, 1, 2, 3, 4);
    pixie_context_fill_rect(ctx, 1, 2, 3, 4);
    pixie_context_stroke_rect(ctx, 1, 2, 3, 4);
    pixie_context_stroke_segment(ctx, 1, 2, 3, 4);
    pixie_context_fill_text(ctx, "abc", 1, 2);
    pixie_context_stroke_text(ctx, "abc", 1, 2);
    pixie_context_translate(ctx, 3, 4);
    pixie_context_scale(ctx, 2, 3);
    pixie_context_rotate(ctx, 0.5f);
    pixie_context_save(ctx);
    pixie_context_save_layer(ctx);
    pixie_context_restore(ctx);

    GennyBuffer encoded_canvas = pixie_image_encode_base64(canvas);
    Image decoded = pixie_decode_base64(pixie_genny_buffer_data(encoded_canvas));
    pixie_genny_buffer_unref(encoded_canvas);
    assert(pixie_image_get_width(decoded) == pixie_image_get_width(canvas));
    assert(pixie_image_get_height(decoded) == pixie_image_get_height(canvas));
    assert(pixie_image_get_width(pixie_decode_image((char*)ppm)) == 2);
    assert(pixie_decode_image_dimensions((char*)ppm).height == 1);
    assert(pixie_image_get_width(pixie_read_image(IMAGE_PATH)) == 40);
    assert(pixie_read_image_dimensions(IMAGE_PATH).height == 40);
    approx(pixie_font_get_size(pixie_read_font(FONT_PATH)), 12);
    assert(pixie_path_compute_bounds(pixie_parse_path("M0 0 L10 0 L10 10 Z"), identity).w == 10);
    pixie_parse_color("bad");
    assert(pixie_check_error());
    assert_buffer_contains(pixie_take_error(), "bad");

    printf("All Pixie C tests passed!\n");
    return 0;
}
