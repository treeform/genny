const std = @import("std");
const pixie = @import("generated/pixie.zig");

fn expect(ok: bool) !void {
    if (!ok) return error.TestFailed;
}

fn approx(value: f32, expected: f32) !void {
    try expect(@abs(value - expected) < 0.0001);
}

fn approxEps(value: f32, expected: f32, eps: f32) !void {
    try expect(@abs(value - expected) <= eps);
}

pub fn main() !void {
    @setEvalBranchQuota(10000);

    const font_path = "../../pixie/tests/fonts/Inter-Regular.ttf";
    const image_path = "../../pixie/tests/images/turtle.png";
    const ppm = "P3\n2 1\n255\n255 0 0 0 255 0\n";

    try expect(pixie.default_miter_limit == 4.0);
    try expect(pixie.auto_line_height == -1.0);
    try expect(@intFromEnum(pixie.FileFormat.png_format) == 0);
    try expect(@intFromEnum(pixie.PaintKind.linear_gradient_paint) == 3);

    const red = try pixie.parseColor("#ff0000");
    const green = try pixie.parseColor("#00ff00");
    const mixed = pixie.mix(red, green, 0.25);
    try approx(mixed.r, 0.75);
    try approx(mixed.g, 0.25);

    const mat = pixie.translate(3, 4);
    const identity = pixie.translate(0, 0);
    try expect(mat.values[6] == 3);
    try expect(pixie.inverse(mat).values[6] == -3);
    try expect(pixie.snapToPixels(pixie.Rect.init(1, 2, 3, 4)).eql(pixie.Rect.init(1, 2, 3, 4)));
    try expect(pixie.miterLimitToAngle(2) > 0);
    try expect(pixie.angleToMiterLimit(1) > 0);

    const dashes = pixie.SeqFloat32.init();
    defer dashes.deinit();
    dashes.append(1.5);
    dashes.append(2.5);
    dashes.set(1, 3.5);
    try expect(dashes.len() == 2);
    try approx(dashes.get(1), 3.5);

    const image = try pixie.Image.init(4, 3);
    defer image.deinit();
    try expect(image.getWidth() == 4);
    try expect(image.getHeight() == 3);
    try expect((try image.encodeBase64()).len > 20);
    image.fill(red);
    try expect(image.isOneColor());
    try expect(image.isOpaque());
    try expect(image.getColor(1, 1).eql(red));
    image.setColor(0, 0, green);
    try expect(!image.isOneColor());
    const image_copy = image.copy();
    defer image_copy.deinit();
    try expect(image_copy.getWidth() == image.getWidth());

    const solid = pixie.Paint.init(.solid_paint);
    defer solid.deinit();
    solid.setColor(red);
    try image.fillPaint(solid);
    image.applyOpacity(0.5);
    try approxEps(image.getColor(0, 0).a, 0.5, 0.01);
    image.invert();
    try image.blur(1, red);

    const resized = try image.resize(6, 5);
    defer resized.deinit();
    try expect(resized.getWidth() == 6);
    try expect(resized.getHeight() == 5);
    try resized.rotate90();
    try expect(resized.getWidth() == 5);
    try expect(resized.getHeight() == 6);
    const sub = try resized.subImage(0, 0, 2, 2);
    defer sub.deinit();
    try expect(sub.getWidth() == 2);
    const rect_sub = try resized.subImageRect(pixie.Rect.init(0, 0, 1, 1));
    defer rect_sub.deinit();
    try expect(rect_sub.getHeight() == 1);
    const shadow = try resized.shadow(pixie.Vector2.init(1, 2), 3, 4, red);
    defer shadow.deinit();
    try expect(shadow.getWidth() == resized.getWidth());
    const super_image = try resized.superImage(-1, -1, resized.getWidth() + 2, resized.getHeight() + 2);
    defer super_image.deinit();
    try expect(super_image.getWidth() == resized.getWidth() + 2);
    try expect(resized.opaqueBounds().w > 0);

    const paint = pixie.Paint.init(.solid_paint);
    defer paint.deinit();
    paint.setKind(.linear_gradient_paint);
    paint.setBlendMode(.multiply_blend);
    paint.setOpacity(0.5);
    paint.setColor(green);
    paint.setImageMat(pixie.scale(2, 3));
    try expect(paint.getKind() == .linear_gradient_paint);
    try approx(paint.getOpacity(), 0.5);
    paint.appendGradientHandlePositions(pixie.Vector2.init(0.25, 0));
    paint.appendGradientHandlePositions(pixie.Vector2.init(0.75, 1));
    paint.setGradientHandlePositions(1, pixie.Vector2.init(0.8, 1));
    try expect(paint.lenGradientHandlePositions() == 2);
    try approx(paint.getGradientHandlePositions(1).x, 0.8);
    paint.appendGradientStops(pixie.ColorStop.init(red, 0));
    paint.appendGradientStops(pixie.ColorStop.init(green, 1));
    try expect(paint.lenGradientStops() == 2);
    try expect(paint.getGradientStops(1).color.eql(green));

    const path = pixie.Path.init();
    defer path.deinit();
    path.moveTo(1, 1);
    path.lineTo(2, 2);
    path.bezierCurveTo(1, 2, 3, 4, 5, 6);
    path.quadraticCurveTo(1, 2, 3, 4);
    path.ellipticalArcTo(1, 2, 3, false, true, 4, 5);
    try path.arc(1, 2, 3, 0, 1, false);
    try path.arcTo(1, 2, 3, 4, 5);
    path.rect(0, 0, 3, 4, true);
    path.roundedRect(0, 0, 3, 4, 1, 1, 1, 1, true);
    path.ellipse(1, 2, 3, 4);
    path.circle(1, 2, 3);
    try path.polygon(1, 2, 3, 5);
    path.closePath();
    try expect((try path.computeBounds(identity)).w > 0);

    const rect_path = pixie.Path.init();
    defer rect_path.deinit();
    rect_path.rect(0, 0, 10, 10, true);
    const solid_dashes = pixie.SeqFloat32.init();
    defer solid_dashes.deinit();
    try expect(try rect_path.fillOverlaps(pixie.Vector2.init(5, 5), identity, .non_zero));
    try expect(try rect_path.strokeOverlaps(pixie.Vector2.init(0, 5), identity, 2, .butt_cap, .miter_join, pixie.default_miter_limit, solid_dashes));

    const typeface = try pixie.readTypeface(font_path);
    defer typeface.deinit();
    try expect(std.mem.endsWith(u8, typeface.getFilePath(), "Inter-Regular.ttf"));
    typeface.setFilePath(font_path);
    try expect(typeface.hasGlyph('A'));
    try expect(typeface.getAdvance('A') > 0);
    const glyph = try typeface.getGlyphPath('A');
    defer glyph.deinit();
    try expect((try glyph.computeBounds(identity)).w > 0);

    const font = typeface.newFont();
    defer font.deinit();
    font.setSize(24);
    font.setLineHeight(pixie.auto_line_height);
    font.setPaint(solid);
    font.setTextCase(.upper_case);
    font.setUnderline(true);
    font.setStrikethrough(true);
    font.setNoKerningAdjustments(true);
    font.appendPaints(solid);
    try expect(font.lenPaints() >= 1);
    try expect(font.scale() > 0);
    try expect(font.defaultLineHeight() > 0);
    try expect(font.layoutBounds("abcd").x > 0);
    const font_arrangement = font.typeset("abcd", pixie.Vector2.init(100, 100), .left_align, .top_align, true);
    defer font_arrangement.deinit();
    try expect(font_arrangement.layoutBounds().x > 0);

    const span = pixie.Span.init("hi", font);
    defer span.deinit();
    span.setText("hello");
    const spans = pixie.SeqSpan.init();
    defer spans.deinit();
    spans.append(span);
    const arrangement = spans.typeset(pixie.Vector2.init(100, 100), .center_align, .bottom_align, true);
    defer arrangement.deinit();
    try expect(std.mem.eql(u8, spans.get(0).getText(), "hello"));
    try expect(arrangement.layoutBounds().x > 0);
    try expect(spans.layoutBounds().y > 0);
    try expect((try arrangement.computeBounds(mat)).x > 0);

    const canvas = try pixie.Image.init(64, 64);
    defer canvas.deinit();
    canvas.fill(try pixie.parseColor("#ffffff"));
    try canvas.fillText(font, "abc", mat, pixie.Vector2.init(60, 60), .left_align, .top_align);
    try canvas.fillTextArrangement(arrangement, mat);
    try canvas.strokeText(font, "abc", mat, 2, pixie.Vector2.init(60, 60), .left_align, .top_align, .butt_cap, .miter_join, pixie.default_miter_limit, dashes);
    try canvas.strokeTextArrangement(arrangement, mat, 2, .butt_cap, .miter_join, pixie.default_miter_limit, dashes);
    try canvas.fillPath(rect_path, solid, mat, .non_zero);
    try canvas.strokePath(rect_path, solid, mat, 2, .butt_cap, .miter_join, pixie.default_miter_limit, dashes);

    const ctx = try pixie.Context.init(80, 80);
    defer ctx.deinit();
    ctx.setGlobalAlpha(0.75);
    ctx.setLineWidth(2);
    ctx.setMiterLimit(5);
    ctx.setLineCap(.round_cap);
    ctx.setLineJoin(.bevel_join);
    ctx.setFont(font_path);
    ctx.setFontSize(24);
    ctx.setTextAlign(.right_align);
    try expect(ctx.getTextAlign() == .right_align);
    try expect((try ctx.measureText("abcd")).width > 0);
    ctx.setTransform(mat);
    try expect(ctx.getTransform().values[6] == 3);
    ctx.transform(pixie.scale(2, 2));
    ctx.resetTransform();
    ctx.setLineDash(solid_dashes);
    ctx.beginPath();
    ctx.rect(0, 0, 10, 10);
    try expect(try ctx.isPointInPath(5, 5, .non_zero));
    try expect(try ctx.isPointInPathPath(rect_path, 5, 5, .non_zero));
    try expect(try ctx.isPointInStroke(0, 5));
    try expect(try ctx.isPointInStrokePath(rect_path, 0, 5));
    ctx.setLineDash(dashes);
    const ctx_dashes = ctx.getLineDash();
    defer ctx_dashes.deinit();
    try expect(ctx_dashes.len() == 2);
    ctx.moveTo(1, 1);
    ctx.lineTo(2, 2);
    ctx.bezierCurveTo(1, 2, 3, 4, 5, 6);
    ctx.quadraticCurveTo(1, 2, 3, 4);
    try ctx.arc(1, 2, 3, 0, 1, false);
    try ctx.arcTo(1, 2, 3, 4, 5);
    ctx.roundedRect(0, 0, 3, 4, 1, 1, 1, 1);
    ctx.ellipse(1, 2, 3, 4);
    ctx.circle(1, 2, 3);
    try ctx.polygon(1, 2, 3, 5);
    ctx.closePath();
    try ctx.fill(.non_zero);
    try ctx.fillPath(rect_path, .even_odd);
    try ctx.clip(.non_zero);
    try ctx.clipPath(rect_path, .even_odd);
    try ctx.stroke();
    try ctx.strokePath(rect_path);
    try ctx.drawImage(canvas, 1, 2);
    try ctx.drawImage2(canvas, 1, 2, 3, 4);
    try ctx.drawImage3(canvas, 1, 2, 3, 4, 5, 6, 7, 8);
    try ctx.clearRect(1, 2, 3, 4);
    try ctx.fillRect(1, 2, 3, 4);
    try ctx.strokeRect(1, 2, 3, 4);
    try ctx.strokeSegment(1, 2, 3, 4);
    try ctx.fillText("abc", 1, 2);
    try ctx.strokeText("abc", 1, 2);
    ctx.translate(3, 4);
    ctx.scale(2, 3);
    ctx.rotate(0.5);
    ctx.save();
    try ctx.saveLayer();
    try ctx.restore();

    const decoded = try pixie.decodeBase64(try canvas.encodeBase64());
    defer decoded.deinit();
    try expect(decoded.getWidth() == canvas.getWidth());
    try expect(decoded.getHeight() == canvas.getHeight());
    const decoded_image = try pixie.decodeImage(ppm);
    defer decoded_image.deinit();
    try expect(decoded_image.getWidth() == 2);
    try expect((try pixie.decodeImageDimensions(ppm)).height == 1);
    const read_image = try pixie.readImage(image_path);
    defer read_image.deinit();
    try expect(read_image.getWidth() == 40);
    try expect((try pixie.readImageDimensions(image_path)).height == 40);
    const read_font = try pixie.readFont(font_path);
    defer read_font.deinit();
    try approx(read_font.getSize(), 12);
    const parsed_path = try pixie.parsePath("M0 0 L10 0 L10 10 Z");
    defer parsed_path.deinit();
    try expect((try parsed_path.computeBounds(identity)).w == 10);
    if (pixie.parseColor("bad")) |_| {
        return error.TestFailed;
    } else |err| {
        try expect(err == error.PixieError);
    }
    try expect(pixie.checkError());
    try expect(std.mem.indexOf(u8, pixie.takeError(), "bad") != null);

    std.debug.print("All Pixie Zig tests passed!\n", .{});
}
