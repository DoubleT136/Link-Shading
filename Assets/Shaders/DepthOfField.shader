Shader "Hidden/DepthOfField" {
	Properties {
		_MainTex ("Texture", 2D) = "white" {}
	}

	CGINCLUDE
		#include "UnityCG.cginc"

		sampler2D _MainTex, _CameraDepthTexture;
		float4 _MainTex_TexelSize;

        float _FocusDistance, _FocusRange, _BokehRadius;

		struct VertexData {
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct Interpolators {
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
		};

		// we don't need to do anything fancy with the vertices
		// just transform from object space to camera space
		Interpolators VertexProgram (VertexData v) {
			Interpolators i;
			i.pos = UnityObjectToClipPos(v.vertex);
			i.uv = v.uv;
			return i;
		}

	ENDCG

	SubShader {
		Cull Off
		ZTest Always
		ZWrite Off

		Pass {  // 0 CircleOfConfusionPass
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half4 FragmentProgram (Interpolators i) : SV_Target {
					half depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                    // returns depth in camera space
					depth = LinearEyeDepth(depth);

                    // CoC represents how out of focus a fragment is,
                    // with values between -1 and 1
                    float coc = (depth - _FocusDistance) / _FocusRange;
                    coc = clamp(coc, -1, 1) * _BokehRadius;

					return half4(tex2D(_MainTex, i.uv).rgb, coc);
				}
			ENDCG
		}

        Pass {  // 1 bokehPass
            CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

                // From https://github.com/Unity-Technologies/PostProcessing/
				// blob/v2/PostProcessing/Shaders/Builtins/DiskKernels.hlsl
                // This cotanis offset within the unit circle and defines
                // the 22 samples needed per fragment for the bokeh ring.
				static const int kernelSampleCount = 22;
                static const float2 kernel[kernelSampleCount] = {
                    float2(0, 0),
                    float2(0.53333336, 0),
                    float2(0.3325279, 0.4169768),
                    float2(-0.11867785, 0.5199616),
                    float2(-0.48051673, 0.2314047),
                    float2(-0.48051673, -0.23140468),
                    float2(-0.11867763, -0.51996166),
                    float2(0.33252785, -0.4169769),
                    float2(1, 0),
                    float2(0.90096885, 0.43388376),
                    float2(0.6234898, 0.7818315),
                    float2(0.22252098, 0.9749279),
                    float2(-0.22252095, 0.9749279),
                    float2(-0.62349, 0.7818314),
                    float2(-0.90096885, 0.43388382),
                    float2(-1, 0),
                    float2(-0.90096885, -0.43388376),
                    float2(-0.6234896, -0.7818316),
                    float2(-0.22252055, -0.974928),
                    float2(0.2225215, -0.9749278),
                    float2(0.6234897, -0.7818316),
                    float2(0.90096885, -0.43388376),
                };

				// Samples in the same ring of kernel tend to have roughly the
				// same Kernel value, so we use a weighting depending on CoC
				// and offset, cmaping to 0-1. Adding a small offset and 
				// dividing by it turns it into a steep ramp with smooth
				// transiitions.
                half Weigh (half coc, half radius) {
					return saturate((coc - radius + 2) / 2);
				}

				half4 FragmentProgram (Interpolators i) : SV_Target {
					half3 color = 0;
                    float weight = 0;
					for (int k = 0; k < kernelSampleCount; k++) {
						float2 o = kernel[k] * _BokehRadius;
                        half radius = length(o);
                        o *= _MainTex_TexelSize.xy;
						half4 s = tex2D(_MainTex, i.uv + o);

                        half sw = Weigh(abs(s.a), radius);
						color += s.rgb * sw;
						weight += sw;
					}
					color *= 1.0 / weight;
					return half4(color, 1);
				}
			ENDCG
		}

        Pass { // 2 postFilterPass
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half4 FragmentProgram (Interpolators i) : SV_Target {
					// perfom a Gaussian blur using a box filter.
					float4 o = _MainTex_TexelSize.xyxy * float2(-0.5, 0.5).xxyy;
					half4 s =
						tex2D(_MainTex, i.uv + o.xy) +
						tex2D(_MainTex, i.uv + o.zy) +
						tex2D(_MainTex, i.uv + o.xw) +
						tex2D(_MainTex, i.uv + o.zw);
					return s * 0.25;
				}
			ENDCG
		}
	}
}