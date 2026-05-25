const assert = require('assert');
const Module = require('module');
const path = require('path');

process.env.NODE_PATH = [path.join(__dirname, 'node_modules'), process.env.NODE_PATH]
  .filter(Boolean)
  .join(path.delimiter);
Module._initPaths();

const pixieRoot = path.resolve(process.env.PIXIE_ROOT || path.join(__dirname, '..', '..', 'pixie'));
const bindingsDir = path.resolve(process.env.PIXIE_BINDINGS_DIR || path.join(pixieRoot, 'bindings', 'generated'));
const pixie = require(path.join(bindingsDir, 'pixie.js'));

function asset(...parts) {
  return path.join(pixieRoot, ...parts);
}

function approx(value, expected, eps = 0.0001) {
  assert(Math.abs(value - expected) <= eps, `expected ${expected}, got ${value}`);
}

function assertColor(actual, expected) {
  approx(actual.r, expected.r);
  approx(actual.g, expected.g);
  approx(actual.b, expected.b);
  approx(actual.a, expected.a);
}

const fontPath = asset('tests', 'fonts', 'Inter-Regular.ttf');
const imagePath = asset('tests', 'images', 'turtle.png');
const ppm = 'P3\n2 1\n255\n255 0 0 0 255 0\n';

assert.strictEqual(pixie.DEFAULT_MITER_LIMIT, 4);
assert.strictEqual(pixie.AUTO_LINE_HEIGHT, -1);
assert.strictEqual(pixie.PNG_FORMAT, 0);
assert.strictEqual(pixie.LINEAR_GRADIENT_PAINT, 3);

const red = pixie.parseColor('#ff0000');
const green = pixie.parseColor('#00ff00');
const mixed = pixie.mix(red, green, 0.25);
approx(mixed.r, 0.75);
approx(mixed.g, 0.25);

const mat = pixie.translate(3, 4);
const identity = pixie.translate(0, 0);
assert.strictEqual(mat.values[6], 3);
assert.strictEqual(pixie.inverse(mat).values[6], -3);
assert.deepStrictEqual(pixie.snapToPixels(pixie.rect(1, 2, 3, 4)), pixie.rect(1, 2, 3, 4));
assert(pixie.miterLimitToAngle(2) > 0);
assert(pixie.angleToMiterLimit(1) > 0);

const dashes = pixie.newSeqFloat32();
dashes.add(1.5);
dashes.add(2.5);
dashes.set(1, 3.5);
assert.strictEqual(dashes.length(), 2);
approx(dashes.get(1), 3.5);

const image = pixie.newImage(4, 3);
assert.strictEqual(image.width, 4);
assert.strictEqual(image.height, 3);
assert(image.encodeBase64().length > 20);
image.fill(red);
assert(image.isOneColor());
assert(image.isOpaque());
assertColor(image.getColor(1, 1), red);
image.setColor(0, 0, green);
assert(!image.isOneColor());
assert.strictEqual(image.copy().width, image.width);

const solid = pixie.newPaint(pixie.SOLID_PAINT);
solid.color = red;
image.paintFill(solid);
image.applyOpacity(0.5);
approx(image.getColor(0, 0).a, 0.5, 0.01);
image.invert();
image.blur(1, red);

const resized = image.resize(6, 5);
assert.strictEqual(resized.width, 6);
assert.strictEqual(resized.height, 5);
resized.rotate90();
assert.strictEqual(resized.width, 5);
assert.strictEqual(resized.height, 6);
assert.strictEqual(resized.subImage(0, 0, 2, 2).width, 2);
assert.strictEqual(resized.rectSubImage(pixie.rect(0, 0, 1, 1)).height, 1);
assert.strictEqual(resized.shadow(pixie.vector2(1, 2), 3, 4, red).width, resized.width);
assert.strictEqual(resized.superImage(-1, -1, resized.width + 2, resized.height + 2).width, resized.width + 2);
assert(resized.opaqueBounds().w > 0);

