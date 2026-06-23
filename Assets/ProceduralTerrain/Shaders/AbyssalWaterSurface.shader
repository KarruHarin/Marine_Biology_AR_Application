// URP abyssal water surface seen from far below at night: dark, near-opaque, with
// slow heavy swells, a cold fresnel rim, and only the faintest moonlight shimmer
// (no bright sunlit caustics). Fades into the shared abyssal fog at distance.
// Globals (_Underwater*) come from UnderwaterEnvironment.cs.
Shader "Custom/AbyssalWaterSurface"
{
    Properties
    {
        _WaterColor ("Water Colour", Color) = (0.02, 0.06, 0.10, 1)
        _Opacity ("Base Opacity", Range(0, 1)) = 0.7

        _WaveAmplitude ("Wave Amplitude (m)", Float) = 0.22
        _WaveLength ("Wave Length (m)", Float) = 6.0
        _WaveSpeed ("Wave Speed", Float) = 0.4

        _ShimmerScale ("Moon Shimmer Scale", Float) = 0.18
        _ShimmerIntensity ("Moon Shimmer Intensity", Range(0, 2)) = 0.35
        _ShimmerSpeed ("Moon Shimmer Speed", Float) = 0.25
        _ShimmerColor ("Moon Shimmer Colour", Color) = (0.30, 0.55, 0.70, 1)

        _FresnelPower ("Fresnel Power", Range(0.5, 8)) = 4.0
        _FresnelColor ("Fresnel Rim Colour", Color) = (0.12, 0.30, 0.42, 1)
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "RenderPipeline"="UniversalPipeline"
        }

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _WaterColor;
                half4 _ShimmerColor;
                half4 _FresnelColor;
                float _Opacity;
                float _WaveAmplitude;
                float _WaveLength;
                float _WaveSpeed;
                float _ShimmerScale;
                float _ShimmerIntensity;
                float _ShimmerSpeed;
                float _FresnelPower;
            CBUFFER_END

            // Globals driven by UnderwaterEnvironment.cs
            half4 _UnderwaterFogColor;
            half4 _UnderwaterColorSurface;
            half4 _UnderwaterColorDeep;
            half4 _UnderwaterSunGlow;
            float _UnderwaterFogDensity;
            float _UnderwaterFadeStart;
            float _UnderwaterFadeEnd;

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
            };

            float Hash(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }
            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = Hash(i);
                float b = Hash(i + float2(1, 0));
                float c = Hash(i + float2(0, 1));
                float d = Hash(i + float2(1, 1));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float UnderwaterFog(float3 positionWS)
            {
                float dist      = distance(positionWS, _WorldSpaceCameraPos);
                float fadeEnd   = _UnderwaterFadeEnd > 0.01 ? _UnderwaterFadeEnd : 1e5;
                float fadeStart = min(_UnderwaterFadeStart, fadeEnd - 0.01);
                float expFog    = 1.0 - exp(-pow(dist * _UnderwaterFogDensity, 2.0));
                return max(expFog, smoothstep(fadeStart, fadeEnd, dist));
            }

            // Must stay identical to Custom/AbyssalSkybox (see that file).
            half3 UnderwaterBackground(float3 viewDir)
            {
                half3 col = lerp(_UnderwaterFogColor.rgb, _UnderwaterColorSurface.rgb,
                                 smoothstep(0.0, 0.7, viewDir.y));
                col = lerp(col, _UnderwaterColorDeep.rgb,
                           smoothstep(0.0, 0.6, -viewDir.y));

                float3 L = _MainLightPosition.xyz;
                float sunAmount = saturate(dot(viewDir, L));
                col += _UnderwaterSunGlow.rgb *
                       (pow(sunAmount, 12.0) * 0.5 + pow(sunAmount, 90.0) * 0.8);
                return col;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);

                // Two world-space swells; slower and heavier than the bright water.
                float  k  = TWO_PI / max(_WaveLength, 0.01);
                float  t  = _Time.y * _WaveSpeed;
                float2 d1 = normalize(float2(1.0, 0.6));
                float2 d2 = normalize(float2(-0.7, 1.0));
                float  p1 = dot(posWS.xz, d1) * k + t;
                float  p2 = dot(posWS.xz, d2) * (k * 1.7) - t * 1.3;

                posWS.y += (sin(p1) + 0.6 * sin(p2)) * _WaveAmplitude;

                float dx = (cos(p1) * d1.x * k + 0.6 * cos(p2) * d2.x * k * 1.7) * _WaveAmplitude;
                float dz = (cos(p1) * d1.y * k + 0.6 * cos(p2) * d2.y * k * 1.7) * _WaveAmplitude;
                OUT.normalWS = normalize(float3(-dx, 1.0, -dz));

                OUT.positionWS = posWS;
                OUT.positionCS = TransformWorldToHClip(posWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 V = normalize(_WorldSpaceCameraPos - IN.positionWS);
                half3 N = normalize(IN.normalWS);

                // abs() so the fresnel works identically from above and below.
                half ndv     = abs(dot(N, V));
                half fresnel = pow(1.0 - ndv, _FresnelPower);

                // Faint broken moon shimmer rolling across the swell — soft, not caustic.
                float2 suv = IN.positionWS.xz * _ShimmerScale;
                float  st  = _Time.y * _ShimmerSpeed;
                float shimmer = ValueNoise(suv + float2(st, -st * 0.7));
                shimmer = pow(saturate(shimmer), 4.0);

                Light mainLight = GetMainLight();
                half3 color = _WaterColor.rgb;
                color += shimmer * _ShimmerIntensity * _ShimmerColor.rgb * (0.3 + 0.7 * mainLight.color);
                color += fresnel * _FresnelColor.rgb;

                half alpha = saturate(_Opacity + fresnel * 0.25);

                // Melt into the same view-dependent backdrop the skybox draws.
                float fog = UnderwaterFog(IN.positionWS);
                color = lerp(color, UnderwaterBackground(-V), fog);
                alpha = lerp(alpha, 1.0, fog);

                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
}
