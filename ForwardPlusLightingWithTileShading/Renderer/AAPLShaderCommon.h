/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header containing types and enumeration constants shared between Metal shaders (but not C/Objective-C source).
*/
#ifndef AAPLShaderCommon_h
#define AAPLShaderCommon_h

// Per-tile data computed by the culling kernel.
struct TileData
{
    atomic_int numLights;
    float minDepth;
    float maxDepth;
};

// Per-vertex inputs populated by the vertex buffer laid out with the `MTLVertexDescriptor` Metal API.
typedef struct
{
    float3 position [[attribute(AAPLVertexAttributePosition)]];
    float2 texCoord [[attribute(AAPLVertexAttributeTexcoord)]];
    half3 normal    [[attribute(AAPLVertexAttributeNormal)]];
    half3 tangent   [[attribute(AAPLVertexAttributeTangent)]];
    half3 bitangent [[attribute(AAPLVertexAttributeBitangent)]];
} Vertex;

// Outputs for the color attachments.
typedef struct
{
    half4 lighting [[color(AAPLRenderTargetLighting)]];
    float depth    [[color(AAPLRenderTargetDepth)]];
} ColorData;

#endif /* AAPLShaderCommon_h */