const paint = pixie.newPaint(pixie.SOLID_PAINT);
paint.kind = pixie.LINEAR_GRADIENT_PAINT;
paint.blendMode = pixie.MULTIPLY_BLEND;
paint.opacity = 0.5;
paint.color = green;
paint.imageMat = pixie.scale(2, 3);
assert.strictEqual(paint.kind, pixie.LINEAR_GRADIENT_PAINT);
approx(paint.opacity, 0.5);
paint.gradientHandlePositions.add(pixie.vector2(0.25, 0));
paint.gradientHandlePositions.add(pixie.vector2(0.75, 1));
paint.gradientHandlePositions.set(1, pixie.vector2(0.8, 1));
assert.strictEqual(paint.gradientHandlePositions.length(), 2);
approx(paint.gradientHandlePositions.get(1).x, 0.8);
paint.gradientStops.add(pixie.colorStop(red, 0));
paint.gradientStops.add(pixie.colorStop(green, 1));
assert.strictEqual(paint.gradientStops.length(), 2);
assertColor(paint.gradientStops.get(1).color, green);

const pathShape = pixie.newPath();
pathShape.moveTo(1, 1);
pathShape.lineTo(2, 2);
pathShape.bezierCurveTo(1, 2, 3, 4, 5, 6);
pathShape.quadraticCurveTo(1, 2, 3, 4);
pathShape.ellipticalArcTo(1, 2, 3, false, true, 4, 5);
pathShape.arc(1, 2, 3, 0, 1, false);
pathShape.arcTo(1, 2, 3, 4, 5);
pathShape.rect(0, 0, 3, 4, true);
pathShape.roundedRect(0, 0, 3, 4, 1, 1, 1, 1, true);
pathShape.ellipse(1, 2, 3, 4);
pathShape.circle(1, 2, 3);
pathShape.polygon(1, 2, 3, 5);
pathShape.closePath();
assert(pathShape.computeBounds(identity).w > 0);

const rectPath = pixie.newPath();
rectPath.rect(0, 0, 10, 10, true);
const solidDashes = pixie.newSeqFloat32();
assert(rectPath.fillOverlaps(pixie.vector2(5, 5), identity, pixie.NON_ZERO));
assert(rectPath.strokeOverlaps(pixie.vector2(0, 5), identity, 2, pixie.BUTT_CAP, pixie.MITER_JOIN, pixie.DEFAULT_MITER_LIMIT, solidDashes));

const typeface = pixie.readTypeface(fontPath);
assert(typeface.filePath.endsWith('Inter-Regular.ttf'));
typeface.filePath = fontPath;
assert(typeface.hasGlyph('A'));
assert(typeface.getAdvance('A') > 0);
assert(typeface.getGlyphPath('A').computeBounds(identity).w > 0);
assert.throws(() => typeface.hasGlyph('AB'), assert.AssertionError);
assert.throws(() => typeface.hasGlyph('\uD800'), assert.AssertionError);

const font = typeface.newFont();
font.size = 24;
font.lineHeight = pixie.AUTO_LINE_HEIGHT;
font.paint = solid;
font.textCase = pixie.UPPER_CASE;
font.underline = true;
font.strikethrough = true;
font.noKerningAdjustments = true;
font.paints.add(solid);
assert(font.paints.length() >= 1);
assert(font.scale() > 0);
assert(font.defaultLineHeight() > 0);
assert(font.layoutBounds('abcd').x > 0);
assert(font.typeset('abcd', pixie.vector2(100, 100), pixie.LEFT_ALIGN, pixie.TOP_ALIGN, true).layoutBounds().x > 0);

const span = pixie.newSpan('hi', font);
span.text = 'hello';
const spans = pixie.newSeqSpan();
spans.add(span);
const arrangement = spans.typeset(pixie.vector2(100, 100), pixie.CENTER_ALIGN, pixie.BOTTOM_ALIGN, true);
assert.strictEqual(spans.get(0).text, 'hello');
assert(arrangement.layoutBounds().x > 0);
assert(spans.layoutBounds().y > 0);
assert(arrangement.computeBounds(mat).x > 0);

