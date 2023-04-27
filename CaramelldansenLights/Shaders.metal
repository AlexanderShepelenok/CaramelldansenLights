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
    out.position = vector_float4(0, 0, 0, 1);
    out.position.xy = vertices[vertexID].position.xy;
    out.textureCoordinate = (1 - out.position.yx) * 0.5;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> texture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = texture.sample(textureSampler, in.textureCoordinate);
    return color * float4(in.textureCoordinate.x, in.textureCoordinate.y, 1.0 - in.textureCoordinate.x, 1.0);
}
