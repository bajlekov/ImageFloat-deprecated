-- handle functions for:
--		library names
--		general params
-- 		etc...

return {
	windowSize = {1280, 600},
	numThreads = 4,
	bufferPrecision = {"double",8},
	
	imageLoadType = "PPM", -- PPM / IM / RAW / FPM
	imageLoadParams = "",
	imageLoadName = "img.ppm",
	imageLoadPath = "../Resources/Photos/",

	--NYI
	imageSaveType = "PPM", -- PPM / IM / FPM
	imageSaveParams = "",
	imageSaveName = "out.ppm",
	imageSavePath = "../Resources/Photos/",

	--Paths
	threadPath = "./Threads/threadFunc.lua",
	--threadPath = "./Thread.lua",
	libPath = nil,
	imgPath = "../Resources/Images/",
	ttfPath = "../Resources/Fonts/",
	incPath = "./Include/",

	--library names
}
