Shader "Custom/InnerBorderHighlight"
{
    Properties
    {
        _BorderColor    ("Border Color",    Color)        = (1, 1, 1, 1)
        _DepthThreshold ("Depth Threshold", Float)        = 1.0
        _AlbedoMix      ("Albedo Mix",      Range(0, 1))  = 0.5
        _BorderWidth    ("Border Width",    Range(1, 10)) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
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

            TEXTURE2D(_GBuffer0); SAMPLER(sampler_GBuffer0);
            TEXTURE2D(_GBuffer1); SAMPLER(sampler_GBuffer1);

            float4 _BlitTexture_TexelSize;
            float4 _BorderColor;
            float  _DepthThreshold;
            float  _AlbedoMix;
            float  _BorderWidth;

            float SampleEyeDepth(float2 uv)
            {
                return LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
            }

            float SobelDepth(float2 uv, float2 ts)
            {
                float d00 = SampleEyeDepth(uv + float2(-1,-1) * ts);
                float d10 = SampleEyeDepth(uv + float2( 0,-1) * ts);
                float d20 = SampleEyeDepth(uv + float2( 1,-1) * ts);
                float d01 = SampleEyeDepth(uv + float2(-1, 0) * ts);
                float d21 = SampleEyeDepth(uv + float2( 1, 0) * ts);
                float d02 = SampleEyeDepth(uv + float2(-1, 1) * ts);
                float d12 = SampleEyeDepth(uv + float2( 0, 1) * ts);
                float d22 = SampleEyeDepth(uv + float2( 1, 1) * ts);

                float gx = -d00 - 2*d01 - d02 + d20 + 2*d21 + d22;
                float gy = -d00 - 2*d10 - d20 + d02 + 2*d12 + d22;
                return sqrt(gx*gx + gy*gy);
            }

            float CalcInnerBorder(float2 uv, float2 ts, float threshold)
            {
                float notEdge  = 1.0 - step(threshold, SobelDepth(uv, ts));
                float2 offset  = ts * _BorderWidth;
                float n = SobelDepth(uv + float2( 0, 1) * offset, ts);
                float s = SobelDepth(uv + float2( 0,-1) * offset, ts);
                float e = SobelDepth(uv + float2( 1, 0) * offset, ts);
                float w = SobelDepth(uv + float2(-1, 0) * offset, ts);
                float nearEdge = step(threshold, max(max(n, s), max(e, w)));
                return notEdge * nearEdge;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;
                float2 ts = _BlitTexture_TexelSize.xy;

                half4 scene    = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
                half4 gbuffer0 = SAMPLE_TEXTURE2D(_GBuffer0, sampler_GBuffer0, uv);
                half4 gbuffer1 = SAMPLE_TEXTURE2D(_GBuffer1, sampler_GBuffer1, uv);

                half3 albedo           = gbuffer0.rgb;
                half  highlightStrength = gbuffer1.a;

                float border     = CalcInnerBorder(uv, ts, _DepthThreshold);
                float borderMask = saturate(border * (1.0 + highlightStrength * 5.0));

                half3 tint       = lerp(half3(1,1,1), albedo, _AlbedoMix);
                half3 borderCol  = _BorderColor.rgb * tint;
                half3 finalColor = scene.rgb + borderCol * borderMask * _BorderColor.a;

                return half4(finalColor, scene.a);
            }
            ENDHLSL
        }
    }
}