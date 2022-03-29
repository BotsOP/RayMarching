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

    private Material RaymarchMaterial
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

    [Header("Raymarcher")]
    [SerializeField] private float maxDistance;
    [SerializeField] private int maxIterations;
    [SerializeField] private float accuracy;
    
    [Header("Directional light")]
    [SerializeField] private Transform directionalLight;
    [SerializeField] private Color lightColor;
    [SerializeField] private float lightIntensity;

    [Header("Shadow")] 
    [SerializeField] private float shadowIntensity;
    [SerializeField] private Vector2 shadowDistance;
    [SerializeField] private float shadowPenumbra;

    [Header("Ambient Occlusion")] 
    [SerializeField] private float aoStepSize;
    [SerializeField] private int aoIterations;
    [SerializeField] private float aoIntesity;

    [Header("Signed distance fields")]
    [SerializeField] private Color mainColor;
    [SerializeField] private Texture2D objectTexture;
    [SerializeField] private Transform cube1;
    [SerializeField] private Transform[] planets;
    [SerializeField] private float[] planetsSpeed;
    [SerializeField] private float[] planetsRotationSpeed;

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (!RaymarchMaterial)
        {
            Graphics.Blit(src, dest);
            return;
        }

        Vector4[] planetsPos = new Vector4[8];
        for (int i = 0; i < 8; i++)
        {
            planetsPos[i] = planets[i].position;
        }
        
        RaymarchMaterial.SetFloat("maxDistance", maxDistance);
        RaymarchMaterial.SetInt("maxIterations", maxIterations);
        RaymarchMaterial.SetFloat("accuracy", accuracy);
        
        RaymarchMaterial.SetVectorArray("ballPos", planetsPos);
        RaymarchMaterial.SetFloatArray("ballSpeed", planetsSpeed);
        RaymarchMaterial.SetFloatArray("ballRotationSpeed", planetsRotationSpeed);
        RaymarchMaterial.SetVector("ballPos1", cube1.position);
        RaymarchMaterial.SetVector("boxSize", cube1.localScale / 2);
        RaymarchMaterial.SetColor("mainColor", mainColor);
        RaymarchMaterial.SetTexture("objectTexture", objectTexture);
        
        //RaymarchMaterial.SetVector("lightDir", directionalLight ? directionalLight.forward : Vector3.down);
        RaymarchMaterial.SetColor("lightCol", lightColor);
        RaymarchMaterial.SetFloat("lightIntensity", lightIntensity);
        RaymarchMaterial.SetFloat("shadowIntensity", shadowIntensity);
        RaymarchMaterial.SetVector("shadowDistance", shadowDistance);
        RaymarchMaterial.SetFloat("shadowPenumbra", shadowPenumbra);
        
        RaymarchMaterial.SetFloat("aoStepSize", aoStepSize);
        RaymarchMaterial.SetFloat("aoIntensity", aoIntesity);
        RaymarchMaterial.SetInt("aoIterations", aoIterations);
        
        RaymarchMaterial.SetMatrix("camFrustum", CamFrustum(Camera));
        RaymarchMaterial.SetMatrix("camToWorld", Camera.cameraToWorldMatrix);
        
        
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
