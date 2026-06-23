// URP abyssal rock seabed: bulky ridged terrain seen in the deep dark ocean.
// Slope-based blend (flat silt vs. steep bare rock), depth darkening, cold rim
// light, and a faint bioluminescent crevice glow instead of sunlit caustics.
// Globals (_Underwater*) come from UnderwaterEnvironment.cs, same as the sand shader,
// so this terrain fogs into the exact same backdrop the AbyssalSkybox draws.
Shader "Custom/AbyssalRock"
{
    Properties
    {
        _BaseMap ("Rock Albedo", 2D) = "white" {}
        [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0, 2)) = 0.9
        _WorldTiling ("Texture Tiling (tiles per metre)", Float) = 0.28
        _DetileStrength ("Anti-Tiling Blend", Range(0, 1)) = 0.5

        _RockColor ("Steep Rock Tint", Color) = (0.10, 0.13, 0.16, 1)
        _SiltColor ("Flat Silt Tint", Color) = (0.16, 0.20, 0.22, 1)
        _SlopeBlend ("Rock/Silt Slope Sharpness", Range(0.02, 1)) = 0.35
        _SlopeMidpoint ("Rock/Silt Slope Midpoint", Range(0, 1)) = 0.55

        _DeepColor ("Abyss Depth Tint", Color) = (0.01, 0.03, 0.05, 1)
        _DepthTintStrength ("Depth Darkening", Range(0, 1)) = 0.75
        _DepthTintRange ("Depth Darkening Range (m)", Float) = 9

        _Wetness ("Wet Rock Specular", Range(0, 2)) = 0.4
        _RimColor ("Cold Rim Light", Color) = (0.18, 0.42, 0.55, 1)
        _RimPower ("Rim Light Sharpness", Range(0.5, 8)) = 3.5
        _RimStrength ("Rim Light Strength", Range(0, 2)) = 0.6

        _BioColor ("Bioluminescent Glow", Color) = (0.10, 0.85, 0.70, 1)
        _BioIntensity ("Bioluminescence Strength", Range(0, 3)) = 0.7
        _BioScale ("Bioluminescence Scale", Float) = 0.5
        _BioSpeed ("Bioluminescence Pulse Speed", Float) = 0.25
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);   SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _RockColor;
                half4 _SiltColor;
                half4 _DeepColor;
                half4 _RimColor;
                half4 _BioColor;
                float _NormalStrength;
                float _WorldTiling;
                float _DetileStrength;
                float _SlopeBlend;
                float _SlopeMidpoint;
                float _DepthTintStrength;
                float _DepthTintRange;
                float _Wetness;
                float _RimPower;
                float _RimStrength;
                float _BioIntensity;
                float _BioScale;
                float _BioSpeed;
            CBUFFER_END

            // Globals driven by UnderwaterEnvironment.cs
            half4 _UnderwaterFogColor;
            half4 _UnderwaterColorSurface;
            half4 _UnderwaterColorDeep;
            half4 _UnderwaterSunGlow;
            float _UnderwaterFogDensity;
            float _UnderwaterFadeStart;
            float _UnderwaterFadeEnd;
            float _UnderwaterLevel;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
            };

            float UnderwaterFog(float3 positionWS)
            {
                float dist      = distance(positionWS, _WorldSpaceCameraPos);
                float fadeEnd   = _UnderwaterFadeEnd > 0.01 ? _UnderwaterFadeEnd : 1e5;
                float fadeStart = min(_UnderwaterFadeStart, fadeEnd - 0.01);
                float expFog    = 1.0 - exp(-pow(dist * _UnderwaterFogDensity, 2.0));
                return max(expFog, smoothstep(fadeStart, fadeEnd, dist));
            }

            // View-dependent backdrop colour; must match Custom/AbyssalSkybox.
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

            // Cheap smooth value noise (hash + bilinear) for the crevice glow —
            // no texture dependency, stays continuous across endless chunks.
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

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.positionWS.xz * _WorldTiling;

                // Two samples at different scales hide the texture repeat on endless rock.
                half3 albedo  = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).rgb;
                half3 albedo2 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv * 0.137 + 0.5).rgb;
                albedo = lerp(albedo, albedo2, _DetileStrength);

                // Normal mapping using a world-axis tangent frame (heightfield).
                half3 nTS = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv), _NormalStrength);
                half3 Ngeo = normalize(IN.normalWS);
                half3 T = normalize(cross(half3(0, 0, 1), Ngeo));
                half3 B = cross(Ngeo, T);
                half3 N = normalize(nTS.x * T + nTS.y * B + nTS.z * Ngeo);

                // Slope drives rock (steep) vs. silt (flat). Ngeo.y ~1 flat, ~0 vertical.
                half slope = 1.0 - saturate(Ngeo.y);
                half rockMask = smoothstep(_SlopeMidpoint - _SlopeBlend,
                                           _SlopeMidpoint + _SlopeBlend, slope);
                half3 tint = lerp(_SiltColor.rgb, _RockColor.rgb, rockMask);
                half3 baseCol = albedo * tint;

                // Soft, wrapped diffuse — abyssal light is faint and directionless.
                Light mainLight = GetMainLight();
                half  halfLambert = saturate(dot(N, mainLight.direction) * 0.5 + 0.5);
                half3 lighting = mainLight.color * halfLambert * 0.5 + SampleSH(N);
                half3 color = baseCol * lighting;

                // Wet-rock specular glint (stronger on steep bare rock).
                float3 V = normalize(_WorldSpaceCameraPos - IN.positionWS);
                half3 H = normalize(mainLight.direction + V);
                half spec = pow(saturate(dot(N, H)), 64.0);
                color += mainLight.color * (spec * _Wetness * (0.4 + 0.6 * rockMask));

                // Cold rim light — eerie edge glow where geometry turns away from the eye.
                half rim = pow(1.0 - saturate(dot(Ngeo, V)), _RimPower);
                color += _RimColor.rgb * (rim * _RimStrength);

                // Bioluminescent glow pooling in the flat silt / crevices, slow pulse.
                float bn = ValueNoise(IN.positionWS.xz * _BioScale);
                float bn2 = ValueNoise(IN.positionWS.xz * _BioScale * 2.3 + 9.7);
                float bio = saturate(bn * bn2);
                bio = pow(bio, 3.0) * (1.0 - rockMask);          // silt pockets only
                bio *= 0.55 + 0.45 * sin(_Time.y * _BioSpeed + bn * 30.0); // pulse
                color += _BioColor.rgb * saturate(bio) * _BioIntensity;

                // Deeper rock sinks toward the abyss colour (scary darkness below).
                float depthBelow = saturate((_UnderwaterLevel - IN.positionWS.y) /
                                            max(_DepthTintRange, 0.01));
                color = lerp(color, color * _DeepColor.rgb * 2.0,
                             depthBelow * _DepthTintStrength);

                // Fade into the same view-dependent backdrop the skybox draws.
                color = lerp(color, UnderwaterBackground(-V), UnderwaterFog(IN.positionWS));
                return half4(color, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }

            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings  { float4 positionCS : SV_POSITION; };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half frag(Varyings IN) : SV_Target { return IN.positionCS.z; }
            ENDHLSL
        }
    }
}
