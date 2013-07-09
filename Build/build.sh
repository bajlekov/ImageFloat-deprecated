#!/bin/bash

cp squishyMain squishy
./squish --minify-level=basic
rm squishy
cp squishyThread squishy
./squish --minify-level=basic
rm squishy

#luajit -b ImageFloat.lua ImageFloat
#luajit -b Thread.lua Thread
cp ImageFloat.lua ImageFloat
cp Thread.lua Thread

cp ImageFloat ../Distribution/ImageFloat
cp Thread ../Distribution/Thread