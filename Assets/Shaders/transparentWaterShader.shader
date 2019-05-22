Shader "Custom/Transparent Water Shader" {
    Properties {
        //This list of properties contains all of the properties used for the
        //distorted water texture, the directional waves and the transparency
        //and fog effects.
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
        _WaveB ("Wave B (dir, steepness, waveNumber)", Vector) = (0.5, 1.5, 8)
        _FogColor ("Fog Color", Color) = (0, 0, 0, 0)
        _FogDensity ("Fog Density", Range(0, 5)) = 0.1
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
        LOD 200

        GrabPass { "_BackgroundWater" }

        CGPROGRAM
        #pragma surface surf Standard alpha vertex:vertexFunc addshadow finalcolor:alphaReset
        #pragma target 3.0

        #include "Flow.cginc"
        #include "WaterLookThrough.cginc"

        sampler2D _MainTex, _FlowMap, _DerivHeightMap;
        float _UJump, _VJump, _Tiling, _Speed, _FlowStrength, _FlowOffset, _Amplitude;

        float4 _WaveA, _WaveB;

        float _HeightScale, _HeightScaleModulated;

        struct Input {
            float2 uv_MainTex;
            float4 screenPos;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        //Returns derivative data from the derivative texture
        float3 UnpackDerivativeHeight (float4 textureData) {
            //The x derivative is stored in the alpha channel, the y derivative
            //is stored in the g channel, and the original height is stored in the
            //b channel, although we won't be using that in this implementation
            float3 dh = textureData.agb;
            //Normal conversion from normal map to coordinate space by multiplying
            //by 2 and subtracting 1
            dh.xy = dh.xy * 2 - 1;
            return dh;
        }

        //This functions models a Gerstner wave, which is a realistic model for
        //water waves. In a Gerstner wave particles actually travel in a small circle
        //instead of just changing their vertical displacement over time
        float3 GerstnerWave (
            float4 wave, float3 p, inout float3 tangent, inout float3 binormal
        ) {
            float steepness = wave.z;
            float k = wave.w;
            //Natural speed of waves due to gravity
            float c = sqrt(9.8 / k);
            //Normalized direction that we want the wave to travel in
            float2 d = normalize(wave.xy);
            //Dot product allows us to easily incorporate x and z direction information
            float f = k * (dot(d, p.xz) - c * _Time.y);
            float a = steepness / k;

            //Calculate the tangent vector at the current vertex. We are adding here
            //as this vector may be added to multiple tangents from other waves
            tangent += float3(
                -d.x * d.x * (steepness * sin(f)),
                d.x * (steepness * cos(f)),
                -d.x * d.y * (steepness * sin(f))
            );
            //Calculate the birnomal vector as the current vertex, which is in the
            //z direction. We can now calculate the normal vector at the current vertex
            //by taking the cross product between the tangent and binormal vectors.
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

        //This function takes in the data of a single vertex and outputs updated
        //vertex positions and normals. It updates the vertex with position and normal
        //information from a combination of two Gerstner waves - wave A and wave B. I
        //experimented with adding more waves but the surface became so chaotic that I
        //decided to cut my final wave down to a combination of only 2.
        void vertexFunc(inout appdata_full vertexData) {
            float3 gridPoint = vertexData.vertex.xyz;
            float3 tangent = float3(1, 0, 0);
            float3 binormal = float3(0, 0, 1);
            float3 p = gridPoint;
            p += GerstnerWave(_WaveA, gridPoint, tangent, binormal);
            p += GerstnerWave(_WaveB, gridPoint, tangent, binormal);
            float3 normal = normalize(cross(binormal, tangent));
            vertexData.vertex.xyz = p;
            vertexData.normal = normal;
        }

        void surf (Input IN, inout SurfaceOutputStandard o) {
            //In order to get flow in various directions we sample from a flow map
            //which takes the form of an RGBA image where R and G represent flow
            //vector directions, B represents flow speed and A represents noise
            float3 flow = tex2D(_FlowMap, IN.uv_MainTex).rgb;

            //Decode the flow vector as if it were a normal map
            flow.xy = flow.xy * 2 - 1;
            //Multiply by a user-set flow strength parameter
            flow *= _FlowStrength;
            //Add in a noise sample in order to remove the black pulsing
            //effect of the waves
            float noise = tex2D(_FlowMap, IN.uv_MainTex).a;

            //Combine time and noise offset in order to create non-uniform
            //pulsing in different areas of the water surface
            float time = _Time.y * _Speed + noise;
            float2 uvJump = float2(_UJump, _VJump);

            //Obtain the flow-adjusted UV coordinates for both pattern A and B
            float3 uvwA = FlowUVW(
                IN.uv_MainTex, flow.xy, uvJump,
                _FlowOffset, _Tiling, time, false
            );
            //Set the final Boolean to true to indicate that we are dealing with
            //pattern B
            float3 uvwB = FlowUVW(
                IN.uv_MainTex, flow.xy, uvJump,
                _FlowOffset, _Tiling, time, true
            );

            //Based off of the idea that you get higher waves where there is strong flow
            //modulate the height of the distortion based on flow speed. Adding a height
            //scale to this product also allows us to have some height when there is no
            //flow, which is much more realistic as waves don't just become flat when they
            //stop flowing. We use flow.z as this is obtained from the B, or speed channel
            //of our flow map
            float modulatedHeightScale =
                flow.z * _HeightScaleModulated + _HeightScale;

            //Calculate x and y derivatives for pattern A
            float3 heightDerivA =
                UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwA.xy)) *
                (uvwA.z * modulatedHeightScale);
            //Calculate x and y derivatives for pattern B
            float3 heightDerivB =
                UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwB.xy)) *
                (uvwB.z * modulatedHeightScale);

            //Calculate the new normal for the fragment based on the two height
            //derivatives for patterns A and B. The normal plays a big role in making
            //us think that the water is flowing in a specific direction
            o.Normal = normalize(float3(-(heightDerivA.xy + heightDerivB.xy), 1));

            //We sample 2 separate pattern that are offset from each other by half a phase
            //so that we never see either one fade out to black
            fixed4 patternA = tex2D(_MainTex, uvwA.xy) * uvwA.z;
            fixed4 patternB = tex2D(_MainTex, uvwB.xy) * uvwB.z;

            //The overall color of the fragment is a combination of these two patterns
            //multiplied by the color we want the wave to be
            fixed4 c = (patternA + patternB) * _Color;

            //Can set metallic and smoothness parameters based on what the user
            //specified in the Unity editor
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            
            //Set albedo
            o.Albedo = c.rgb;
            o.Alpha = c.a;

            //Use the underwater as an emissive color in order to add it to surface
            //lighting. We must still modulate by the fragment's albedo in order to
            //create the correct effect
            o.Emission = underWaterColor(IN.screenPos) * (1 - c.a);
        }

        //This function is automatically called after rendering and sets the alpha
        //back to 1 after all fragments have been processed. We need to do this since
        //the alpha value we use in the surface shader is already blended with the
        //background, and we do not want to do this blending twice!
        void alphaReset (Input IN, SurfaceOutputStandard o, inout fixed4 color) {
            color.a = 1;
        }

        ENDCG
    }

}
