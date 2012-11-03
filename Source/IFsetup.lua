-- handle functions for:
--		library names
--		general params
-- 		etc...

return {
	windowSize = {1280, 600},
	numThreads = 4,
	
	imageLoadType = "PPM", -- PPM / IM / RAW / FPM
	imageLoadParams = "",
	imageLoadName = "../Resources/Photos/img16.ppm",

	--NYI
	imageSaveType = "PPM", -- PPM / IM / FPM
	imageSaveParams = "",
	imageSaveName = "../Resources/Photos/out.ppm",

	--Paths
	threadPath = "./Threads/threadFunc.lua",
	libPath = nil,
	imgPath = "../Resources/Images/",
	ttfPath = "../Resources/Fonts/",

	--library names
}
