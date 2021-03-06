#include <simd/simd.h>
#include "aaclip2.h"

using namespace metal;

struct VertexInput {
    float3 position [[attribute(VertexAttributePosition)]];
    half4 color [[attribute(VertexAttributeColor)]];
};

struct TxVertexInput {
    float3 position [[attribute(VertexAttributePosition)]];
    half4 color [[attribute(VertexAttributeColor)]];
    float2 texCoords [[attribute(VertexAttributeTexPos)]];
};

struct ShaderInOut {
    float4 position [[position]];
    half4  color;
};

struct TxShaderInOut {
    float4 position [[position]];
    half4  color;
    float2 texCoords [[attribute(VertexAttributeTexPos)]];
};

struct StencilShaderInOut {
    float4 position [[position]];
    float4  color;
};

vertex ShaderInOut vert(VertexInput in [[stage_in]],
	   constant FrameUniforms& uniforms [[buffer(FrameUniformBuffer)]]) {
    ShaderInOut out;
    float4 pos4 = float4(in.position, 1.0);
    out.position = uniforms.projectionViewModel * pos4;
    out.color = in.color / 255.0;
    return out;
}

vertex StencilShaderInOut vert_stencil(VertexInput in [[stage_in]],
    constant FrameUniforms& uniforms [[buffer(FrameUniformBuffer)]]) {
    StencilShaderInOut out;
    float4 pos4 = float4(in.position, 1.0);
    out.position = uniforms.projectionViewModel * pos4;
    out.color = float4(1.0f, 1.0f, 1.0f, 1.0f);
    return out;
}

fragment half4 frag(ShaderInOut in [[stage_in]]) {
    return in.color;
}

fragment  float4 frag_stencil(StencilShaderInOut in [[stage_in]]) {
    return float4(1.0f, 1.0f, 1.0f, 1.0f);
}

vertex TxShaderInOut tx_vert(TxVertexInput in [[stage_in]],
    constant FrameUniforms& uniforms [[buffer(FrameUniformBuffer)]]) {
    TxShaderInOut out;
    float4 pos4 = float4(in.position, 1.0);
    out.position = uniforms.projectionViewModel * pos4;
    out.color = in.color / 255.0;
    out.texCoords = in.texCoords;
    return out;
}

fragment half4 tx_frag(
        TxShaderInOut vert  [[stage_in]],
texture2d<float, access::sample> renderTexture [[texture(0)]],
        texture2d<float, access::sample> stencilTexture [[texture(1)]]
)
{
    constexpr sampler textureSampler (mag_filter::linear,
                                  min_filter::linear);
    float4 pixelColor = renderTexture.sample(textureSampler, vert.texCoords);
    float4 stencil = stencilTexture.sample(textureSampler, vert.texCoords);
    if (stencil.r ==  0.0 && stencil.g ==  0.0 && stencil.b ==  0.0 && stencil.a ==  0.0) {
        discard_fragment();
    }
    return half4(pixelColor.r*pixelColor.a, pixelColor.g*pixelColor.a, pixelColor.b*pixelColor.a, 1.0);
}