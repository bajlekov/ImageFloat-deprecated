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
	imageLoadPath = "../",
	
	imageSaveType = "PPM", -- PPM / IM / FPM
	imageSaveParams = "",
	imageSaveName = "out.ppm",
	imageSavePath = "../",
	
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
			fuseOps	= false,	-- fuse functional ops together in a single loop
			fuseCS	= false,	-- fuse CS ops with getters/setters on in/output
			cacheCS	= false,	-- set cache points containing all CS
	},
	optCache	= {
			cache	= false,	-- keep intermediate results in ram
			disk	= false,	-- keep buffers on disk for huge files (set limit)
			tiled	= false,	-- tiled processing -> whenever possible
			
			pack	= false,	-- "float16"/"int16"/"int8"/"32bit RGBE" -> c-code for float<>half conversion!
			compr	= false,	-- enable buffer compression -> external lib?
	},
	optCalc		= {
			memoize	= false,	-- tables of 16/18/20/22/24 bits -> out of range still handled correctly
			linear	= true,		-- linear or step interpolation
			approx	= false,	-- approximate functions by taylor/remez/polynomial
	},
	optDraw		= {
			fast	= false,	-- use faster line and text drawing
			hist	= true,		-- histogram update on preview?
			
			preview	= 4,		-- preview downsampling
			filter	= false,	-- change interpolation filter for a faster one during preview (NN or even floor)
	},
	
	--library names
}
