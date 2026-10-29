/**
 * Creates a coordinate viewport for converting between math world and Excalidraw screen coordinates.
 */
export function createViewport(width = 800, height = 600, centerX = 0, centerY = 0, scale = 40) {
  const originSx = width / 2;
  const originSy = height / 2;

  const toScreen = (x, y) => ({
    sx: originSx + (x - centerX) * scale,
    sy: originSy - (y - centerY) * scale,
  });

  const toMath = (sx, sy) => ({
    x: centerX + (sx - originSx) / scale,
    y: centerY - (sy - originSy) / scale,
  });

  const getVisibleRange = () => {
    const topLeft = toMath(0, 0);
    const bottomRight = toMath(width, height);
    return {
      minX: topLeft.x,
      maxX: bottomRight.x,
      minY: bottomRight.y,
      maxY: topLeft.y,
    };
  };

  const getNiceStep = () => {
    // We want tick spacing in pixels to be ~40-100 px
    const targetMathDist = 60 / scale;
    const exponent = Math.floor(Math.log10(targetMathDist));
    const fraction = targetMathDist / Math.pow(10, exponent);

    let niceFrac = 1;
    if (fraction > 1.5 && fraction <= 3.5) niceFrac = 2;
    else if (fraction > 3.5 && fraction <= 7.5) niceFrac = 5;
    else if (fraction > 7.5) niceFrac = 10;

    return niceFrac * Math.pow(10, exponent);
  };

  return {
    width,
    height,
    centerX,
    centerY,
    scale,
    toScreen,
    toMath,
    getVisibleRange,
    getNiceStep,
  };
}

