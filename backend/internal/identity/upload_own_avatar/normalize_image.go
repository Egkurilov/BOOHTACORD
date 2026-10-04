package uploadownavatar

import (
	"image"
	"image/color"
	"math"
)

// centerCropResize makes every stored avatar a centered square 128px PNG.
func centerCropResize(source image.Image, dimension int) *image.RGBA {
	bounds := source.Bounds()
	width, height := bounds.Dx(), bounds.Dy()
	side := min(width, height)
	left := bounds.Min.X + (width-side)/2
	top := bounds.Min.Y + (height-side)/2
	result := image.NewRGBA(image.Rect(0, 0, dimension, dimension))

	for y := 0; y < dimension; y++ {
		sourceY := float64(top) + (float64(y)+0.5)*float64(side)/float64(dimension) - 0.5
		for x := 0; x < dimension; x++ {
			sourceX := float64(left) + (float64(x)+0.5)*float64(side)/float64(dimension) - 0.5
			result.SetRGBA(x, y, sampleBilinear(source, sourceX, sourceY))
		}
	}
	return result
}

func sampleBilinear(source image.Image, x, y float64) color.RGBA {
	bounds := source.Bounds()
	minX, minY := bounds.Min.X, bounds.Min.Y
	maxX, maxY := bounds.Max.X-1, bounds.Max.Y-1
	x = max(float64(minX), min(float64(maxX), x))
	y = max(float64(minY), min(float64(maxY), y))
	x0, y0 := int(math.Floor(x)), int(math.Floor(y))
	x1, y1 := min(x0+1, maxX), min(y0+1, maxY)
	fx, fy := x-float64(x0), y-float64(y0)

	topLeft := color.RGBAModel.Convert(source.At(x0, y0)).(color.RGBA)
	topRight := color.RGBAModel.Convert(source.At(x1, y0)).(color.RGBA)
	bottomLeft := color.RGBAModel.Convert(source.At(x0, y1)).(color.RGBA)
	bottomRight := color.RGBAModel.Convert(source.At(x1, y1)).(color.RGBA)

	return color.RGBA{
		R: interpolate(topLeft.R, topRight.R, bottomLeft.R, bottomRight.R, fx, fy),
		G: interpolate(topLeft.G, topRight.G, bottomLeft.G, bottomRight.G, fx, fy),
		B: interpolate(topLeft.B, topRight.B, bottomLeft.B, bottomRight.B, fx, fy),
		A: interpolate(topLeft.A, topRight.A, bottomLeft.A, bottomRight.A, fx, fy),
	}
}

func interpolate(topLeft, topRight, bottomLeft, bottomRight uint8, fx, fy float64) uint8 {
	top := float64(topLeft)*(1-fx) + float64(topRight)*fx
	bottom := float64(bottomLeft)*(1-fx) + float64(bottomRight)*fx
	return uint8(math.Round(top*(1-fy) + bottom*fy))
}
