# Deferred Lighting

Demonstrates how to implement a deferred lighting renderer that takes advantage of unique Metal features.

## Overview

This sample demonstrates a deferred lighting renderer that implements shadows using a shadow map, and culls light volumes using the stencil buffer.

![Screenshot of the sample app running to show the rich lighting effects.](Documentation/DeferredLighting.png)

Deferred lighting can render a large number of lights more easily than forward lighting. For example, with forward lighting, in a scene with many lights, it's infeasible for every fragment to calculate the contribution of every light. Complex sorting and binning algorithms must be implemented to limit the calculation of light contributions to only those lights affecting each fragment. With deferred lighting, multiple lights can be applied to the scene with ease.

## Getting Started

The Xcode project contains schemes for running the sample on macOS, iOS, or tvOS. Metal is not supported in the iOS or tvOS Simulator, so the iOS and tvOS schemes require a physical device to run the sample. The default scheme is macOS, which runs the sample as is on your Mac.

- Note: Splitting render targets into separate groups for fragment function execution requires a macOS or iOS device that supports raster order groups. Query the `rasterOrderGroupsSupported` property of your device to determine support.

The sample contains the following preprocessor conditionals that you can modify to control the configuration of the app.

``` objective-c
// When enabled, writes depth values in eye space to the g-buffer depth component. This allows the
// deferred pass to calculate the eye space fragment position more easily in order to apply lighting.
// When disabled, the screen depth is written to the g-buffer depth component and an extra inverse
// transform from screen space to eye space is necessary to calculate lighting contributions in
// the deferred pass.
#define USE_EYE_DEPTH                   1

// When enabled, uses the stencil buffer to avoid execution of lighting calculations on fragments
// that do not intersect with a 3D light volume.
// When disabled, all fragments covered by a light in screen space will have lighting calculations
// executed. This means that considerably more fragments will have expensive lighting calculations
// executed than is actually necessary.
#define LIGHT_STENCIL_CULLING           1

// Enables toggling of buffer examination mode at runtime. Code protected by this definition
// is only useful to examine parts of the underlying implementation (i.e. it's a debug feature).
#define SUPPORT_BUFFER_EXAMINATION      1
```

On macOS, press the following keys to examine the scene at runtime.

* **1.** See all the examination views at the same time.
* **2.** See the G-buffer albedo data.
* **3.** See the G-buffer normal data.
* **4.** See the G-buffer depth data.
* **5.** See the G-buffer specular data.
* **6.** See the G-buffer shadow data.
* **7.** See the shadow map.
* **8.** See the masked light volume coverage.
* **9.** See the full light volume coverage.
* **0 or return.** Exit an examination view and return to the standard view.

On iOS, tap the screen to toggle between the standard view and the examination view at runtime.

## Review Important Concepts

Before you get started with the sample app, review these concepts to better understand key details of a deferred lighting renderer and some unique Metal features.

**Traditional Deferred Lighting Renderer**

A traditional deferred lighting renderer is typically separated into two render passes:

* **First pass: G-buffer rendering.** The renderer draws and transforms the scene's models, and the fragment function renders the results to a collection of textures known as the *geometry buffer* or *G-buffer*. The G-buffer contains material colors from the models, as well as per-fragment normal, shadow, and depth values.

* **Second pass: Deferred lighting and composition.** The renderer draws each light volume, using the G-buffer data to reconstruct the position of each fragment and apply the lighting calculations. As the lights are drawn, the output of each light is blended on top of the previous light outputs. Finally, the renderer composites other data, such as shadows and directional lighting, onto the scene by executing a full-screen quad or a compute kernel.

![Implementation diagram showing the outputs of the two render passes in a traditional deferred lighting algorithm.](Documentation/TraditionalDeferredLighting.png)

- Note: macOS GPUs have an immediate mode rendering (IMR) architecture. On IMR GPUs, a deferred lighting renderer can only be implemented with at least two render passes. Therefore, the sample implements a two-pass deferred lighting algorithm for the macOS version of the app.  The iOS and tvOS simulators run on macOS Metal implementations so these also use the two-pass deferred lighting algorithm.

