// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


//This shader was originally created by the awesome Danish tech/Artist Mikkel S.
//Shader has later been modified by Jesper K.


Shader "Mikkel_LightMapped_1map" {
	Properties {
		_Color ("Main Color (RGB)", Color) = (1,1,1,1)
		_RimColor ("Rim Color (RGB)", Color) = (1,1,1,1)
		_RimFalloff ("Rim Falloff", Range(0.5,8)) = 1
		_MainTex ("MainTex (RGB)", 2D) = "white" {}
		_LightMap ("Additive Lightmap (RGB)", 2D) = "white" {}
	}

SubShader {
	Pass {
	
								
		CGPROGRAM
		
		
		//Vert program name
		#pragma vertex vert
		//Frag program name
		#pragma fragment frag
		//Platform target, directx 9 = 3.0, directx 11 = 5.0
		#pragma target 3.0
		//Always include this thing
		#pragma glsl

		//#include is to include a library of off-file functions
		#include "UnityCG.cginc"

		//This is where we drag stuff into the VRAM, using the property types and names
		//These specifics are textures (sampler2D)
		sampler2D _MainTex;
		sampler2D _LightMap;
				
		//These corespond to the names of the textures, and are always float4s. They need to be put into ram in order to tile and offset
		float4 _MainTex_ST;
		
		//Here we import a dataset, and call that set appdata_t
		struct appdata_t {
			//We first enter the datatype, then the name : and the imported data
			//This example is named vertex (My name) and it's the position data of the model
			float4 vertex : POSITION;
			//This is the imported texture coordinates, or unwraps. 0 is 1 in max, and 1 is 2. Max isn't zero-indexed.
			float2 texcoord_light : TEXCOORD1;
			float2 texcoord_main : TEXCOORD0;
			float3 normal : NORMAL;
			//This is imported color info from the vertisies.
			float4 color : COLOR;
		};

		//Here we define what goes from the vertex program to the fragment program. We just define data types and names like last time.
		struct v2f {
			float4 vertex : POSITION;
			//This time, unlike above we just name them 0, 1, 2 because they have to be different.
			float2 texcoord_light : TEXCOORD0;
			float2 texcoord_r : TEXCOORD1;
			float rim : TEXCOORD3;
			float4 color : COLOR;
		};

		//Now the fun, this is the vert program. We take in data and do calculations on the vertisies. We named it vert above, we transfer the v2f data, and use the input appdata_t, which we define the prefix "v"
		v2f vert (appdata_t v)
		{
			//v2f o defines that we're working on the v2f dataset, and calling it o in here. o stands for out, as in output
			v2f o;
			//Every vert shader has to do this, it projects the vertesies into screen space
			o.vertex = UnityObjectToClipPos(v.vertex);

			//Here we take the unwraps/texcoords and apply the tile/offset using the names of the textures, and the function TRANSFORM_TEX. You can find that function inside UnityCG.cginc. It demands a float2(the coords) and a texture
			o.texcoord_r = TRANSFORM_TEX(v.texcoord_main,_MainTex);
		
			//Here we simply output the lightmap coords using our names
			o.texcoord_light = v.texcoord_light;

			//This rimlight function is magic, don't attempt to understand.
			o.rim = 1 - dot(normalize(WorldSpaceViewDir(v.vertex)), normalize(mul(unity_ObjectToWorld, float4(v.normal,0))));

			//Here we simply output the vertex colors
			o.color = v.color;
			return o;
		}

		float4 _Color;
		float3 _RimColor;
		float _RimFalloff;

		//Here we start the frag program. It's the pixel shader. The v2f data we prefix with i, : COLOR? Idunno about that.
		fixed4 frag (v2f i) : COLOR
		{
			//Here we do something we didn't do in vert, we create data in the type hafl3, half is 16-bit floats, float is 32-bit. 3 defines that it's three components (RGB in this case, XYZ in others)
			//tex2D is a function that requires the texture, and a coordinate/unwrap
			half3 texsample_r = tex2D(_MainTex, i.texcoord_r);
			half3 texsample_light = tex2D(_LightMap, i.texcoord_light);

			//Here we power and color the rimlight
			half3 rim = pow(i.rim * _RimColor.rgb, _RimFalloff);

			//Now we just do a lerp function which is linear interpolate, it requres the first color, the second color (Our two textures) and the blend value, which we just set to be the green vertex color
			//After that we multiply it by the lightmap multiplied by 2 (Brighter) and multiplied by the color (Darker and tinted)
			
			half3 outcol = texsample_r * texsample_light * 2 * _Color.rgb;
			
			//And now we add the rimlight tinted with lightmap
			outcol += rim * texsample_light;
			//Now we return the data, create a fixed4, which we use as color and alpha. We give it the color we just made (Two textures and a lightmap), and give it alpha 1 (Fully opaqge)
			return fixed4(outcol,1);
		}
		//THAT'S IT! STEAL IT!

		ENDCG

	}
}

FallBack "VDiffuse"

}