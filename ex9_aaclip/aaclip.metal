#include <simd/simd.h>
#include "aaclip.h"

using namespace metal;

struct VertexInput {
    float3 position [[attribute(VertexAttributePosition)]];
    half4 color [[attribute(VertexAttributeColor)]];
};

struct ShaderInOut {
    float4 position [[position]];
    half4  color;
};

struct StencilShaderInOut {
    float4 position [[position]];
    char color;
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
    out.color = 0xFF;
    return out;
}

fragment half4 frag(ShaderInOut in [[stage_in]]) {
    return in.color;
}

fragment unsigned int frag_stencil(StencilShaderInOut in [[stage_in]]) {
    return in.color;
}