**Single-Pass Deferred Lighting on iOS and tvOS GPUs**

iOS and tvOS GPUs have a tile-based deferred rendering (TBDR) architecture, which allows them to render data to tile memory within the GPU. By rendering to tile memory, the device avoids potentially expensive round trips between the GPU and system memory (via a bandwidth-constrained memory bus). Whether a GPU writes tile memory to system memory depends on these configurations:

* The store action of the app's render command encoders.
* The storage mode of the app's textures.

When `MTLStoreActionStore` is set as a store action, output data for the render targets of a render pass is written from tile memory to system memory, where the render targets are backed by textures. If this data is then used for a subsequent render pass, input data from these textures is read from system memory into a texture cache in the GPU. Therefore, a traditional deferred lighting renderer that accesses system memory requires G-buffer data to be stored in system memory between the first and second render passes.

![Implementation diagram showing how G-buffer data in a traditional deferred lighting algorithm is transferred between the GPU and system memory.](Documentation/TraditionalDeferredLightingOnTBDR.png)

However, because of their TBDR architecture, iOS and tvOS GPUs can also read data from tile memory at any given time. This allows fragment shaders to read from and perform calculations on render targets in tile memory, before this data is written to tile memory again. This feature allows the sample to avoid storing G-buffer data in system memory between the first and second render passes; thus, a deferred lighting renderer can be implemented with a single render pass.

G-buffer data is produced and consumed exclusively by the GPU, not the CPU, within the single render pass. Therefore, this data isn't loaded from system memory before the render pass begins, nor is it stored in system memory after the render pass finishes. Instead of reading G-buffer data from a texture in system memory, the lighting fragment functions read data from the G-buffer while it's still attached to the render pass as a render target. Thus, system memory doesn't need to be allocated for G-buffer textures, and each of these textures can be declared with a `MTLStorageModeMemoryless` storage mode.

![Implementation diagram showing how G-buffer data in a single-pass deferred lighting algorithm is accessed in tile memory.](Documentation/SinglePassDeferredLightingOnTBDR.png)

- Note: The feature that allows a TBDR GPU to read from attached render targets in a fragment function is also known as *programmable blending*.

**Deferred Lighting with Raster Order Groups**

By default, when a fragment shader writes data to a pixel, the GPU waits until the shader has completely finished writing to that pixel before beginning the execution of another fragment shader for that same pixel.

![Timeline diagram showing two lights executed by a fragment shader, without raster order groups.](Documentation/DeferredLightingWithoutRasterOrderGroups.png)

Raster order groups allow apps to increase the parallelization of the GPU's fragment shaders. With raster order groups, a fragment function can separate render targets into different execution groups. This separation allows the GPU to read from and perform calculations on render targets in one group, before a previous instance of a fragment shader has finished writing data to pixels in another group.

![Timeline diagram showing two lights executed by a fragment shader, with raster order groups.](Documentation/DeferredLightingWithRasterOrderGroups.png)

In this sample, some lighting fragment functions use these raster order groups:

* **Raster order group 0.** `AAPLLightingROG` is used for the render target that contains the results of the lighting calculations.
* **Raster order group 1.** `AAPLGBufferROG` is used for the G-buffer data in the lighting function.

These raster order groups allow the GPU to read the G-buffer in a fragment shader and execute the lighting calculations, before the lighting calculations from a previous instance of a fragment shader have finished writing their output data.

## Render a Deferred Lighting Frame

The sample renders each full frame by rendering these stages, in this order:

1. Shadow map
2. G-buffer
3. Directional light
4. Light mask
5. Point lights
6. Skybox
7. Fairy lights

The sample's iOS and tvOS renderer produces the G-buffer and performs all subsequent stages in a single render pass. This single-pass implementation is possible due to the TBDR architecture of iOS and tvOS GPUs, which allows a device to read G-buffer data from render targets in tile memory.

