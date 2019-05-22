using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class raftMovement : MonoBehaviour
{

	float rotSpeed = 2.0f;
	float cameraRotSpeed = 2.0f;

	private float m_TiltMax = 75f;                       // The maximum value of the x axis rotation of the pivot.
    private float m_TiltMin = 45f;

	public Camera camera;

	//Vector3 currDist = new Vector3(0.0f, 0.0f, 0.0f);
	Vector3 cameraRotAxis = new Vector3(0.0f, 1.0f, 0.0f);
	Vector3 testPoint = new Vector3(0.0f, 0.0f, 0.0f);

    // Start is called before the first frame update
    void Start()
    {
        //currDist = camera.transform.position - transform.position;

        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    // Update is called once per frame
    void Update()
    {
    	//camera.transform.position = transform.position + currDist;

        float w = Input.GetAxis("Horizontal");
        float h = Input.GetAxis("Vertical");

        var x = Input.GetAxis("Mouse X");
        var y = Input.GetAxis("Mouse Y");

        transform.Translate(0,0,-h * Time.deltaTime * 10);

        // Rotate the rig (the root object) around Y axis only
        transform.Rotate(0f, w * rotSpeed, 0f);

        // float newAng = Mathf.Clamp(y, -m_TiltMin, m_TiltMax);

        // camera.transform.Rotate(newAng * cameraRotSpeed * -1, 0f, 0f);

        // camera.transform.Rotate(0f, 0f, x * cameraRotSpeed);

    }
}
