/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders for rendering faries.
*/
#include <metal_stdlib>

using namespace metal;

// Include header shared between C code and .metal files.
#import "AAPLShaderTypes.h"

// Include header shared between all .metal files.
#import "AAPLShaderCommon.h"

typedef struct
{
    float4 position [[position]];
    half3 color;
} FairyInOut;

vertex FairyInOut fairy_vertex(const device AAPLSimpleVertex *vertices     [[ buffer(AAPLBufferIndexMeshPositions) ]],
                               const device AAPLPointLight *light_data     [[ buffer(AAPLBufferIndexLightsData) ]],
                               const device vector_float4 *light_positions [[ buffer(AAPLBufferIndexLightsPosition) ]],
                               uint iid                              [[ instance_id ]],
                               uint vid                              [[ vertex_id ]],
                               constant AAPLUniforms & uniforms      [[ buffer(AAPLBufferIndexUniforms) ]])
{
    FairyInOut out;

    // Convert 2D vertex to 3D vertex.
    float3 vertex_position = float3(vertices[vid].position.xy,0);

    // Project fairy vertices to screen space.
    float4 fairy_eye_pos = uniforms.viewMatrix * float4(light_positions[iid].xyz,1);

    // Add vertex position to fairy position and project to clip-space.
    out.position = uniforms.projectionMatrix * float4(vertex_position + fairy_eye_pos.xyz,1);

    // Pass fairy color through.
    out.color = half3(light_data[iid].lightColor.xyz);

    return out;
}

fragment half4 fairy_fragment(FairyInOut in [[ stage_in ]])
{
    return half4(in.color.xyz, 1);
}
