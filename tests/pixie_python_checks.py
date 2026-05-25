import os
from pathlib import Path


def pixie_root():
    return Path(os.environ.get("PIXIE_ROOT", Path(__file__).resolve().parents[2] / "pixie"))


def asset(*parts):
    return str(pixie_root().joinpath(*parts))


def approx(value, expected, eps=0.0001):
    assert abs(value - expected) <= eps, f"expected {expected}, got {value}"


def matrix_values(matrix):
    return list(matrix.values)


def run(pixie):
    font_path = asset("tests", "fonts", "Inter-Regular.ttf")
    image_path = asset("tests", "images", "turtle.png")
    ppm = "P3\n2 1\n255\n255 0 0 0 255 0\n"

    assert pixie.DEFAULT_MITER_LIMIT == 4.0
    assert pixie.AUTO_LINE_HEIGHT == -1.0
    assert pixie.PNG_FORMAT == 0
    assert pixie.LINEAR_GRADIENT_PAINT == 3

    red = pixie.parse_color("#ff0000")
    green = pixie.parse_color("#00ff00")
    mixed = pixie.mix(red, green, 0.25)
    approx(mixed.r, 0.75)
    approx(mixed.g, 0.25)

    mat = pixie.translate(3, 4)
    assert matrix_values(mat)[6] == 3
    assert matrix_values(pixie.inverse(mat))[6] == -3
    a = pixie.Vec2(1, 2)
    b = pixie.Vec2(3, 4)
    assert a + b == pixie.Vec2(4, 6)
    assert a * b == pixie.Vec2(3, 8)
    assert a * 2.0 == pixie.Vec2(2, 4)
    assert mat * a == pixie.Vec2(4, 6)
    assert pixie.snap_to_pixels(pixie.Rect(1, 2, 3, 4)) == pixie.Rect(1, 2, 3, 4)
    assert pixie.miter_limit_to_angle(2) > 0
    assert pixie.angle_to_miter_limit(1) > 0

    dashes = pixie.SeqFloat32()
    dashes.append(1.5)
    dashes.append(2.5)
    dashes[1] = 3.5
    assert len(dashes) == 2
    approx(dashes[1], 3.5)

    image = pixie.Image(4, 3)
    assert image.width == 4
    assert image.height == 3
    assert len(image.encode_base64()) > 20
    image.fill(red)
    assert image.is_one_color()
    assert image.is_opaque()
    assert image.get_color(1, 1) == red
    image.set_color(0, 0, green)
    assert not image.is_one_color()
    assert image.copy().width == image.width

    solid = pixie.Paint(pixie.SOLID_PAINT)
    solid.color = red
    image.paint_fill(solid)
    image.apply_opacity(0.5)
    approx(image.get_color(0, 0).a, 0.5, 0.01)
    image.invert()
    image.blur(1, red)

    resized = image.resize(6, 5)
    assert resized.width == 6
    assert resized.height == 5
    resized.rotate90()
    assert resized.width == 5
    assert resized.height == 6
    assert resized.sub_image(0, 0, 2, 2).width == 2
    assert resized.rect_sub_image(pixie.Rect(0, 0, 1, 1)).height == 1
    assert resized.shadow(pixie.Vec2(1, 2), 3, 4, red).width == resized.width
    assert resized.super_image(-1, -1, resized.width + 2, resized.height + 2).width == resized.width + 2
    assert resized.opaque_bounds().w > 0

    paint = pixie.Paint(pixie.SOLID_PAINT)
    paint.kind = pixie.LINEAR_GRADIENT_PAINT
    paint.blend_mode = pixie.MULTIPLY_BLEND
    paint.opacity = 0.5
    paint.color = green
    paint.image_mat = pixie.scale(2, 3)
    assert paint.kind == pixie.LINEAR_GRADIENT_PAINT
    approx(paint.opacity, 0.5)

    paint.gradient_handle_positions.append(pixie.Vec2(0.25, 0.0))
    paint.gradient_handle_positions.append(pixie.Vec2(0.75, 1.0))
    paint.gradient_handle_positions[1] = pixie.Vec2(0.8, 1.0)
    assert len(paint.gradient_handle_positions) == 2
    approx(paint.gradient_handle_positions[1].x, 0.8)

    paint.gradient_stops.append(pixie.ColorStop(red, 0.0))
    paint.gradient_stops.append(pixie.ColorStop(green, 1.0))
    assert len(paint.gradient_stops) == 2
    assert paint.gradient_stops[1].color == green

    path = pixie.Path()
    path.move_to(1, 1)
    path.line_to(2, 2)
    path.bezier_curve_to(1, 2, 3, 4, 5, 6)
    path.quadratic_curve_to(1, 2, 3, 4)
    path.elliptical_arc_to(1, 2, 3, False, True, 4, 5)
    path.arc(1, 2, 3, 0, 1, False)
    path.arc_to(1, 2, 3, 4, 5)
    path.rect(0, 0, 3, 4)
    path.rounded_rect(0, 0, 3, 4, 1, 1, 1, 1, True)
    path.ellipse(1, 2, 3, 4)
    path.circle(1, 2, 3)
    path.polygon(1, 2, 3, 5)
    path.close_path()
    assert path.compute_bounds().w > 0

    rect_path = pixie.Path()
    rect_path.rect(0, 0, 10, 10)
    solid_dashes = pixie.SeqFloat32()
    assert rect_path.fill_overlaps(pixie.Vec2(5, 5), None, pixie.NON_ZERO)
    assert rect_path.stroke_overlaps(
        pixie.Vec2(0, 5), None, 2, pixie.BUTT_CAP, pixie.MITER_JOIN, pixie.DEFAULT_MITER_LIMIT, solid_dashes
    )

    typeface = pixie.read_typeface(font_path)
    assert typeface.file_path.endswith("Inter-Regular.ttf")
    typeface.file_path = font_path
    assert typeface.has_glyph("A")
    assert typeface.get_advance("A") > 0
    assert typeface.get_glyph_path("A").compute_bounds().w > 0
    for invalid_rune in ("AB", "\ud800"):
        try:
            typeface.has_glyph(invalid_rune)
        except AssertionError:
            continue
        raise AssertionError("invalid rune was accepted")

    font = typeface.new_font()
    font.size = 24
    font.line_height = pixie.AUTO_LINE_HEIGHT
    font.paint = solid
    font.text_case = pixie.UPPER_CASE
    font.underline = True
    font.strikethrough = True
    font.no_kerning_adjustments = True
    font.paints.append(solid)
    assert len(font.paints) >= 1
    assert font.scale() > 0
    assert font.default_line_height() > 0
    assert font.layout_bounds("abcd").x > 0
    assert font.typeset("abcd", pixie.Vec2(100, 100), pixie.LEFT_ALIGN, pixie.TOP_ALIGN, True).layout_bounds().x > 0

    span = pixie.Span("hi", font)
    span.text = "hello"
    spans = pixie.SeqSpan()
    spans.append(span)
    arrangement = spans.typeset(pixie.Vec2(100, 100), pixie.CENTER_ALIGN, pixie.BOTTOM_ALIGN, True)
    assert spans[0].text == "hello"
    assert arrangement.layout_bounds().x > 0
    assert spans.layout_bounds().y > 0
    assert arrangement.compute_bounds(mat).x > 0

    canvas = pixie.Image(64, 64)
    canvas.fill(pixie.parse_color("#ffffff"))
    canvas.fill_text(font, "abc", mat, pixie.Vec2(60, 60), pixie.LEFT_ALIGN, pixie.TOP_ALIGN)
    canvas.arrangement_fill_text(arrangement, mat)
    canvas.stroke_text(
        font, "abc", mat, 2, pixie.Vec2(60, 60), pixie.LEFT_ALIGN, pixie.TOP_ALIGN,
        pixie.BUTT_CAP, pixie.MITER_JOIN, pixie.DEFAULT_MITER_LIMIT, dashes
    )
    canvas.arrangement_stroke_text(arrangement, mat, 2, pixie.BUTT_CAP, pixie.MITER_JOIN, pixie.DEFAULT_MITER_LIMIT, dashes)
    canvas.fill_path(rect_path, solid, mat, pixie.NON_ZERO)
    canvas.stroke_path(rect_path, solid, mat, 2, pixie.BUTT_CAP, pixie.MITER_JOIN, pixie.DEFAULT_MITER_LIMIT, dashes)

    ctx = pixie.Context(80, 80)
    ctx.global_alpha = 0.75
    ctx.line_width = 2
    ctx.miter_limit = 5
    ctx.line_cap = pixie.ROUND_CAP
    ctx.line_join = pixie.BEVEL_JOIN
    ctx.font = font_path
    ctx.font_size = 24
    ctx.text_align = pixie.RIGHT_ALIGN
    assert ctx.text_align == pixie.RIGHT_ALIGN
    assert ctx.measure_text("abcd").width > 0
    ctx.set_transform(mat)
    assert matrix_values(ctx.get_transform())[6] == 3
    ctx.transform(pixie.scale(2, 2))
    ctx.reset_transform()
    ctx.set_line_dash(solid_dashes)
    ctx.begin_path()
    ctx.rect(0, 0, 10, 10)
    assert ctx.is_point_in_path(5, 5, pixie.NON_ZERO)
    assert ctx.path_is_point_in_path(rect_path, 5, 5, pixie.NON_ZERO)
    assert ctx.is_point_in_stroke(0, 5)
    assert ctx.path_is_point_in_stroke(rect_path, 0, 5)
    ctx.set_line_dash(dashes)
    assert len(ctx.get_line_dash()) == 2
    ctx.move_to(1, 1)
    ctx.line_to(2, 2)
    ctx.bezier_curve_to(1, 2, 3, 4, 5, 6)
    ctx.quadratic_curve_to(1, 2, 3, 4)
    ctx.arc(1, 2, 3, 0, 1, False)
    ctx.arc_to(1, 2, 3, 4, 5)
    ctx.rounded_rect(0, 0, 3, 4, 1, 1, 1, 1)
    ctx.ellipse(1, 2, 3, 4)
    ctx.circle(1, 2, 3)
    ctx.polygon(1, 2, 3, 5)
    ctx.close_path()
    ctx.fill(pixie.NON_ZERO)
    ctx.path_fill(rect_path, pixie.EVEN_ODD)
    ctx.clip(pixie.NON_ZERO)
    ctx.path_clip(rect_path, pixie.EVEN_ODD)
    ctx.stroke()
    ctx.path_stroke(rect_path)
    ctx.draw_image(canvas, 1, 2)
    ctx.draw_image2(canvas, 1, 2, 3, 4)
    ctx.draw_image3(canvas, 1, 2, 3, 4, 5, 6, 7, 8)
    ctx.clear_rect(1, 2, 3, 4)
    ctx.fill_rect(1, 2, 3, 4)
    ctx.stroke_rect(1, 2, 3, 4)
    ctx.stroke_segment(1, 2, 3, 4)
    ctx.fill_text("abc", 1, 2)
    ctx.stroke_text("abc", 1, 2)
    ctx.translate(3, 4)
    ctx.scale(2, 3)
    ctx.rotate(0.5)
    ctx.save()
    ctx.save_layer()
    ctx.restore()

    decoded = pixie.decode_base64(canvas.encode_base64())
    assert decoded.width == canvas.width
    assert decoded.height == canvas.height
    assert pixie.decode_image(ppm).width == 2
    assert pixie.decode_image_dimensions(ppm).height == 1
    assert pixie.read_image(image_path).width == 40
    assert pixie.read_image_dimensions(image_path).height == 40
    assert pixie.read_font(font_path).size == 12
    assert pixie.parse_path("M0 0 L10 0 L10 10 Z").compute_bounds().w == 10

    try:
        pixie.parse_color("bad")
    except pixie.PixieError as exc:
        assert "bad" in str(exc)
    else:
        raise AssertionError("parse_color should raise on invalid colors")
