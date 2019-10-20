/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Tessellation Pipeline for MetalBasicTessellation.
            The exposed properties are user-defined via the ViewController UI elements.
            The compute pipelines are built with a compute kernel (one for triangle patches; one for quad patches).
            The render pipelines are built with a post-tessellation vertex function (one for triangle patches; one for quad patches) and a fragment function. The render pipeline descriptor also configures tessellation-specific properties.
            The tessellation factors buffer is dynamically populated by the compute kernel.
            The control points buffer is populated with static position data.
 */

#include <TargetConditionals.h>
#import "AAPLTessellationPipeline.h"

@implementation AAPLTessellationPipeline
{
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;
    id <MTLLibrary> _library;
    
    id <MTLComputePipelineState> _computePipelineTriangle;
    id <MTLComputePipelineState> _computePipelineQuad;
    id <MTLRenderPipelineState> _renderPipelineTriangle;
    id <MTLRenderPipelineState> _renderPipelineQuad;
    
    id <MTLBuffer> _tessellationFactorsBuffer;
    id <MTLBuffer> _controlPointsBufferTriangle;
    id <MTLBuffer> _controlPointsBufferQuad;
}

- (nullable instancetype)initWithMTKView:(nonnull MTKView *)view
{
    self = [super init];
    if(self)
    {
        // Initialize properties
        _wireframe = YES;
        _patchType = MTLPatchTypeTriangle;
        _edgeFactor = 2.0;
        _insideFactor = 2.0;
        
        // Setup Metal
        if(![self didSetupMetal]) {
            return nil;
        }
        
        // Assign device and delegate to MTKView
        view.device = _device;
        view.delegate = self;
        
        // Setup compute pipelines
        if(![self didSetupComputePipelines]) {
            return nil;
        }
        
        // Setup render pipelines
        if(![self didSetupRenderPipelinesWithMTKView:view]) {
            return nil;
        }
        
        // Setup Buffers
        [self setupBuffers];
    }
    return self;
}

#pragma mark Setup methods

- (BOOL)didSetupMetal
{
    // Use the default device
    _device = MTLCreateSystemDefaultDevice();
    if(!_device) {
        NSLog(@"Metal is not supported on this device");
        return NO;
    }
    
#if TARGET_OS_IOS
    if(![_device supportsFeatureSet:MTLFeatureSet_iOS_GPUFamily3_v2]) {
        NSLog(@"Tessellation is not supported on this device");
        return NO;
    }
#elif TARGET_OS_OSX
    if(![_device supportsFeatureSet:MTLFeatureSet_OSX_GPUFamily1_v1]) {
        NSLog(@"Tessellation is not supported on this device");
        return NO;
    }
#endif
    
    // Create a new command queue
    _commandQueue = [_device newCommandQueue];
    
    // Load the default library
    _library = [_device newDefaultLibrary];
    
    return YES;
}

- (BOOL)didSetupComputePipelines
{
    NSError* computePipelineError;
    
    // Create compute pipeline for triangle-based tessellation
    id <MTLFunction> kernelFunctionTriangle = [_library newFunctionWithName:@"tessellation_kernel_triangle"];
    _computePipelineTriangle = [_device newComputePipelineStateWithFunction:kernelFunctionTriangle
                                                                      error:&computePipelineError];
    if(!_computePipelineTriangle) {
        NSLog(@"Failed to create compute pipeline (TRIANGLE), error: %@", computePipelineError);
        return NO;
    }
    
    // Create compute pipeline for quad-based tessellation
    id <MTLFunction> kernelFunctionQuad = [_library newFunctionWithName:@"tessellation_kernel_quad"];
    _computePipelineQuad = [_device newComputePipelineStateWithFunction:kernelFunctionQuad
                                                                  error:&computePipelineError];
    if(!_computePipelineQuad) {
        NSLog(@"Failed to create compute pipeline (QUAD), error: %@", computePipelineError);
        return NO;
    }
    
    return YES;
}

