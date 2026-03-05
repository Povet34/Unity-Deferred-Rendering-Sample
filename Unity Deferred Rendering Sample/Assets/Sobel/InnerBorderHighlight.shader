Shader "Custom/InnerBorderHighlight"
{
    Properties
    {
        _BorderColor     ("Border Color",      Color)  = (1,1,1,1)
        _DepthThreshold  ("Depth Threshold",   Float)  = 1.0
        _AlbedoMix       ("Albedo Mix",        Range(0,1)) = 0.5
        _BorderWidth     ("Border Width",      Range(1,10)) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "InnerBorderHighlight"

            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            // GBuffer 선언
            TEXTURE2D(_GBuffer0); SAMPLER(sampler_GBuffer0); // Albedo(RGB) + MaterialFlags(A)
            TEXTURE2D(_GBuffer1); SAMPLER(sampler_GBuffer1); // Specular(RGB) + Occlusion(A)

            // Blit.hlsl이 _BlitTexture는 선언해주지만 TexelSize는 직접 선언 필요
            float4 _BlitTexture_TexelSize;

            float4 _BorderColor;
            float  _DepthThreshold;
            float  _BorderWidth;
            float  _AlbedoMix;

            // --------------------------------------------------
            // Depth를 선형 Eye Depth로 변환해서 샘플링
            // --------------------------------------------------
            float SampleLinearDepth(float2 uv)
            {
                float raw = SampleSceneDepth(uv);
                return LinearEyeDepth(raw, _ZBufferParams);
            }

            // --------------------------------------------------
            // Depth 기반 Sobel
            // 인접 픽셀 Depth 차이가 크면 엣지
            // --------------------------------------------------
            float SobelDepth(float2 uv, float2 texelSize)
            {
                // 3x3 커널 샘플링
                float d00 = SampleLinearDepth(uv + float2(-1,-1) * texelSize);
                float d10 = SampleLinearDepth(uv + float2( 0,-1) * texelSize);
                float d20 = SampleLinearDepth(uv + float2( 1,-1) * texelSize);
                float d01 = SampleLinearDepth(uv + float2(-1, 0) * texelSize);
                float d21 = SampleLinearDepth(uv + float2( 1, 0) * texelSize);
                float d02 = SampleLinearDepth(uv + float2(-1, 1) * texelSize);
                float d12 = SampleLinearDepth(uv + float2( 0, 1) * texelSize);
                float d22 = SampleLinearDepth(uv + float2( 1, 1) * texelSize);

                // Sobel 수평/수직 커널
                float gx = -d00 - 2*d01 - d02 + d20 + 2*d21 + d22;
                float gy = -d00 - 2*d10 - d20 + d02 + 2*d12 + d22;

                return sqrt(gx*gx + gy*gy);
            }

            // --------------------------------------------------
            // Inner Border 추출
            // 현재 픽셀이 엣지가 아니지만 주변에 엣지가 있으면 Inner Border
            // -> 오브젝트 안쪽에 선이 그려지는 효과
            // --------------------------------------------------
            float InnerBorder(float2 uv, float2 texelSize, float threshold)
            {
                float center = SobelDepth(uv, texelSize);
                float isNotEdge = 1.0 - step(threshold, center);

                // BorderWidth만큼 offset 늘려서 더 두꺼운 Border 검출
                float2 offset = texelSize * _BorderWidth;
                float n = SobelDepth(uv + float2( 0, 1) * offset, texelSize);
                float s = SobelDepth(uv + float2( 0,-1) * offset, texelSize);
                float e = SobelDepth(uv + float2( 1, 0) * offset, texelSize);
                float w = SobelDepth(uv + float2(-1, 0) * offset, texelSize);

                float neighborEdge = step(threshold, max(max(n, s), max(e, w)));

                return isNotEdge * neighborEdge;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv        = input.texcoord;
                float2 texelSize = _BlitTexture_TexelSize.xy;

                // 원본 씬 색상 (Deferred Lighting 결과)
                half4 sceneColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);

                // GBuffer 샘플링
                half4 gbuffer0 = SAMPLE_TEXTURE2D(_GBuffer0, sampler_GBuffer0, uv);
                half4 gbuffer1 = SAMPLE_TEXTURE2D(_GBuffer1, sampler_GBuffer1, uv);

                half3 albedo          = gbuffer0.rgb;
                half  highlightStrength = gbuffer1.a; // Occlusion 채널 = Highlight Strength

                // Depth 기반 Sobel + Highlight Strength 가중치
                float depthEdge = SobelDepth(uv, texelSize);
                float weightedEdge = depthEdge * (1.0 + highlightStrength * 5.0);

                // Inner Border 추출
                float innerBorder = InnerBorder(uv, texelSize, _DepthThreshold);
                innerBorder *= saturate(weightedEdge * 10.0);

                // Border 색상 = BorderColor에 Albedo 색상을 물들이기
                // AlbedoMix = 0 -> 순수 BorderColor
                // AlbedoMix = 1 -> BorderColor * Albedo
                half3 tintedAlbedo = lerp(half3(1,1,1), albedo, _AlbedoMix);
                half3 borderCol = _BorderColor.rgb * tintedAlbedo;

                // 선 강도 = innerBorder * BorderColor.a * HighlightStrength 반영
                float borderMask = innerBorder * _BorderColor.a * (1.0 + highlightStrength * 5.0);
                borderMask = saturate(borderMask);

                // 씬 색상 위에 네온 선을 Additive로 덧씌움
                // -> 씬이 보존되고 선이 발광하는 느낌
                half3 finalColor = sceneColor.rgb + borderCol * borderMask;

                return half4(finalColor, sceneColor.a);
            }
            ENDHLSL
        }
    }
}