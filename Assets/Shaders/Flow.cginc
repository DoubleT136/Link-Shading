#if !defined(FLOW_INCLUDED)
#define FLOW_INCLUDED

#define PI 3.14159265359

//This function takes in a variety of patterns that affect the direction and phase of animated
//flow vectors and outputs a vector of 3 floats: u and v, which are simply updated texture
//coordinates for the water texture map, and w, a third parameter that acts as a weight that adjusts
//how much a current pattern contributes to the final surface distortion pattern.
float3 FlowUVW (
	float2 uv, float2 flowVector, float2 jump, float flowOffset, float tiling, float time, bool flowB
) {
	//Set the phase offset of the current flow vector to be 0 or 0.5, depending on the pattern
	float phaseOffset = 0;
	if (flowB) phaseOffset = 0.5;

	//How far through a phase our pattern is
	float progress = frac(time + phaseOffset);
	//u and v will be final, adjusted uv values based on our input flow vector
	//and z will be the fraction, or weight, by which we modulate the final output
	//color in order to make a visually appealing looping pattern
	float3 uvw;

	//Adding a flow offset allows the animation to start at a user-defined time
	//and not always at the start of each phase of a pattern
	uvw.xy = uv - flowVector * (progress + flowOffset);

	//Multiply by the amount of tiling we want in our material
	uvw.xy *= tiling;

	//Add phase offset depending on the pattern
	uvw.xy += phaseOffset;
	//Avoid visual sliding by jumping to a new offset between phases
	uvw.xy += (time - progress) * jump;

	//I experimented with using an offset sin wave instead of a sawtooth function, but the
	//sawtooth function ended up looking much better
	//uvw.z = sin(PI * progress);

	//This creates a see-saw function. We use this instead of a sin wave
	//as it provides the required effect of a texture fading in and out
	//yet is not too computationally expensive to compute
	uvw.z = 1 - abs(1 - 2 * progress);

	return uvw;
}

#endif