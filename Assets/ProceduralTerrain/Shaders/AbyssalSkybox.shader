// URP abyssal backdrop: a near-black vertical gradient with a faint cold glow far
// up toward the night surface, drifting bioluminescent motes, and a single soft
// moonlight shaft (instead of bright god rays). Matches the fog/gradient the
// AbyssalRock terrain and AbyssalWater surface fade into.
// Globals (_Underwater*) come from UnderwaterEnvironment.cs.
Shader "Custom/AbyssalSkybox"
{
    Properties
    {
        _MoonShaftIntensity ("Moon Shaft Intensity", Range(0, 1)) = 0.25
        _MoonShaftSharpness ("Moon Shaft Sharpness", Range(1, 64)) = 22
        _BioColor ("Mote Glow Colour", Color) = (0.10, 0.85, 0.70, 1)
        _BioIntensity ("Mote Glow Intensity", Range(0, 2)) = 0.5
        _BioDensity ("Mote Density", Range(1, 40)) = 14
        _BioSpeed ("Mote Drift Speed", Range(0, 1)) = 0.08
        _Darkness ("Overall Darkening", Range(0, 1)) = 0.55
    }

    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _MoonShaftIntensity;
                float _MoonShaftSharpness;
                half4 _BioColor;
                float _BioIntensity;
                float _BioDensity;
                float _BioSpeed;
                float _Darkness;
            CBUFFER_END

            // Globals driven by UnderwaterEnvironment.cs
            half4 _UnderwaterFogColor;
            half4 _UnderwaterColorSurface;
            half4 _UnderwaterColorDeep;
            half4 _UnderwaterSunGlow;

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 viewDirWS  : TEXCOORD0;
            };

            // Shared with Custom/AbyssalRock and Custom/AbyssalWaterSurface:
            // identical maths so fogged geometry matches the backdrop exactly.
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

            float Hash(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.viewDirWS  = IN.positionOS.xyz;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 V = normalize(IN.viewDirWS);
                half3 col = UnderwaterBackground(V);

                // Crush toward black: the abyss swallows almost all of the gradient.
                col *= (1.0 - _Darkness);

                // A single soft moonlight shaft toward the main-light direction,
                // only when looking up — a faint cold beam from the night surface.
                float3 L    = _MainLightPosition.xyz;
                float  toL  = saturate(dot(V, L));
                float  shaft = pow(toL, _MoonShaftSharpness) * smoothstep(0.05, 0.5, V.y);
                col += _UnderwaterSunGlow.rgb * (shaft * _MoonShaftIntensity);

                // Drifting bioluminescent motes: cell-hashed sparkles slowly rising,
                // giving the "something alive is out there" feel in the dark.
                float2 muv = V.xy / max(0.35, abs(V.z) + 0.35) * _BioDensity;
                muv.y -= _Time.y * _BioSpeed * _BioDensity;
                float2 cell = floor(muv);
                float  h    = Hash(cell);
                float2 fpos = frac(muv) - 0.5;
                float  d    = length(fpos) + (1.0 - h) * 0.7;
                float  mote = smoothstep(0.35, 0.0, d) * step(0.92, h);
                mote *= 0.5 + 0.5 * sin(_Time.y * (1.0 + h * 3.0) + h * 40.0); // twinkle
                col += _BioColor.rgb * (mote * _BioIntensity);

                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}
