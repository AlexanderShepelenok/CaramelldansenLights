//
//  Shaders.metal
//  ShadersExample
//
//  Created by Aleksandr Shepelenok on 23.02.23.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float3 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float2 viewportSize;
    float4x4 modelViewMatrix;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                             constant VertexIn *vertices [[buffer(0)]],
                             constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    float4 rotatedPos = uniforms.modelViewMatrix * float4(vertices[vertexID].position.xy, 0, 1);
    float2 position = rotatedPos.xy / (uniforms.viewportSize / 2.0);
    out.position = float4(position, 0, 1);
    out.color = float4(vertices[vertexID].color, 1);
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}
