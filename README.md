ImageFloat Image Processing Software
========================================================

__Note: the current state of this repository is highly unstable!__

![Interface Screenshot](https://raw.github.com/bajlekov/ImageFloat/master/Screenshot.png)

This is an early development version of an image processing framework and application. The main goals of this project are to provide a flexible way of defining process pipelines, to provide fast feedback and the ability to easily tune parameters, and to provide a broad range of easily extensible operators as building blocks of the processing pipelines.

The first design goal is met by providing a node editor, where each node represents an operation. These nodes can be arbitrarily linked together to form a pipeline for applying the desired effects to images. Currently only a few nodes are implemented, although handling of nodes will improve in the future, and pipeline management should become fluent. Another aim is to reduce the need of matching input and output of operators. To achieve that, inputs are automatically converted to suitable dimensions, be those full RGB image data, a single value or something in between. Furthermore, each operator works in a specified color space. These color space conversions is also performed transparently between operators, increasing efficiency and ease. Throughout the network creation, parameters of the operations are available at all times, providing the ability to tune any part of the pipeline. The current state of node processing is functional, although not finalized yet. Many basic operations such as color space conversions are implemented in software, and can be easily expanded. Most operators are multithreaded, and provide quick preview feedback. Several optimizations are planned, such as improving memory efficiency and decreasing redundant processing.

As more parts become operational, this page will be updated accordingly. Currently, the code is messy and in constant change. Additionally, many loose ends are being tested without being implemented in the main program, or having a place there at all.