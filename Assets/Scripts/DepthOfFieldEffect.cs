using UnityEngine;
using System;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class DepthOfFieldEffect : MonoBehaviour {
    const int circleOfConfusionPass = 0;
    const int bokehPass = 1;
    const int postFilterPass = 2;

	[HideInInspector]
	public Shader dofShader;

	[NonSerialized]
	Material dofMaterial;

    // Distance between camera and focus plane
    [Range(0.1f, 100f)]
	public float focusDistance = 10f;

    // Range where object is in focus relative to focusDistance
    [Range(0.1f, 100f)]
	public float focusRange = 30f;

    [Range(1f, 20f)]
	public float bokehRadius = 8f;



	void OnRenderImage (RenderTexture source, RenderTexture destination) {
        dofMaterial = new Material(dofShader);
        dofMaterial.hideFlags = HideFlags.HideAndDontSave;

        // Pass variables to shader
        dofMaterial.SetFloat("_FocusDistance", focusDistance);
		dofMaterial.SetFloat("_FocusRange", focusRange);
        dofMaterial.SetFloat("_BokehRadius", bokehRadius);

        // Allocate a temporary render texture to store CoC after first pass
        // Use RenderTextureFormat.RHalf to store a single float,
        // enforced by RenderTextureReadWrite.Linear 
        RenderTexture coc = RenderTexture.GetTemporary(
			source.width, source.height, 0, source.format
		);

        // Allocate another buffer to store temporary result of bokehPass
        // before box filtering in tmp
		RenderTexture tmp = RenderTexture.GetTemporary(
            source.width, source.height, 0, source.format
        );

        // Each Blit call performs 1 pass of a part of the dof shader
        // and stores the result in the RenderTexture provided.
		Graphics.Blit(source, coc, dofMaterial, circleOfConfusionPass);
        Graphics.Blit(coc, tmp, dofMaterial, bokehPass);
        Graphics.Blit(tmp, destination, dofMaterial, postFilterPass);

        RenderTexture.ReleaseTemporary(coc);
        RenderTexture.ReleaseTemporary(tmp);
	}
}