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
};

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                             constant VertexIn *vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = vector_float4(0, 0, 0, 1);
    out.position.xy = vertices[vertexID].position.xy;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return float4(1, 0, 0, 1);
}