``` objective-c
id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_viewRenderPassDescriptor];
renderEncoder.label = @"Combined GBuffer & Lighting Pass";

[super drawGBuffer:renderEncoder];

[self drawDirectionalLight:renderEncoder];

[super drawPointLightMask:renderEncoder];

[self drawPointLights:renderEncoder];

[super drawSky:renderEncoder];

[super drawFairies:renderEncoder];

[renderEncoder endEncoding];
```

The sample's macOS renderer produces the G-buffer in one render pass and then performs all subsequent stages in another render pass. This two-pass implementation is necessary due to the IMR architecture of macOS GPUs, which requires a device to sample G-buffer data from textures in video memory.

``` objective-c
id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_GBufferRenderPassDescriptor];
renderEncoder.label = @"GBuffer Generation";

[super drawGBuffer:renderEncoder];

[renderEncoder endEncoding];
```

``` objective-c
id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_finalRenderPassDescriptor];
renderEncoder.label = @"Lighting & Composition Pass";

[self drawDirectionalLight:renderEncoder];

[super drawPointLightMask:renderEncoder];

[self drawPointLights:renderEncoder];

[super drawSky:renderEncoder];

[super drawFairies:renderEncoder];

[renderEncoder endEncoding];
```

## Render the Shadow Map

The sample renders a shadow map for the single directional light in the scene (the sun) by rendering the model from the light's perspective.

![Rendering that shows the shadow map.](Documentation/ShadowMap.png)

