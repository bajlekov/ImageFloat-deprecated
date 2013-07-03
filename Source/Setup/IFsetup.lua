-- handle functions for:
--		library names
--		general params
-- 		etc...

return {
	windowSize = {1280, 600},
	numThreads = 8,
	bufferPrecision = {"float",4}, -- {"float", 4} or {"double", 8}
	
	imageLoadType = "PPM", -- PPM / IM / RAW / FPM
	imageLoadParams = "",
	imageLoadName = "img.ppm",
	imageLoadPath = "../Resources/Photos/",
	
	imageSaveType = "PPM", -- PPM / IM / FPM
	imageSaveParams = "",
	imageSaveName = "out.ppm",
	imageSavePath = "../Resources/Photos/",
	
	--Paths
	threadPath = "./Threads/threadFunc.lua",
	libPath = nil,
	imgPath = "../Resources/Images/",
	ttfPath = "../Resources/Fonts/",
	incPath = "./Include/",
	
	--optimizations
	optRecompile = false,
	optCompile	= {
			c	= false,
			sse	= false,
			ispc	= false,
			glsl	= false,
	},
	optNode		= {
			fuseOps	= false,
			fuseCS	= false,
			memoize	= false,
			cacheCS	= false,
	},
	optCache	= {
			disk	= false,
			tiled	= false,
			pack	= false,	-- "float16"/"int16"/"int8"
			compr	= false,	-- enable buffer compression
	},
	
	fastDraw = true, -- use faster line and text drawing
	
	--library names
}
