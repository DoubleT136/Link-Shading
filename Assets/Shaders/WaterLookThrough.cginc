#if !defined(WATER_LOOK_THROUGH)
#define WATER_LOOK_THROUGH

sampler2D _CameraDepthTexture, _BackgroundWater;
float4 _CameraDepthTexture_TexelSize;

float3 _FogColor;
float _FogDensity;

//This function takes in a screen position and outputs the color of the water
//at that position, taking into account the objects underneath the surface, as well as
//the fog density of the liquid
float3 underWaterColor(float4 screenPos) {
	//Get the current UV coordinates by dividing by the w coordinate, to convert from homogenous
	//space back to normal coordinate space (as we often did in class)
	float2 uv = screenPos.xy / screenPos.w;
	//This performs an extra check to make sure that our uv values are not reversed
	#if UNITY_UV_STARTS_AT_TOP
		if (_CameraDepthTexture_TexelSize.y < 0) {
			uv.y = 1 - uv.y;
		}
	#endif
	//Sample a depth texture map to calculate how far away background, underwater objects are
	float backgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	//Calculate how far the surface is from the screen using a special built-in Unity function
	float surfaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(screenPos.z);
	//Subtract distance from screen to surface from distance from screen to background to get
	//the true depth of the underwater objects from the surface. This distance will be used to
	//calculate underwater fog
	float depthDiff = backgroundDepth - surfaceDepth;

	//Sample the texture map that stores the background color before the water is
	//rendered. We can do this since the water is a transparent surface, so gets
	//rendered after all of the opaque objects underneath its surface.
	float3 backgroundColor = tex2D(_BackgroundWater, uv).rgb;
	
	//Using exponential squared fog to get the most realistic results. Other options
	//include linear fog and normal exponential fog, however exponential squared fog
	//seemed to be the most realistic model to use
	float fogFactor = exp2(-(_FogDensity * depthDiff) * (_FogDensity * depthDiff));
	//Lerp between the background color and the fog color to get a smooth final result
	return lerp(_FogColor, backgroundColor, fogFactor);
}

#endif