The render pipeline for the shadow map has a vertex function but not a fragment function; therefore, the sample can determine the screen-space depth value written to the shadow map without executing further stages of the render pipeline. (Additionally, because the render pipeline doesn't have a fragment function, it executes much more quickly than it would if it had one.)

``` objective-c
MTLRenderPipelineDescriptor *renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
renderPipelineDescriptor.label = @"Shadow Gen";
renderPipelineDescriptor.vertexDescriptor = nil;
renderPipelineDescriptor.vertexFunction = shadowVertexFunction;
renderPipelineDescriptor.fragmentFunction = nil;
renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

_shadowGenPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor
                                                                  error:&error];
```

Before drawing geometry for the shadow map, the sample sets a depth bias value to reduce shadow artifacts.

``` objective-c
[encoder setDepthBias:0.015 slopeScale:7 clamp:0.02];
```

Then, in the fragment function of the G-buffer stage, the sample tests whether the fragment is occluded and shadowed.

``` metal
float shadow_sample = shadowMap.sample_compare(shadowSampler, in.shadow_coord.xy, in.shadow_coord.z);
```

The sample stores the result of the `sample_compare` function in the `w` component of the `normal_shadow` render target.

``` metal
gBuffer.normal_shadow = half4(eye_normal.xyz, shadow_sample);
```

In the directional light and point light composition stages, the sample reads the shadow value from the G-buffer and applies it to the fragment.

## Render the G-Buffer

The sample's G-buffer contains these textures:

* `albedo_specular_GBuffer`, which stores albedo and specular data. Albedo data is stored in the `x`, `y`, and `z` components; specular data is stored in the `w` component.
* `normal_shadow_GBuffer`, which stores normal and shadow data. Normal data is stored in the `x`, `y`, and `z` components; shadow data is stored in the `w` component.
* `depth_GBuffer`, which stores depth values in eye space.

![Rendering that shows the G-buffer textures.](Documentation/GBufferTextures.png)

When the sample renders the G-buffer, the iOS and tvOS renderer and the macOS renderer attach all the G-buffer textures as render targets for the render pass. However, because iOS and tvOS devices can both render the G-buffer and read from it in a single render pass, the sample creates the iOS and tvOS textures with a memoryless storage mode, which indicates that system memory isn't allocated for these textures. Instead, these textures are allocated and populated only in tile memory for the duration of the render pass.

The sample creates the G-buffer textures in the common `drawableSizeWillChange:withGBufferStorageMode:` method, but the iOS and tvOS renderer sets the `storageMode` variable to `MTLStorageModeMemoryless` while the macOS renderer sets it to `MTLStorageModePrivate`.

``` objective-c
GBufferTextureDesc.storageMode = storageMode;

GBufferTextureDesc.pixelFormat = _albedo_specular_GBufferFormat;
_albedo_specular_GBuffer = [_device newTextureWithDescriptor:GBufferTextureDesc];

GBufferTextureDesc.pixelFormat = _normal_shadow_GBufferFormat;
_normal_shadow_GBuffer = [_device newTextureWithDescriptor:GBufferTextureDesc];

GBufferTextureDesc.pixelFormat = _depth_GBufferFormat;
_depth_GBuffer = [_device newTextureWithDescriptor:GBufferTextureDesc];
```

For the macOS renderer, after the sample finishes writing data to the G-buffer textures, it calls the `endEncoding` method to finalize the G-buffer render pass. Because the store action for the render command encoder is set to `MTLStoreActionStore`, the GPU writes each of the render target textures to video memory when the encoder completes its execution. This allows the sample to read these textures from video memory in the subsequent deferred lighting and composition render pass.

For the iOS and tvOS renderer, after the sample finishes writing data to the G-buffer textures, the sample doesn't finalize the render command encoder and instead continues to use it for subsequent stages.

## Apply the Directional Lighting and Shadows

The sample applies directional lighting and shadows to the drawable that's destined for the display.

The macOS renderer reads G-buffer data from textures set as arguments to a fragment function.

``` metal
fragment half4
deferred_directional_lighting_fragment(QuadInOut               in                      [[ stage_in ]],
                                       constant AAPLUniforms & uniforms                [[ buffer(AAPLBufferIndexUniforms) ]],
                                       texture2d<half>         albedo_specular_GBuffer [[ texture(AAPLRenderTargetAlbedo) ]],
                                       texture2d<half>         normal_shadow_GBuffer   [[ texture(AAPLRenderTargetNormal) ]],
                                       texture2d<float>        depth_GBuffer           [[ texture(AAPLRenderTargetDepth)  ]])
```

The iOS and tvOS renderer reads G-buffer data from render targets attached to the render pass.

``` objective-c
struct GBufferData
{
    half4 lighting        [[color(AAPLRenderTargetLighting), raster_order_group(AAPLLightingROG)]];
    half4 albedo_specular [[color(AAPLRenderTargetAlbedo),   raster_order_group(AAPLGBufferROG)]];
    half4 normal_shadow   [[color(AAPLRenderTargetNormal),   raster_order_group(AAPLGBufferROG)]];
    float depth           [[color(AAPLRenderTargetDepth),    raster_order_group(AAPLGBufferROG)]];
};
```

``` metal
fragment AccumLightBuffer
deferred_directional_lighting_fragment(QuadInOut               in       [[ stage_in ]],
                                       constant AAPLUniforms & uniforms [[ buffer(AAPLBufferIndexUniforms) ]],
                                       GBufferData             GBuffer)
```

Although these fragment functions have different inputs, they share a common implementation in the `deferred_directional_lighting_fragment_common` fragment function. This function performs these operations:

* Reconstructs the normals from the G-buffer normal data to calculate the diffuse term.
* Reconstructs the eye space position from the G-buffer depth data to apply specular highlights.
* Uses the G-buffer shadow data to darken the fragment and apply the shadow to the scene.

Because this is the first stage that renders to the drawable, the iOS and tvOS renderer obtains a drawable before the earlier G-buffer stage so that the drawable can be merged with the output of later stages. The macOS renderer, however, delays obtaining a drawable until after the G-buffer stage is completed and before the directional light stage begins. This delay reduces the amount of time that the app holds onto the drawable and thus improves performance.

- Note: Because of the state of `_directionLightDepthStencilState`, the `deferred_directional_lighting_fragment` function is only executed for fragments that should be lit. This optimization is simple yet important, and saves many fragment shader execution cycles.

## Cull the Light Volumes

The sample creates a stencil mask that's used to avoid executing expensive lighting calculations for many fragments. It creates this stencil mask by using the depth buffer from the G-buffer pass, and the stencil buffer, to track whether a light volume intersects any geometry. (If not, then it isn't casting light on anything.)

