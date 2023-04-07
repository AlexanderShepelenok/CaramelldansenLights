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
    float2 textureCoordinate;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                             constant VertexIn *vertices [[buffer(0)]]) {
    VertexOut out;
    float4 position = float4(vertices[vertexID].position.xy, 0, 1);
    out.position = float4(position.xy, 0, 1);
    // Convert coordinate space from [-1,1] to [0,1]
    float2 rotatedPosition = float2(position.y, position.x);
    out.textureCoordinate = float2((rotatedPosition - 1.0) / -2.0);

    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> texture [[ texture(0) ]]) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    float4 color = texture.sample(textureSampler, in.textureCoordinate.xy);
    return color;
}
