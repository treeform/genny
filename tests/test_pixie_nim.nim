import os, strutils
import ../../pixie/bindings/generated/pixie

proc approx(value, expected: float32; eps: float32 = 0.0001) =
  doAssert abs(value - expected) <= eps

let
  pixieRoot = getEnv("PIXIE_ROOT", "../pixie")
  fontPath = pixieRoot / "tests" / "fonts" / "Inter-Regular.ttf"
  imagePath = pixieRoot / "tests" / "images" / "turtle.png"
  ppm = "P3\n2 1\n255\n255 0 0 0 255 0\n"

doAssert defaultMiterLimit == 4.0
doAssert autoLineHeight == -1.0
doAssert PngFormat.ord == 0
doAssert LinearGradientPaint.ord == 3

let
  red = parseColor("#ff0000")
  green = parseColor("#00ff00")

let
  mat = translate(3, 4)
  identity = translate(0, 0)
doAssert mat.values[6] == 3
doAssert inverse(mat).values[6] == -3
doAssert snapToPixels(rect(1, 2, 3, 4)) == rect(1, 2, 3, 4)
doAssert miterLimitToAngle(2) > 0
doAssert angleToMiterLimit(1) > 0

let dashes = newSeqFloat32()
dashes.add(1.5)
dashes.add(2.5)
dashes[1] = 3.5
doAssert dashes.len == 2
approx(dashes[1], 3.5)

let image = newImage(4, 3)
doAssert image.width == 4
doAssert image.height == 3
doAssert ($image.encodeBase64()).len > 20
image.fill(red)
doAssert image.isOneColor()
doAssert image.isOpaque()
doAssert image.getColor(1, 1) == red
image.setColor(0, 0, green)
doAssert not image.isOneColor()
doAssert image.copy().width == image.width

let solid = newPaint(SolidPaint)
solid.color = red
image.fill(solid)
image.applyOpacity(0.5)
approx(image.getColor(0, 0).a, 0.5, 0.01)
image.invert()
image.blur(1, red)

let resized = image.resize(6, 5)
doAssert resized.width == 6
doAssert resized.height == 5
resized.rotate90()
doAssert resized.width == 5
doAssert resized.height == 6
doAssert resized.subImage(0, 0, 2, 2).width == 2
doAssert resized.subImage(rect(0, 0, 1, 1)).height == 1
doAssert resized.shadow(vector2(1, 2), 3, 4, red).width == resized.width
doAssert resized.superImage(-1, -1, resized.width + 2, resized.height + 2).width == resized.width + 2
doAssert resized.opaqueBounds().w > 0

let paint = newPaint(SolidPaint)
paint.kind = LinearGradientPaint
paint.blendMode = MultiplyBlend
paint.opacity = 0.5
paint.color = green
paint.imageMat = scale(2, 3)
doAssert paint.kind == LinearGradientPaint
approx(paint.opacity, 0.5)
paint.gradientHandlePositions.add(vector2(0.25, 0))
paint.gradientHandlePositions.add(vector2(0.75, 1))
paint.gradientHandlePositions[1] = vector2(0.8, 1)
doAssert paint.gradientHandlePositions.len == 2
approx(paint.gradientHandlePositions[1].x, 0.8)
paint.gradientStops.add(colorStop(red, 0))
paint.gradientStops.add(colorStop(green, 1))
doAssert paint.gradientStops.len == 2
doAssert paint.gradientStops[1].color == green

let pathShape = newPath()
pathShape.moveTo(1, 1)
pathShape.lineTo(2, 2)
pathShape.bezierCurveTo(1, 2, 3, 4, 5, 6)
pathShape.quadraticCurveTo(1, 2, 3, 4)
pathShape.ellipticalArcTo(1, 2, 3, false, true, 4, 5)
pathShape.arc(1, 2, 3, 0, 1, false)
pathShape.arcTo(1, 2, 3, 4, 5)
pathShape.rect(0, 0, 3, 4, true)
pathShape.roundedRect(0, 0, 3, 4, 1, 1, 1, 1, true)
pathShape.ellipse(1, 2, 3, 4)
pathShape.circle(1, 2, 3)
pathShape.polygon(1, 2, 3, 5)
pathShape.closePath()
doAssert pathShape.computeBounds(identity).w > 0

let rectPath = newPath()
rectPath.rect(0, 0, 10, 10, true)
let solidDashes = newSeqFloat32()
doAssert rectPath.fillOverlaps(vector2(5, 5), identity, NonZero)
doAssert rectPath.strokeOverlaps(vector2(0, 5), identity, 2, ButtCap, MiterJoin, defaultMiterLimit, solidDashes)

let typeface = readTypeface(fontPath)
doAssert ($typeface.filePath).endsWith("Inter-Regular.ttf")
typeface.filePath = fontPath
doAssert typeface.hasGlyph(int32(ord('A')))
doAssert typeface.getAdvance(int32(ord('A'))) > 0
doAssert typeface.getGlyphPath(int32(ord('A'))).computeBounds(identity).w > 0

