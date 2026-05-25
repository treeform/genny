#include <cassert>
#include <cmath>
#include <cstring>
#include <iostream>
#include <string>
#include "pixie.hpp"

#ifndef PIXIE_ROOT
#define PIXIE_ROOT "../pixie"
#endif

#define FONT_PATH PIXIE_ROOT "/tests/fonts/Inter-Regular.ttf"
#define IMAGE_PATH PIXIE_ROOT "/tests/images/turtle.png"

static void approx(float value, float expected, float eps = 0.0001f) {
    assert(std::fabs(value - expected) <= eps);
}

static void assertColor(Color actual, Color expected) {
    approx(actual.r, expected.r);
    approx(actual.g, expected.g);
    approx(actual.b, expected.b);
    approx(actual.a, expected.a);
}

int main() {
    const char *ppm = "P3\n2 1\n255\n255 0 0 0 255 0\n";

    assert(DEFAULT_MITER_LIMIT == 4.0f);
    assert(AUTO_LINE_HEIGHT == -1.0f);
    assert(PNG_FORMAT == 0);
    assert(LINEAR_GRADIENT_PAINT == 3);

    Color red = parseColor("#ff0000");
    Color green = parseColor("#00ff00");
    Color mixed = mix(red, green, 0.25f);
    approx(mixed.r, 0.75f);
    approx(mixed.g, 0.25f);

    Matrix3 mat = translate(3, 4);
    Matrix3 identity = translate(0, 0);
    assert(mat.values[6] == 3);
    assert(inverse(mat).values[6] == -3);
    assert(pixie_rect_eq(snapToPixels(rect(1, 2, 3, 4)), rect(1, 2, 3, 4)));
    assert(miterLimitToAngle(2) > 0);
    assert(angleToMiterLimit(1) > 0);

    SeqFloat32 dashes;
    dashes.add(1.5f);
    dashes.add(2.5f);
    dashes.set(1, 3.5f);
    assert(dashes.size() == 2);
    approx(dashes[1], 3.5f);

    Image image(4, 3);
    assert(image.getWidth() == 4);
    assert(image.getHeight() == 3);
    assert(image.encodeBase64().size() > 20);
    image.fill(red);
    assert(image.isOneColor());
    assert(image.isOpaque());
    assertColor(image.getColor(1, 1), red);
    image.setColor(0, 0, green);
    assert(!image.isOneColor());
    assert(image.copy().getWidth() == image.getWidth());

    Paint solid(SOLID_PAINT);
    solid.setColor(red);
    image.fill(solid);
    image.applyOpacity(0.5f);
    approx(image.getColor(0, 0).a, 0.5f, 0.01f);
    image.invert();
    image.blur(1, red);

    Image resized = image.resize(6, 5);
    assert(resized.getWidth() == 6);
    assert(resized.getHeight() == 5);
    resized.rotate90();
    assert(resized.getWidth() == 5);
    assert(resized.getHeight() == 6);
    assert(resized.subImage(0, 0, 2, 2).getWidth() == 2);
    assert(resized.subImage(rect(0, 0, 1, 1)).getHeight() == 1);
    assert(resized.shadow(vector2(1, 2), 3, 4, red).getWidth() == resized.getWidth());
    assert(resized.superImage(-1, -1, resized.getWidth() + 2, resized.getHeight() + 2).getWidth() == resized.getWidth() + 2);
    assert(resized.opaqueBounds().w > 0);

    Paint paint(SOLID_PAINT);
    paint.setKind(LINEAR_GRADIENT_PAINT);
    paint.setBlendMode(MULTIPLY_BLEND);
    paint.setOpacity(0.5f);
    paint.setColor(green);
    paint.setImageMat(scale(2, 3));
    assert(paint.getKind() == LINEAR_GRADIENT_PAINT);
    approx(paint.getOpacity(), 0.5f);
    paint.addGradientHandlePositions(vector2(0.25f, 0));
    paint.addGradientHandlePositions(vector2(0.75f, 1));
    paint.setGradientHandlePositions(1, vector2(0.8f, 1));
    assert(paint.gradientHandlePositionsSize() == 2);
    approx(paint.getGradientHandlePositions(1).x, 0.8f);
    paint.addGradientStops(colorStop(red, 0));
    paint.addGradientStops(colorStop(green, 1));
    assert(paint.gradientStopsSize() == 2);
    assertColor(paint.getGradientStops(1).color, green);

    Path path;
    path.moveTo(1, 1);
    path.lineTo(2, 2);
    path.bezierCurveTo(1, 2, 3, 4, 5, 6);
    path.quadraticCurveTo(1, 2, 3, 4);
    path.ellipticalArcTo(1, 2, 3, false, true, 4, 5);
    path.arc(1, 2, 3, 0, 1, false);
    path.arcTo(1, 2, 3, 4, 5);
    path.rect(0, 0, 3, 4, true);
    path.roundedRect(0, 0, 3, 4, 1, 1, 1, 1, true);
    path.ellipse(1, 2, 3, 4);
    path.circle(1, 2, 3);
    path.polygon(1, 2, 3, 5);
    path.closePath();
    assert(path.computeBounds(identity).w > 0);

    Path rectPath;
    rectPath.rect(0, 0, 10, 10, true);
    SeqFloat32 solidDashes;
    assert(rectPath.fillOverlaps(vector2(5, 5), identity, NON_ZERO));
    assert(rectPath.strokeOverlaps(vector2(0, 5), identity, 2, BUTT_CAP, MITER_JOIN, DEFAULT_MITER_LIMIT, solidDashes));

    Typeface typeface = readTypeface(FONT_PATH);
    assert(typeface.getFilePath().find("Inter-Regular.ttf") != std::string::npos);
    typeface.setFilePath(FONT_PATH);
    assert(typeface.hasGlyph(U'A'));
    assert(typeface.getAdvance(U'A') > 0);
    assert(typeface.getGlyphPath(U'A').computeBounds(identity).w > 0);

    Font font = typeface.newFont();
    font.setSize(24);
    font.setLineHeight(AUTO_LINE_HEIGHT);
    font.setPaint(solid);
    font.setTextCase(UPPER_CASE);
    font.setUnderline(true);
    font.setStrikethrough(true);
    font.setNoKerningAdjustments(true);
    font.addPaints(solid);
    assert(font.paintsSize() >= 1);
    assert(font.scale() > 0);
    assert(font.defaultLineHeight() > 0);
    assert(font.layoutBounds("abcd").x > 0);
    assert(font.typeset("abcd", vector2(100, 100), LEFT_ALIGN, TOP_ALIGN, true).layoutBounds().x > 0);

    Span span("hi", font);
    span.setText("hello");
    SeqSpan spans;
    spans.add(span);
    Arrangement arrangement = spans.typeset(vector2(100, 100), CENTER_ALIGN, BOTTOM_ALIGN, true);
    assert(spans[0].getText() == "hello");
    assert(arrangement.layoutBounds().x > 0);
    assert(spans.layoutBounds().y > 0);
    assert(arrangement.computeBounds(mat).x > 0);

    Image canvas(64, 64);
    canvas.fill(parseColor("#ffffff"));
    canvas.fillText(font, "abc", mat, vector2(60, 60), LEFT_ALIGN, TOP_ALIGN);
    canvas.fillText(arrangement, mat);
    canvas.strokeText(font, "abc", mat, 2, vector2(60, 60), LEFT_ALIGN, TOP_ALIGN, BUTT_CAP, MITER_JOIN, DEFAULT_MITER_LIMIT, dashes);
    canvas.strokeText(arrangement, mat, 2, BUTT_CAP, MITER_JOIN, DEFAULT_MITER_LIMIT, dashes);
    canvas.fillPath(rectPath, solid, mat, NON_ZERO);
    canvas.strokePath(rectPath, solid, mat, 2, BUTT_CAP, MITER_JOIN, DEFAULT_MITER_LIMIT, dashes);

    Context ctx(80, 80);
    ctx.setGlobalAlpha(0.75f);
    ctx.setLineWidth(2);
    ctx.setMiterLimit(5);
    ctx.setLineCap(ROUND_CAP);
    ctx.setLineJoin(BEVEL_JOIN);
    ctx.setFont(FONT_PATH);
    ctx.setFontSize(24);
    ctx.setTextAlign(RIGHT_ALIGN);
    assert(ctx.getTextAlign() == RIGHT_ALIGN);
    assert(ctx.measureText("abcd").width > 0);
    ctx.setTransform(mat);
    assert(ctx.getTransform().values[6] == 3);
    ctx.transform(scale(2, 2));
    ctx.resetTransform();
    ctx.setLineDash(solidDashes);
    ctx.beginPath();
    ctx.rect(0, 0, 10, 10);
    assert(ctx.isPointInPath(5, 5, NON_ZERO));
    assert(ctx.isPointInPath(rectPath, 5, 5, NON_ZERO));
    assert(ctx.isPointInStroke(0, 5));
    assert(ctx.isPointInStroke(rectPath, 0, 5));
    ctx.setLineDash(dashes);
    SeqFloat32 ctxDashes = ctx.getLineDash();
    assert(ctxDashes.size() == 2);
    ctx.moveTo(1, 1);
    ctx.lineTo(2, 2);
    ctx.bezierCurveTo(1, 2, 3, 4, 5, 6);
    ctx.quadraticCurveTo(1, 2, 3, 4);
    ctx.arc(1, 2, 3, 0, 1, false);
    ctx.arcTo(1, 2, 3, 4, 5);
    ctx.roundedRect(0, 0, 3, 4, 1, 1, 1, 1);
    ctx.ellipse(1, 2, 3, 4);
    ctx.circle(1, 2, 3);
    ctx.polygon(1, 2, 3, 5);
    ctx.closePath();
    ctx.fill(NON_ZERO);
    ctx.fill(rectPath, EVEN_ODD);
    ctx.clip(NON_ZERO);
    ctx.clip(rectPath, EVEN_ODD);
    ctx.stroke();
    ctx.stroke(rectPath);
    ctx.drawImage(canvas, 1, 2);
    ctx.drawImage2(canvas, 1, 2, 3, 4);
    ctx.drawImage3(canvas, 1, 2, 3, 4, 5, 6, 7, 8);
    ctx.clearRect(1, 2, 3, 4);
    ctx.fillRect(1, 2, 3, 4);
    ctx.strokeRect(1, 2, 3, 4);
    ctx.strokeSegment(1, 2, 3, 4);
    ctx.fillText("abc", 1, 2);
    ctx.strokeText("abc", 1, 2);
    ctx.translate(3, 4);
    ctx.scale(2, 3);
    ctx.rotate(0.5f);
    ctx.save();
    ctx.saveLayer();
    ctx.restore();

    std::string encodedCanvas = canvas.encodeBase64();
    Image decoded = decodeBase64(encodedCanvas.c_str());
    assert(decoded.getWidth() == canvas.getWidth());
    assert(decoded.getHeight() == canvas.getHeight());
    assert(decodeImage(ppm).getWidth() == 2);
    assert(decodeImageDimensions(ppm).height == 1);
    assert(readImage(IMAGE_PATH).getWidth() == 40);
    assert(readImageDimensions(IMAGE_PATH).height == 40);
    approx(readFont(FONT_PATH).getSize(), 12);
    assert(parsePath("M0 0 L10 0 L10 10 Z").computeBounds(identity).w == 10);
    parseColor("bad");
    assert(checkError());
    assert(takeError().find("bad") != std::string::npos);

    std::cout << "All Pixie C++ tests passed!" << std::endl;
    return 0;
}