In the `drawPointLightMask:` implementation, the sample sets the `_lightMaskPipelineState` render pipeline and encodes an instanced draw call to draw only the back faces of icosahedrons, which encompass the volumes of the point lights. If a fragment within this draw call fails the depth test, this result indicates that the back face of the icosahedron is behind some geometry.

``` objective-c
[renderEncoder setRenderPipelineState:_lightMaskPipelineState];
[renderEncoder setDepthStencilState:_lightMaskDepthStencilState];

[renderEncoder setStencilReferenceValue:128];
[renderEncoder setCullMode:MTLCullModeFront];

[renderEncoder setVertexBuffer:self.uniformBuffers[self.currentBufferIndex] offset:0 atIndex:AAPLBufferIndexUniforms];
[renderEncoder setFragmentBuffer:self.uniformBuffers[self.currentBufferIndex] offset:0 atIndex:AAPLBufferIndexUniforms];
[renderEncoder setVertexBuffer:self.lightsData offset:0 atIndex:AAPLBufferIndexLightsData];
[renderEncoder setVertexBuffer:self.lightPositions[self.currentBufferIndex] offset:0 atIndex:AAPLBufferIndexLightsPosition];

MTKMeshBuffer *vertexBuffer = self.icosahedronMesh.vertexBuffers[AAPLBufferIndexMeshPositions];
[renderEncoder setVertexBuffer:vertexBuffer.buffer offset:vertexBuffer.offset atIndex:AAPLBufferIndexMeshPositions];

MTKSubmesh *icosahedronSubmesh = self.icosahedronMesh.submeshes[0];
[renderEncoder drawIndexedPrimitives:icosahedronSubmesh.primitiveType
                          indexCount:icosahedronSubmesh.indexCount
                           indexType:icosahedronSubmesh.indexType
                         indexBuffer:icosahedronSubmesh.indexBuffer.buffer
                   indexBufferOffset:icosahedronSubmesh.indexBuffer.offset
                       instanceCount:AAPLNumLights];
```

`_lightMaskPipelineState` doesn't have a fragment function, so no color data is written from this render pipeline. However, due to the set `_lightMaskDepthStencilState` depth and stencil state, any fragment that fails the depth test increments the stencil buffer for that fragment. Fragments that contain geometry have a starting depth value of `128`, which the sample set in the G-buffer stage. Therefore, any fragment that fails the depth test while `_lightMaskDepthStencilState` is set increments the depth value to greater than `128`. (Because front face culling is enabled, a fragment that fails the depth test and has a value greater than `128` indicates that at least the back half of the icosahedron is behind all geometry.)

In the next draw call, in the `drawPointLightsCommon` implementation, the sample applies the contribution of the point lights to the drawable. The sample tests whether the front half of the icosahedron is in front of all geometry, which determines if the volume intersects some geometry and thus if the fragment should be lit. The depth and stencil state,  `_pointLightDepthStencilState`, set for this draw call only executes the fragment function if the stencil value for the fragment is greater than the reference value of `128`. (Because the stencil test value is set to `MTLCompareFunctionLess`, the sample passes the test only if the reference value of `128` is less than the value in the stencil buffer.)