- (BOOL)didSetupRenderPipelinesWithMTKView:(nonnull MTKView *)view
{
    NSError *renderPipelineError = nil;
    
    // Create a reusable vertex descriptor for the control point data
    // This describes the inputs to the post-tessellation vertex function, declared with the 'stage_in' qualifier
    MTLVertexDescriptor* vertexDescriptor = [MTLVertexDescriptor vertexDescriptor];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerPatchControlPoint;
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stride = 4.0*sizeof(float);
    
    // Create a reusable render pipeline descriptor
    MTLRenderPipelineDescriptor *renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    
    // Configure common render properties
    renderPipelineDescriptor.vertexDescriptor = vertexDescriptor;
    renderPipelineDescriptor.sampleCount = view.sampleCount;
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    renderPipelineDescriptor.fragmentFunction = [_library newFunctionWithName:@"tessellation_fragment"];
    
    // Configure common tessellation properties
    renderPipelineDescriptor.tessellationFactorScaleEnabled = NO;
    renderPipelineDescriptor.tessellationFactorFormat = MTLTessellationFactorFormatHalf;
    renderPipelineDescriptor.tessellationControlPointIndexType = MTLTessellationControlPointIndexTypeNone;
    renderPipelineDescriptor.tessellationFactorStepFunction = MTLTessellationFactorStepFunctionConstant;
    renderPipelineDescriptor.tessellationOutputWindingOrder = MTLWindingClockwise;
    renderPipelineDescriptor.tessellationPartitionMode = MTLTessellationPartitionModeFractionalEven;
#if TARGET_OS_IOS
    // In iOS, the maximum tessellation factor is 16
    renderPipelineDescriptor.maxTessellationFactor = 16;
#elif TARGET_OS_OSX
    // In OS X, the maximum tessellation factor is 64
    renderPipelineDescriptor.maxTessellationFactor = 64;
#endif
    
    // Create render pipeline for triangle-based tessellation
    renderPipelineDescriptor.vertexFunction = [_library newFunctionWithName:@"tessellation_vertex_triangle"];
    _renderPipelineTriangle = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor
                                                                      error:&renderPipelineError];
    if(!_renderPipelineTriangle){
        NSLog(@"Failed to create render pipeline (TRIANGLE), error %@", renderPipelineError);
        return NO;
    }
    
    // Create render pipeline for quad-based tessellation
    renderPipelineDescriptor.vertexFunction = [_library newFunctionWithName:@"tessellation_vertex_quad"];
    _renderPipelineQuad = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor
                                                                  error:&renderPipelineError];
    if (!_renderPipelineQuad) {
        NSLog(@"Failed to create render pipeline state (QUAD), error %@", renderPipelineError);
        return NO;
    }
    
    return YES;
}

- (void)setupBuffers
{
    // Allocate memory for the tessellation factors buffer
    // This is a private buffer whose contents are later populated by the GPU (compute kernel)
    _tessellationFactorsBuffer = [_device newBufferWithLength:256
                                               options:MTLResourceStorageModePrivate];
    _tessellationFactorsBuffer.label = @"Tessellation Factors";
    
    // Allocate memory for the control points buffers
    // These are shared or managed buffers whose contents are immediately populated by the CPU
    MTLResourceOptions controlPointsBufferOptions;
#if TARGET_OS_IOS
    // In iOS, the storage mode can only be shared
    controlPointsBufferOptions = MTLResourceStorageModeShared;
#elif TARGET_OS_OSX
    // In OS X, the storage mode can be shared or managed, but managed may yield better performance
    controlPointsBufferOptions = MTLResourceStorageModeManaged;
#endif
    
    static const float controlPointPositionsTriangle[] = {
        -0.8, -0.8, 0.0, 1.0,   // lower-left
         0.0,  0.8, 0.0, 1.0,   // upper-middle
         0.8, -0.8, 0.0, 1.0,   // lower-right
    };
    _controlPointsBufferTriangle = [_device newBufferWithBytes:controlPointPositionsTriangle
                                                        length:sizeof(controlPointPositionsTriangle)
                                                       options:controlPointsBufferOptions];
    _controlPointsBufferTriangle.label = @"Control Points Triangle";
    
    static const float controlPointPositionsQuad[] = {
        -0.8,  0.8, 0.0, 1.0,   // upper-left
         0.8,  0.8, 0.0, 1.0,   // upper-right
         0.8, -0.8, 0.0, 1.0,   // lower-right
        -0.8, -0.8, 0.0, 1.0,   // lower-left
    };
    _controlPointsBufferQuad = [_device newBufferWithBytes:controlPointPositionsQuad
                                                    length:sizeof(controlPointPositionsQuad)
                                                   options:controlPointsBufferOptions];
    _controlPointsBufferQuad.label = @"Control Points Quad";
    
    // More sophisticated tessellation passes might have additional buffers for per-patch user data
}

