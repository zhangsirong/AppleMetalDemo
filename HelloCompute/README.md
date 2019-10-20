# Hello Compute

Demonstrates how to perform data-parallel computations using the GPU.

## Overview

In the [Basic Texturing](https://developer.apple.com/documentation/metal/basic_texturing) sample, you learned how to render a 2D image by applying a texture to a single quad.

In this sample, you'll learn how to execute compute-processing workloads in Metal for image processing. In particular, you'll learn how to work with the compute processing pipeline and write kernel functions.

## Getting Started

The Xcode project contains schemes for running the sample on macOS, iOS, or tvOS. Metal is not supported in the iOS or tvOS Simulator, so the iOS and tvOS schemes require a physical device to run the sample. The default scheme is macOS, which runs the sample as is on your Mac.

## General-Purpose GPU Programming

Graphics processing units (GPUs) were originally designed to process large amounts of graphics data, such as vertices or fragments, in a very fast and efficient manner. This design is evident in the GPU hardware architecture itself, which has many processing cores that execute workloads in parallel.

Throughout the history of GPU design, the parallel-processing architecture has remained fairly consistent, but the processing cores have become increasingly programmable. This change enabled GPUs to move away from a fixed-function pipeline toward a programmable pipeline, a change that also enabled general-purpose GPU (GPGPU) programming.

In the GPGPU model, the GPU can be used for any kind of processing task and isn't limited to graphics data. For example, GPUs can be used for cryptography, machine learning, physics, or finance. In Metal, GPGPU workloads are known as compute-processing workloads, or *compute*.

Graphics and compute workloads are not mutually exclusive; Metal  provides a unified framework and language that enables seamless integration of graphics and compute workloads. In fact, this sample demonstrates this integration by:

1. Using a compute pipeline that converts a color image to a grayscale image
2. Using a graphics pipeline that renders the grayscale image to a quad surface

## Create a Compute Processing Pipeline

The compute processing pipeline is made up of only one stage, a programmable kernel function, that executes a compute pass. The kernel function reads from and writes to resources directly, without passing resource data through various pipeline stages.

A `MTLComputePipelineState` object represents a compute processing pipeline. Unlike a graphics rendering pipeline, you can create a `MTLComputePipelineState` object with a single kernel function, without using a pipeline descriptor.

``` objective-c
// Load the kernel function from the library
id<MTLFunction> kernelFunction = [defaultLibrary newFunctionWithName:@"grayscaleKernel"];

// Create a compute pipeline state
_computePipelineState = [_device newComputePipelineStateWithFunction:kernelFunction
                                                               error:&error];
```

## Write a Kernel Function

This sample loads image data into a texture and then uses a kernel function to convert the texture's pixels from color to grayscale. The kernel function processes the pixels independently and concurrently.

- Note: An equivalent algorithm can be written for and executed by the CPU. However, a GPU solution is faster because the texture's pixels don't need to be processed sequentially.

The kernel function in this sample is called `grayscaleKernel` and its signature is shown below:

``` metal
kernel void
grayscaleKernel(texture2d<half, access::read>  inTexture  [[texture(AAPLTextureIndexInput)]],
                texture2d<half, access::write> outTexture [[texture(AAPLTextureIndexOutput)]],
                uint2                          gid         [[thread_position_in_grid]])
```

The function takes the following resource parameters:

* `inTexture`: A read-only, 2D texture that contains the input color pixels.
* `outTexture`: A write-only, 2D texture that stores the output grayscale pixels.

Textures that specify a `read` access qualifier can be read from using the `read()` function. Textures that specify a `write` access qualifier can be written to using the `write()` function.

A kernel function executes once per *thread*, which is analogous to how a vertex function executes once per vertex. Threads are organized into a 3D grid; an encoded compute pass specifies how many threads to process by declaring the size of the grid. Because this sample processes a 2D texture, the threads are arranged in a 2D grid where each thread corresponds to a unique texel.

The kernel function's `gid` parameter uses the ` [[thread_position_in_grid]]` attribute qualifier, which locates a thread within the compute grid. Each execution of the kernel function has a unique `gid` value that enables each thread to work distinctly.

A grayscale pixel has the same value for each of its RGB components. This value can be calculated by simply averaging the RGB components of a color pixel, or by applying certain weights to each component. This sample uses the Rec. 709 luma coefficients for the color-to-grayscale conversion.

``` metal
half4 inColor  = inTexture.read(gid);
half  gray     = dot(inColor.rgb, kRec709Luma);
outTexture.write(half4(gray, gray, gray, 1.0), gid);
```

## Execute a Compute Pass

A `MTLComputeCommandEncoder` object contains the commands for executing a compute pass, including references to the kernel function and its resources. Unlike a render command encoder, you can create a `MTLComputeCommandEncoder` without using a pass descriptor.

``` objective-c
id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];

[computeEncoder setComputePipelineState:_computePipelineState];

[computeEncoder setTexture:_inputTexture
                   atIndex:AAPLTextureIndexInput];

[computeEncoder setTexture:_outputTexture
                   atIndex:AAPLTextureIndexOutput];
```

A compute pass must specify the number of times to execute a kernel function. This number corresponds to the grid size, which is defined in terms of threads and threadgroups. A *threadgroup* is a 3D group of threads that are executed concurrently by a kernel function. In this sample, each thread corresponds to a unique texel, and the grid size must be at least the size of the 2D image. For simplicity, this sample uses a 16 x 16 threadgroup size which is small enough to be used by any GPU. In practice, however, selecting an efficient threadgroup size depends on both the size of the data and the capabilities of a specific device.

``` objective-c
// Set the compute kernel's threadgroup size of 16x16
_threadgroupSize = MTLSizeMake(16, 16, 1);

// Calculate the number of rows and columns of threadgroups given the width of the input image
// Ensure that you cover the entire image (or more) so you process every pixel
_threadgroupCount.width  = (_inputTexture.width  + _threadgroupSize.width -  1) / _threadgroupSize.width;
_threadgroupCount.height = (_inputTexture.height + _threadgroupSize.height - 1) / _threadgroupSize.height;
```

The sample finalizes the compute pass by issuing a dispatch call and ending the encoding of compute commands.

``` objective-c
[computeEncoder dispatchThreadgroups:_threadgroupCount
               threadsPerThreadgroup:_threadgroupSize];

[computeEncoder endEncoding];
```

The sample then continues to encode the rendering commands first introduced in the [Basic Texturing](https://developer.apple.com/documentation/metal/basic_texturing) sample. The commands for the compute pass and the render pass use the same grayscale texture, are appended into the same command buffer, and are submitted to the GPU at the same time. However, the grayscale conversion in the compute pass is always executed before the quad rendering in the render pass.
