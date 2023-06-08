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
    out.textureCoordinate = float2((out.position.x + 1) * 0.5, 1 - (out.position.y + 1) * 0.5); // [-1;1] -> [0; 1]
    return out;
}

struct FragmentUniform {
    float4 mask;
    uint2 output_size;
};

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> texture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = texture.sample(textureSampler, in.textureCoordinate);
    return color;
}

kernel void write_texture(texture2d<float, access::read> inputTexture [[texture(0)]],
                         texture2d<float, access::write> outputTexture [[texture(1)]],
                         constant FragmentUniform &uniforms [[buffer(0)]],
                         uint2 position [[thread_position_in_grid]]) {
    float4 inputColor = inputTexture.read(position);
    float4 outputColor = inputColor * uniforms.mask;
    uint2 rotatedPosition = uint2(uniforms.output_size.x - position.y, position.x);
    outputTexture.write(outputColor, rotatedPosition);
}
