#if !defined(WATER_LOOK_THROUGH)
#define WATER_LOOK_THROUGH

sampler2D _CameraDepthTexture;

float3 underWaterColor(float4 screenPos) {
	float2 uv = screenPos.xy / screenPos.w;
	float backgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	float surfaceDepth = UNITY_Z_O_FAR_FROM_CLIPSPACE(screenPos);
	float depthDifference = backgroundDepth - surfaceDepth;
	
	return depthDifference/30;
}

#endif