#!/bin/bash

cp squishyMain squishy
squish --minify-level=basic
rm squishy
cp squishyThread squishy
squish --minify-level=basic
rm squishy

luajit -b ImageFloat.lua ImageFloat
luajit -b Thread.lua Thread

cp ImageFloat Dist/ImageFloat
cp Thread Dist/Thread

cp IFsetup.lua Dist/IFsetup.lua
