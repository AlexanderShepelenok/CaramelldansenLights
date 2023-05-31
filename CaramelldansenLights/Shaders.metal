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
    float2 position = vertices[vertexID].position.xy;
    out.position = float4(position.xy, 0, 1);
    
    // Convert coordinate space from [-1,1] to [0,-1]
    out.textureCoordinate = float2((position.x + 1) * 0.5, 1 - (position.y + 1) * 0.5);
    return out;
}

struct FragmentUniforms {
    float4 colorMask;
    uint2 outputSize;
};

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> texture [[ texture(0) ]]) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    float4 color = texture.sample(textureSampler, in.textureCoordinate.xy);
    return color;
}

kernel void compute_color(texture2d<float, access::read> inputTexture [[texture(0)]],
                          texture2d<float, access::write> outputTexture [[texture(1)]],
                          constant FragmentUniforms &uniforms [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    
    float4 inputColor = inputTexture.read(gid);
    float4 outputColor = inputColor * uniforms.colorMask;
    uint2 position = uint2(uniforms.outputSize.x - gid.y, gid.x);
    outputTexture.write(outputColor, position);
}
