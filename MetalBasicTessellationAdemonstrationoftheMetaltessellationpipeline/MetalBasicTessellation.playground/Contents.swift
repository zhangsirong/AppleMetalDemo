/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Playground version of MetalBasicTessellation.
 */

import Cocoa
import Metal
import MetalKit
import PlaygroundSupport

// Setup Metal
let device = MTLCreateSystemDefaultDevice()!
let commandQueue = device.makeCommandQueue()
let mtkView = MTKView(frame: CGRect(x: 0, y: 0, width: 512, height: 512), device: device)
var library: MTLLibrary?
do {
    let path = Bundle.main.path(forResource: "TessellationFunctions", ofType: "metal")
    let source = try String(contentsOfFile: path!, encoding: .utf8)
    library = try device.makeLibrary(source: source, options: nil)
} catch let error as NSError {
    print("library error: " + error.description)
}

// Setup Compute Pipeline
let kernelFunction = library?.makeFunction(name: "tessellation_kernel_triangle")
var computePipeline: MTLComputePipelineState?
do {
    computePipeline = try device.makeComputePipelineState(function: kernelFunction!)
} catch let error as NSError {
    print("compute pipeline error: " + error.description)
}

// Setup Vertex Descriptor
let vertexDescriptor = MTLVertexDescriptor()
vertexDescriptor.attributes[0].format = .float4;
vertexDescriptor.attributes[0].offset = 0;
vertexDescriptor.attributes[0].bufferIndex = 0;
vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint;
vertexDescriptor.layouts[0].stepRate = 1;
vertexDescriptor.layouts[0].stride = 4*MemoryLayout<Float>.size;

// Setup Render Pipeline
let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
renderPipelineDescriptor.fragmentFunction = library?.makeFunction(name: "tessellation_fragment")
renderPipelineDescriptor.isTessellationFactorScaleEnabled = false
renderPipelineDescriptor.tessellationFactorFormat = .half
renderPipelineDescriptor.tessellationControlPointIndexType = .none
renderPipelineDescriptor.tessellationFactorStepFunction = .constant
renderPipelineDescriptor.tessellationOutputWindingOrder = .clockwise
renderPipelineDescriptor.tessellationPartitionMode = .fractionalEven
renderPipelineDescriptor.maxTessellationFactor = 64;
renderPipelineDescriptor.vertexFunction = library?.makeFunction(name: "tessellation_vertex_triangle")
var renderPipeline: MTLRenderPipelineState?
do {
    renderPipeline = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
} catch let error as NSError {
    print("render pipeline error: " + error.description)
    
}

// Setup Buffers
let tessellationFactorsBuffer = device.makeBuffer(length: 256, options: MTLResourceOptions.storageModePrivate)
let controlPointPositions: [Float] = [
    -0.8, -0.8, 0.0, 1.0,   // lower-left
     0.0,  0.8, 0.0, 1.0,   // upper-middle
     0.8, -0.8, 0.0, 1.0,   // lower-right
]
let controlPointsBuffer = device.makeBuffer(bytes: controlPointPositions, length:256 , options: [])

// Tessellation Pass
let commandBuffer = commandQueue.makeCommandBuffer()

let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
computeCommandEncoder.setComputePipelineState(computePipeline!)
let edgeFactor: [Float] = [16.0]
let insideFactor: [Float] = [8.0]
computeCommandEncoder.setBytes(edgeFactor, length: MemoryLayout<Float>.size, at: 0)
computeCommandEncoder.setBytes(insideFactor, length: MemoryLayout<Float>.size, at: 1)
computeCommandEncoder.setBuffer(tessellationFactorsBuffer, offset: 0, at: 2)
computeCommandEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
computeCommandEncoder.endEncoding()

let renderPassDescriptor = mtkView.currentRenderPassDescriptor
let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
renderCommandEncoder.setRenderPipelineState(renderPipeline!)
renderCommandEncoder.setVertexBuffer(controlPointsBuffer, offset: 0, at: 0)
renderCommandEncoder.setTriangleFillMode(.lines)
renderCommandEncoder.setTessellationFactorBuffer(tessellationFactorsBuffer, offset: 0, instanceStride: 0)
renderCommandEncoder.drawPatches(numberOfPatchControlPoints: 3, patchStart: 0, patchCount: 1, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)
renderCommandEncoder.endEncoding()

commandBuffer.present(mtkView.currentDrawable!)
commandBuffer.commit()
commandBuffer.waitUntilCompleted()

// Display Tessellated Content
PlaygroundPage.current.liveView = mtkView
