import os, strformat, strutils
import pixie

const
  renderOutputDir = "tests" / "generated" / "pixie_images"
  goldenDir = "tests" / "goldens"
  maxChannelDelta = 0.02'f32
  maxAvgDelta = 0.002'f64

proc fail(message: string) =
  stderr.writeLine(message)
  quit(1)

proc recordDelta(delta: float32; totalDelta: var float64; maxDelta: var float32) =
  totalDelta += delta.float64
  if delta > maxDelta:
    maxDelta = delta

proc compareImages(actualPath, goldenPath: string) =
  if not fileExists(goldenPath):
    fail(&"missing golden image for {actualPath}: {goldenPath}")

  let
    actual = readImage(actualPath)
    golden = readImage(goldenPath)

  if actual.width != golden.width or actual.height != golden.height:
    fail(&"{actualPath} dimensions {actual.width}x{actual.height} differ from {goldenPath} {golden.width}x{golden.height}")

  var
    totalDelta = 0'f64
    maxDelta = 0'f32
  for y in 0 ..< actual.height:
    for x in 0 ..< actual.width:
      let
        actualColor = actual.getColor(x, y)
        goldenColor = golden.getColor(x, y)
      recordDelta(abs(actualColor.r - goldenColor.r), totalDelta, maxDelta)
      recordDelta(abs(actualColor.g - goldenColor.g), totalDelta, maxDelta)
      recordDelta(abs(actualColor.b - goldenColor.b), totalDelta, maxDelta)
      recordDelta(abs(actualColor.a - goldenColor.a), totalDelta, maxDelta)

  let avgDelta = totalDelta / float64(actual.width * actual.height * 4)
  if maxDelta > maxChannelDelta or avgDelta > maxAvgDelta:
    fail(&"{actualPath} differs from {goldenPath}: max delta {maxDelta}, avg delta {avgDelta}")

proc goldenFor(actualPath: string): string =
  let filename = actualPath.extractFilename()
  if not filename.endsWith(".png"):
    fail(&"not a PNG render output: {actualPath}")

  let stepStart = filename.rfind("_step")
  if stepStart < 0:
    fail(&"render output does not include a _step suffix: {actualPath}")

  let step = filename[stepStart + 1 .. filename.len - ".png".len - 1]
  result = goldenDir / ("pixie_render_" & step & ".png")

if not dirExists(renderOutputDir):
  fail(&"missing Pixie render output directory: {renderOutputDir}")

var checked = 0
for actualPath in walkFiles(renderOutputDir / "*.png"):
  compareImages(actualPath, goldenFor(actualPath))
  inc checked

if checked == 0:
  fail(&"no Pixie render output images found in {renderOutputDir}")

echo &"Pixie render gold diff passed for {checked} image(s)."
