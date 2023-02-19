#include <metal_stdlib>
using namespace metal;

struct RasterizerData {
    float4 position [[position]];
    float2 uvs;
    float size [[point_size]];
    float2 viewport;
    float size2;
};

struct Vertex {
    float2 position;
    float2 uvs;
    float size;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(0)]],
                                   constant vector_uint2 *viewportSizePointer [[buffer(1)]]) {
    RasterizerData out;
    float2 pixelSpacePosition = vertices[vertexID].position.xy;
    vector_float2 viewportSize = vector_float2(*viewportSizePointer);

    out.position = vector_float4(0, 0, 0, 1);
    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);
    out.size = vertices[vertexID].size;
    out.uvs = vertices[vertexID].uvs;
    out.viewport = viewportSize;
    out.size2 = vertices[vertexID].size;

    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<float> texture [[texture(0)]],
                               float2 pointCoord [[point_coord]]) {
    float dist = length_squared(pointCoord * 2.0 - 1.0);
    constexpr sampler default_sampler;

    pointCoord.y = 1.0 - pointCoord.y;

    float2 newUvs = in.uvs + (pointCoord - 0.5) * in.size2;
    newUvs += 800.0;
    newUvs /= 1600.0;

    float4 color = texture.sample(default_sampler, newUvs);

    if (dist > 1) {
        discard_fragment();
    }
    return color;
}