``` objective-c
[renderEncoder setDepthStencilState:_pointLightDepthStencilState];

[renderEncoder setStencilReferenceValue:128];
[renderEncoder setCullMode:MTLCullModeBack];

[renderEncoder setVertexBuffer:self.uniformBuffers[self.currentBufferIndex] offset:0 atIndex:AAPLBufferIndexUniforms];
[renderEncoder setVertexBuffer:self.lightsData offset:0 atIndex:AAPLBufferIndexLightsData];
[renderEncoder setVertexBuffer:self.lightPositions[self.currentBufferIndex] offset:0 atIndex:AAPLBufferIndexLightsPosition];

[renderEncoder setFragmentBuffer:self.uniformBuffers[self.currentBufferIndex] offset:0 atIndex:AAPLBufferIndexUniforms];
[renderEncoder setFragmentBuffer:self.lightsData offset:0 atIndex:AAPLBufferIndexLightsData];
[renderEncoder setFragmentBuffer:self.lightPositions[self.currentBufferIndex] offset:0 atIndex:AAPLBufferIndexLightsPosition];

MTKMeshBuffer *vertexBuffer = self.icosahedronMesh.vertexBuffers[AAPLBufferIndexMeshPositions];
[renderEncoder setVertexBuffer:vertexBuffer.buffer offset:vertexBuffer.offset atIndex:AAPLBufferIndexMeshPositions];

MTKSubmesh *icosahedronSubmesh = self.icosahedronMesh.submeshes[0];
[renderEncoder drawIndexedPrimitives:icosahedronSubmesh.primitiveType
                          indexCount:icosahedronSubmesh.indexCount
                           indexType:icosahedronSubmesh.indexType
                         indexBuffer:icosahedronSubmesh.indexBuffer.buffer
                   indexBufferOffset:icosahedronSubmesh.indexBuffer.offset
                       instanceCount:AAPLNumLights];
```

Because the draw call in `drawPointLightMask:` increments the stencil values for fragments that are behind any geometry, the only fragments for which the sample executes the fragment function are those that meet both of these conditions:

* Fragments whose front face passes the depth test and is in front of some geometry.

* Fragments whose back face fails the depth test and is behind some geometry.

The following diagrams show the difference in fragment coverage between a rendered frame that uses this stencil mask algorithm and another that doesn't. When the algorithm is enabled, pixels in green are pixels for which the point light fragment function was executed.

![Rendering that shows point light fragment coverage when the stencil mask is enabled.](Documentation/StencilMaskOnly.png)

When the algorithm is disabled, pixels in green and red are pixels for which the point light fragment function was executed.

![Rendering that shows point light fragment coverage when the stencil mask is disabled.](Documentation/StencilMaskVSFullVolumes.png)

## Render the Skybox and Fairy Lights

In the final lighting stages, the sample applies much simpler lighting techniques to the scene.

The sample applies depth testing to the skybox, against the temple's geometry, so the renderer only renders to areas of the drawable that have not been filled by some geometry.

``` objective-c
[renderEncoder setRenderPipelineState:_skyboxPipelineState];
[renderEncoder setDepthStencilState:_dontWriteDepthStencilState];
[renderEncoder setCullMode:MTLCullModeFront];

[renderEncoder setVertexBuffer:_uniformBuffers[_currentBufferIndex] offset:0 atIndex:AAPLBufferIndexUniforms];
[renderEncoder setFragmentTexture:_skyMap atIndex:AAPLTextureIndexBaseColor];

// Set mesh's vertex buffers
for (NSUInteger bufferIndex = 0; bufferIndex < _skyMesh.vertexBuffers.count; bufferIndex++)
{
    __unsafe_unretained MTKMeshBuffer *vertexBuffer = _skyMesh.vertexBuffers[bufferIndex];
    if((NSNull*)vertexBuffer != [NSNull null])
    {
        [renderEncoder setVertexBuffer:vertexBuffer.buffer
                                offset:vertexBuffer.offset
                               atIndex:bufferIndex];
    }
}

MTKSubmesh *sphereSubmesh = _skyMesh.submeshes[0];
[renderEncoder drawIndexedPrimitives:sphereSubmesh.primitiveType
                          indexCount:sphereSubmesh.indexCount
                           indexType:sphereSubmesh.indexType
                         indexBuffer:sphereSubmesh.indexBuffer.buffer
                   indexBufferOffset:sphereSubmesh.indexBuffer.offset];
```

The sample renders fairy lights onto the drawable as 2D circles and uses a texture to determine the alpha blending factors for their fragments.

``` metal
half4 c = colorMap.sample(linearSampler, float2(in.tex_coord));

half3 fragColor = in.color * c.x;

return half4(fragColor, c.x);
```