#pragma mark Compute/Render methods

- (void)computeTessellationFactorsWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    // Create a compute command encoder
    id <MTLComputeCommandEncoder> computeCommandEncoder = [commandBuffer computeCommandEncoder];
    computeCommandEncoder.label = @"Compute Command Encoder";
    
    // Begin encoding compute commands
    [computeCommandEncoder pushDebugGroup:@"Compute Tessellation Factors"];
    
    // Set the correct compute pipeline
    if(self.patchType == MTLPatchTypeTriangle) {
        [computeCommandEncoder setComputePipelineState:_computePipelineTriangle];
    } else if(self.patchType == MTLPatchTypeQuad) {
        [computeCommandEncoder setComputePipelineState:_computePipelineQuad];
    }
    
    // Bind the user-selected edge and inside factor values to the compute kernel
    [computeCommandEncoder setBytes:&_edgeFactor length:sizeof(float) atIndex:0];
    [computeCommandEncoder setBytes:&_insideFactor length:sizeof(float) atIndex:1];
    
    // Bind the tessellation factors buffer to the compute kernel
    [computeCommandEncoder setBuffer:_tessellationFactorsBuffer offset:0 atIndex:2];
    
    // Dispatch threadgroups
    [computeCommandEncoder dispatchThreadgroups:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
    
    // All compute commands have been encoded
    [computeCommandEncoder popDebugGroup];
    [computeCommandEncoder endEncoding];
}

- (void)tessellateAndRenderInMTKView:(nonnull MTKView *)view withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    // Obtain a renderPassDescriptor generated from the view's drawable
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    
    // If the renderPassDescriptor is valid, begin the commands to render into its drawable
    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder
        id <MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderCommandEncoder.label = @"Render Command Encoder";
        
        // Begin encoding render commands, including commands for the tessellator
        [renderCommandEncoder pushDebugGroup:@"Tessellate and Render"];
        
        // Set the correct render pipeline and bind the correct control points buffer
        if(self.patchType == MTLPatchTypeTriangle) {
            [renderCommandEncoder setRenderPipelineState:_renderPipelineTriangle];
            [renderCommandEncoder setVertexBuffer:_controlPointsBufferTriangle offset:0 atIndex:0];
        } else if(self.patchType == MTLPatchTypeQuad) {
            [renderCommandEncoder setRenderPipelineState:_renderPipelineQuad];
            [renderCommandEncoder setVertexBuffer:_controlPointsBufferQuad offset:0 atIndex:0];
        }
        
        // Enable/Disable wireframe mode
        if(self.wireframe) {
            [renderCommandEncoder setTriangleFillMode:MTLTriangleFillModeLines];
        }
        
        // Encode tessellation-specific commands
        [renderCommandEncoder setTessellationFactorBuffer:_tessellationFactorsBuffer offset:0 instanceStride:0];
        NSUInteger patchControlPoints = (self.patchType == MTLPatchTypeTriangle) ? 3 : 4;
        [renderCommandEncoder drawPatches:patchControlPoints patchStart:0 patchCount:1 patchIndexBuffer:NULL patchIndexBufferOffset:0 instanceCount:1 baseInstance:0];
        
        // All render commands have been encoded
        [renderCommandEncoder popDebugGroup];
        [renderCommandEncoder endEncoding];
        
        // Schedule a present once the drawable has been completely rendered to
        [commandBuffer presentDrawable:view.currentDrawable];
    }
}

#pragma mark MTKView delegate methods

// Called whenever view changes orientation or layout is changed
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
}


// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view
{
    @autoreleasepool {
        // Create a new command buffer for each tessellation pass
        id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = @"Tessellation Pass";
        
        [self computeTessellationFactorsWithCommandBuffer:commandBuffer];
        [self tessellateAndRenderInMTKView:view withCommandBuffer:commandBuffer];
        
        // Finalize tessellation pass and commit the command buffer to the GPU
        [commandBuffer commit];
    }
}

@end
