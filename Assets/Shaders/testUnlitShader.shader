Shader "Custom/My First Shader" {

    SubShader {
        Pass {
            CGPROGRAM

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            float4 MyVertexProgram (float4 position : POSITION) : SV_POSITION {
                return position;
            }

            float4 MyFragmentProgram (
                float4 position : SV_POSITION
            ) : SV_TARGET {
                return 0;
            }

            ENDCG
        }
    }
}