let font = typeface.newFont()
font.size = 24
font.lineHeight = autoLineHeight
font.paint = solid
font.textCase = UpperCase
font.underline = true
font.strikethrough = true
font.noKerningAdjustments = true
font.paints.add(solid)
doAssert font.paints.len >= 1
doAssert font.scale() > 0
doAssert font.defaultLineHeight() > 0
doAssert font.layoutBounds("abcd").x > 0
doAssert font.typeset("abcd", vector2(100, 100), LeftAlign, TopAlign, true).layoutBounds().x > 0

let span = newSpan("hi", font)
span.text = "hello"
let spans = newSeqSpan()
spans.add(span)
let arrangement = spans.typeset(vector2(100, 100), CenterAlign, BottomAlign, true)
doAssert $spans[0].text == "hello"
doAssert arrangement.layoutBounds().x > 0
doAssert spans.layoutBounds().y > 0
doAssert arrangement.computeBounds(mat).x > 0

let canvas = newImage(64, 64)
canvas.fill(parseColor("#ffffff"))
canvas.fillText(font, "abc", mat, vector2(60, 60), LeftAlign, TopAlign)
canvas.fillText(arrangement, mat)
canvas.strokeText(font, "abc", mat, 2, vector2(60, 60), LeftAlign, TopAlign, ButtCap, MiterJoin, defaultMiterLimit, dashes)
canvas.strokeText(arrangement, mat, 2, ButtCap, MiterJoin, defaultMiterLimit, dashes)
canvas.fillPath(rectPath, solid, mat, NonZero)
canvas.strokePath(rectPath, solid, mat, 2, ButtCap, MiterJoin, defaultMiterLimit, dashes)

let ctx = newContext(80, 80)
ctx.globalAlpha = 0.75
ctx.lineWidth = 2
ctx.miterLimit = 5
ctx.lineCap = RoundCap
ctx.lineJoin = BevelJoin
ctx.font = fontPath
ctx.fontSize = 24
ctx.textAlign = RightAlign
doAssert ctx.textAlign == RightAlign
doAssert ctx.measureText("abcd").width > 0
ctx.setTransform(mat)
doAssert ctx.getTransform().values[6] == 3
ctx.transform(scale(2, 2))
ctx.resetTransform()
ctx.setLineDash(solidDashes)
ctx.beginPath()
ctx.rect(0, 0, 10, 10)
doAssert ctx.isPointInPath(5, 5, NonZero)
doAssert ctx.isPointInPath(rectPath, 5, 5, NonZero)
doAssert ctx.isPointInStroke(0, 5)
doAssert ctx.isPointInStroke(rectPath, 0, 5)
ctx.setLineDash(dashes)
doAssert ctx.getLineDash().len == 2
ctx.moveTo(1, 1)
ctx.lineTo(2, 2)
ctx.bezierCurveTo(1, 2, 3, 4, 5, 6)
ctx.quadraticCurveTo(1, 2, 3, 4)
ctx.arc(1, 2, 3, 0, 1, false)
ctx.arcTo(1, 2, 3, 4, 5)
ctx.roundedRect(0, 0, 3, 4, 1, 1, 1, 1)
ctx.ellipse(1, 2, 3, 4)
ctx.circle(1, 2, 3)
ctx.polygon(1, 2, 3, 5)
ctx.closePath()
ctx.fill(NonZero)
ctx.fill(rectPath, EvenOdd)
ctx.clip(NonZero)
ctx.clip(rectPath, EvenOdd)
ctx.stroke()
ctx.stroke(rectPath)
ctx.drawImage(canvas, 1, 2)
ctx.drawImage2(canvas, 1, 2, 3, 4)
ctx.drawImage3(canvas, 1, 2, 3, 4, 5, 6, 7, 8)
ctx.clearRect(1, 2, 3, 4)
ctx.fillRect(1, 2, 3, 4)
ctx.strokeRect(1, 2, 3, 4)
ctx.strokeSegment(1, 2, 3, 4)
ctx.fillText("abc", 1, 2)
ctx.strokeText("abc", 1, 2)
ctx.translate(3, 4)
ctx.scale(2, 3)
ctx.rotate(0.5)
ctx.save()
ctx.saveLayer()
ctx.restore()

let decoded = decodeBase64($canvas.encodeBase64())
doAssert decoded.width == canvas.width
doAssert decoded.height == canvas.height
doAssert decodeImage(ppm).width == 2
doAssert decodeImageDimensions(ppm).height == 1
doAssert readImage(imagePath).width == 40
doAssert readImageDimensions(imagePath).height == 40
approx(readFont(fontPath).size, 12)
doAssert parsePath("M0 0 L10 0 L10 10 Z").computeBounds(identity).w == 10
try:
  discard parseColor("bad")
  doAssert false
except ValueError as e:
  doAssert "bad" in e.msg

echo "All Pixie Nim tests passed!"
