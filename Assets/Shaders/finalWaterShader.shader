Shader "Custom/Final Water Shader" {
    Properties {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        [NoScaleOffset] _FlowMap ("Flow (RG, A noise)", 2D) = "black" {}
        //[NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
        [NoScaleOffset] _DerivHeightMap ("Deriv (AG) Height (B)", 2D) = "black" {}
        _UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
        _VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25
        _Tiling ("Tiling", Range(1, 10)) = 1
        _Speed ("Speed", Range(1, 10)) = 1
        _FlowStrength ("Flow Strength", Range(0.0, 1.0)) = 1
        _FlowOffset ("Flow Offset", Range(0.0, 1.0)) = 0
        _HeightScale ("Height Scale, Constant", Float) = 0.25
        _HeightScaleModulated ("Height Scale, Modulated", Float) = 0.75
        _Amplitude ("Wave Amplitude", Range(0.1, 10.0)) = 1.0
        _WaveA ("Wave A (dir, steepness, waveNumber)", Vector) = (1,0,2.0,10)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vertexFunc addshadow
        #pragma target 3.0

        #include "Flow.cginc"

        sampler2D _MainTex, _FlowMap, _DerivHeightMap;
        float _UJump, _VJump, _Tiling, _Speed, _FlowStrength, _FlowOffset, _Amplitude;

        float4 _WaveA;

        float _HeightScale, _HeightScaleModulated;

        struct Input {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        float3 UnpackDerivativeHeight (float4 textureData) {
            float3 dh = textureData.agb;
            dh.xy = dh.xy * 2 - 1;
            return dh;
        }

        float3 GerstnerWave (
            float4 wave, float3 p, inout float3 tangent, inout float3 binormal
        ) {
            float steepness = wave.z;
            float k = wave.w;
            float c = sqrt(9.8 / k);
            float2 d = normalize(wave.xy);
            float f = k * (dot(d, p.xz) - c * _Time.y);
            float a = steepness / k;

            tangent += float3(
                -d.x * d.x * (steepness * sin(f)),
                d.x * (steepness * cos(f)),
                -d.x * d.y * (steepness * sin(f))
            );
            binormal += float3(
                -d.x * d.y * (steepness * sin(f)),
                d.y * (steepness * cos(f)),
                -d.y * d.y * (steepness * sin(f))
            );
            return float3(
                d.x * (a * cos(f)),
                a * sin(f),
                d.y * (a * cos(f))
            );
        }

        void vertexFunc(inout appdata_full vertexData) {
            float3 gridPoint = vertexData.vertex.xyz;
            float3 tangent = float3(1, 0, 0);
            float3 binormal = float3(0, 0, 1);
            float3 p = gridPoint;
            p += GerstnerWave(_WaveA, gridPoint, tangent, binormal);
            float3 normal = normalize(cross(binormal, tangent));
            vertexData.vertex.xyz = p;
            vertexData.normal = normal;
        }

        void surf (Input IN, inout SurfaceOutputStandard o) {
            float3 flow = tex2D(_FlowMap, IN.uv_MainTex).rgb;
            flow.xy = flow.xy * 2 - 1;
            flow *= _FlowStrength;
            float noise = tex2D(_FlowMap, IN.uv_MainTex).a;

            float time = _Time.y * _Speed + noise;
            float2 jump = float2(_UJump, _VJump);

            float3 uvwA = FlowUVW(
                IN.uv_MainTex, flow.xy, jump,
                _FlowOffset, _Tiling, time, false
            );
            float3 uvwB = FlowUVW(
                IN.uv_MainTex, flow.xy, jump,
                _FlowOffset, _Tiling, time, true
            );

            float finalHeightScale =
                flow.z * _HeightScaleModulated + _HeightScale;

            float3 dhA =
                UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwA.xy)) *
                (uvwA.z * finalHeightScale);
            float3 dhB =
                UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwB.xy)) *
                (uvwB.z * finalHeightScale);

            /*
            float3 dhA =
                UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwA.xy)) * uvwA.z;
            float3 dhB =
                UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwB.xy)) * uvwB.z;
            */

            o.Normal = normalize(float3(-(dhA.xy + dhB.xy), 1));

            fixed4 texA = tex2D(_MainTex, uvwA.xy) * uvwA.z;
            fixed4 texB = tex2D(_MainTex, uvwB.xy) * uvwB.z;

            fixed4 c = (texA + texB) * _Color;

            o.Albedo = c.rgb;
            //o.Albedo = pow(dhA.z + dhB.z, 2);
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }

    FallBack "Diffuse"
}