const canvas = pixie.newImage(64, 64);
canvas.fill(pixie.parseColor('#ffffff'));
canvas.fillText(font, 'abc', mat, pixie.vector2(60, 60), pixie.LEFT_ALIGN, pixie.TOP_ALIGN);
canvas.arrangementFillText(arrangement, mat);
canvas.strokeText(font, 'abc', mat, 2, pixie.vector2(60, 60), pixie.LEFT_ALIGN, pixie.TOP_ALIGN, pixie.BUTT_CAP, pixie.MITER_JOIN, pixie.DEFAULT_MITER_LIMIT, dashes);
canvas.arrangementStrokeText(arrangement, mat, 2, pixie.BUTT_CAP, pixie.MITER_JOIN, pixie.DEFAULT_MITER_LIMIT, dashes);
canvas.fillPath(rectPath, solid, mat, pixie.NON_ZERO);
canvas.strokePath(rectPath, solid, mat, 2, pixie.BUTT_CAP, pixie.MITER_JOIN, pixie.DEFAULT_MITER_LIMIT, dashes);

const ctx = pixie.newContext(80, 80);
ctx.globalAlpha = 0.75;
ctx.lineWidth = 2;
ctx.miterLimit = 5;
ctx.lineCap = pixie.ROUND_CAP;
ctx.lineJoin = pixie.BEVEL_JOIN;
ctx.font = fontPath;
ctx.fontSize = 24;
ctx.textAlign = pixie.RIGHT_ALIGN;
assert.strictEqual(ctx.textAlign, pixie.RIGHT_ALIGN);
assert(ctx.measureText('abcd').width > 0);
ctx.setTransform(mat);
assert.strictEqual(ctx.getTransform().values[6], 3);
ctx.transform(pixie.scale(2, 2));
ctx.resetTransform();
ctx.setLineDash(solidDashes);
ctx.beginPath();
ctx.rect(0, 0, 10, 10);
assert(ctx.isPointInPath(5, 5, pixie.NON_ZERO));
assert(ctx.pathIsPointInPath(rectPath, 5, 5, pixie.NON_ZERO));
assert(ctx.isPointInStroke(0, 5));
assert(ctx.pathIsPointInStroke(rectPath, 0, 5));
ctx.setLineDash(dashes);
assert.strictEqual(ctx.getLineDash().length(), 2);
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
ctx.fill(pixie.NON_ZERO);
ctx.pathFill(rectPath, pixie.EVEN_ODD);
ctx.clip(pixie.NON_ZERO);
ctx.pathClip(rectPath, pixie.EVEN_ODD);
ctx.stroke();
ctx.pathStroke(rectPath);
ctx.drawImage(canvas, 1, 2);
ctx.drawImage2(canvas, 1, 2, 3, 4);
ctx.drawImage3(canvas, 1, 2, 3, 4, 5, 6, 7, 8);
ctx.clearRect(1, 2, 3, 4);
ctx.fillRect(1, 2, 3, 4);
ctx.strokeRect(1, 2, 3, 4);
ctx.strokeSegment(1, 2, 3, 4);
ctx.fillText('abc', 1, 2);
ctx.strokeText('abc', 1, 2);
ctx.translate(3, 4);
ctx.scale(2, 3);
ctx.rotate(0.5);
ctx.save();
ctx.saveLayer();
ctx.restore();

const decoded = pixie.decodeBase64(canvas.encodeBase64());
assert.strictEqual(decoded.width, canvas.width);
assert.strictEqual(decoded.height, canvas.height);
assert.strictEqual(pixie.decodeImage(ppm).width, 2);
assert.strictEqual(pixie.decodeImageDimensions(ppm).height, 1);
assert.strictEqual(pixie.readImage(imagePath).width, 40);
assert.strictEqual(pixie.readImageDimensions(imagePath).height, 40);
assert.strictEqual(pixie.readFont(fontPath).size, 12);
assert.strictEqual(pixie.parsePath('M0 0 L10 0 L10 10 Z').computeBounds(identity).w, 10);
pixie.parseColor('bad');
assert(pixie.checkError());
assert(pixie.takeError().includes('bad'));

console.log('All Pixie Node tests passed!');
