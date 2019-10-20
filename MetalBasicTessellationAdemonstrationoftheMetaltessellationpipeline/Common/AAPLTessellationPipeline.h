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

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface AAPLTessellationPipeline : NSObject <MTKViewDelegate>

@property (readwrite) MTLPatchType patchType;
@property (readwrite) BOOL wireframe;
@property (readwrite) float edgeFactor;
@property (readwrite) float insideFactor;

- (nullable instancetype)initWithMTKView:(nonnull MTKView *)mtkView;

@end
