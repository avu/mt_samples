#include <simd/simd.h>
#include <metal_stdlib>
#include "mstxt.h"

using namespace metal;

struct VertexInput {
    float3 position [[attribute(VertexAttributePosition)]];
    half4 color [[attribute(VertexAttributeColor)]];
    float2 texCoords [[attribute(VertexAttributeTexPos)]];
};

struct ShaderInOut {
    float4 position [[position]];
    half4  color;
    float2 texCoords;
};


vertex ShaderInOut vert(VertexInput in [[stage_in]],
	   constant FrameUniforms& uniforms [[buffer(FrameUniformBuffer)]]) {
    ShaderInOut out;
    float4 pos4 = float4(in.position, 1.0);
    out.position = uniforms.projectionViewModel * pos4;
    out.color = in.color / 255.0;
    out.texCoords = in.texCoords;
    return out;
}

fragment half4 frag(
        ShaderInOut vert  [[stage_in]],
        texture2d<float, access::sample> renderTexture [[texture(0)]]
        )
{
    constexpr sampler textureSampler (mag_filter::linear,
                                  min_filter::linear);
    float4 pixelColor = renderTexture.sample(textureSampler, vert.texCoords);
   // if (pixelColor.a < 0.1)
   //     discard_fragment();
    return half4(pixelColor.r*pixelColor.a, pixelColor.g*pixelColor.a, pixelColor.b*pixelColor.a , pixelColor.a);
}