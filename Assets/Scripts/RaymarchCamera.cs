using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Random = UnityEngine.Random;


[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchCamera : SceneViewFilter
{
    [SerializeField] private Shader shader;

    public Material RaymarchMaterial
    {
        get
        {
            if (!raymarchMaterial && shader)
            {
                raymarchMaterial = new Material(shader);
                raymarchMaterial.hideFlags = HideFlags.HideAndDontSave;
            }

            return raymarchMaterial;
        }
    }
    private Material raymarchMaterial;

    public Camera Camera
    {
        get
        {
            if (!camera)
            {
                camera = GetComponent<Camera>();
            }

            return camera;
        }
    }
    private Camera camera;

    public float maxDistance;
    public Color mainColor;
    public Texture2D objectTexture;
    public Transform directionalLight;
    public Transform cube1;

    private Vector4[] voronoiPositions = new Vector4[50];

    private void OnEnable()
    {
        for (int i = 0; i < voronoiPositions.Length; i++)
        {
            voronoiPositions[i] = new Vector4(Random.Range(0, 1f),Random.Range(0, 1f),Random.Range(0, 1f), 0);
        }
        
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (!RaymarchMaterial)
        {
            Graphics.Blit(src, dest);
            return;
        }
        
        RaymarchMaterial.SetVectorArray("voronoiP", voronoiPositions);
        RaymarchMaterial.SetVector("boxPos", cube1.position);
        RaymarchMaterial.SetVector("boxSize", cube1.localScale / 2);
        RaymarchMaterial.SetColor("mainColor", mainColor);
        RaymarchMaterial.SetTexture("objectTexture", objectTexture);
        RaymarchMaterial.SetVector("lightDir", directionalLight ? directionalLight.forward : Vector3.down);
        RaymarchMaterial.SetMatrix("camFrustum", CamFrustum(Camera));
        RaymarchMaterial.SetMatrix("camToWorld", Camera.cameraToWorldMatrix);
        RaymarchMaterial.SetFloat("maxDistance", maxDistance);
        
        RenderTexture.active = dest;
        RaymarchMaterial.SetTexture("mainTexture", src);
        GL.PushMatrix();
        GL.LoadOrtho();
        RaymarchMaterial.SetPass(0);
        GL.Begin(GL.QUADS);
        
        //BL
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);
        //BR
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        //TR
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        //TL
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);
        
        GL.End();
        GL.PopMatrix();
    }

    private Matrix4x4 CamFrustum(Camera _cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan((_cam.fieldOfView * 0.5f) * Mathf.Deg2Rad);
        
        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * _cam.aspect;

        Vector3 TL = (-Vector3.forward - goRight + goUp);
        Vector3 TR = (-Vector3.forward + goRight + goUp);
        Vector3 BL = (-Vector3.forward - goRight - goUp);
        Vector3 BR = (-Vector3.forward + goRight - goUp);
        
        frustum.SetRow(0, TL);
        frustum.SetRow(1, TR);
        frustum.SetRow(2, BR);
        frustum.SetRow(3, BL);
        
        
        return frustum;
    }
}
