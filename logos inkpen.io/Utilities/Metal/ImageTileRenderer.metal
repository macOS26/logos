#include <metal_stdlib>
using namespace metal;

struct TileVertex {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float opacity [[attribute(2)]];
};

struct TileVertexOut {
    float4 position [[position]];
    float2 texCoord;
    float opacity;
};

// Vertex shader - transforms tile quad to screen space
vertex TileVertexOut tileVertexShader(TileVertex in [[stage_in]],
                                      constant float4x4& mvpMatrix [[buffer(1)]]) {
    TileVertexOut out;
    out.position = mvpMatrix * float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    out.opacity = in.opacity;
    return out;
}

// Fragment shader - samples texture at tile coordinates with per-tile opacity
fragment float4 tileFragmentShader(TileVertexOut in [[stage_in]],
                                   texture2d<float> imageTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear,
                                     address::clamp_to_edge);

    float4 color = imageTexture.sample(textureSampler, in.texCoord);
    color.a *= in.opacity;
    return color;
}
