Shader "BotsOP/RaymarchShader"
{
    Properties
    {
        mainTexture ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "DistanceFunctions.cginc"
            #include "Noise.cginc"

            sampler2D mainTexture;
            sampler2D objectTexture;
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 camFrustum, camToWorld;

            uniform float3 boxPos;
            uniform float3 boxSize;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                half index = v.vertex.z;
                v.vertex.z = 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.ray = camFrustum[(int)index].xyz;

                o.ray /= abs(o.ray.z);

                o.ray = mul(camToWorld, o.ray);
                
                return o;
            }

            float ballGyroid(float3 p, float density, float thickness)
            {
                p.z *= Rotx(_Time);
                p *= density;
                return abs(0.7 * dot(sin(p), cos(p.zxy))/10) - thickness;
            }

            float DistLine(float2 p, float2 a, float2 b)
            {
                float2 pa = p - a;
                float2 ba = b - a;
                float t = clamp(dot(pa, ba)/dot(ba, ba), 0, 1);
                return length(pa - ba * t);
            }

            float distanceField(float3 p)
            {
                float sphere1 = sdSphere(p, 1 );
                float gyroid = ballGyroid(p - boxPos, 10, 0.03);
                float plane = p.y + 1.06;
                
                float ballGyroid = sMin(abs(sphere1) - 0.02, gyroid, -0.03);
                return ballGyroid;
            }

            float3 getNormal(float3 p)
            {
                const float2 offset = float2(0.001, 0.0);
                float d = distanceField(p);
                
                float3 n = d - float3(
                    distanceField(p - offset.xyy),
                    distanceField(p - offset.yxy),
                    distanceField(p - offset.yyx)
                    );
                
                return normalize(n);
            }

            uniform float2 shadowDistance;
            uniform float shadowIntensity, shadowPenumbra;

            float softShadow(float3 ro, float3 rd, float mint, float maxt, float k, float3 n)
            {
                float result = 1;
                for (float t = mint; t < maxt;)
                {
                    float h = distanceField(ro + rd * t);
                    
                    if(h < 0.01)
                    {
                        return 0.0;
                    }
                    result = min(result, k * h / t);
                    t += h;
                }
                //return result;
                return result * clamp(dot(n, rd), 0, 1);
            }

            uniform float aoStepSize, aoIntensity;
            uniform int aoIterations;

            float AmbientOcclusion(float3 p, float3 n)
            {
                float step = aoStepSize;
                float ao = 0.0;
                float dist;
                
                for (int i = 1; i <= aoIterations; i++)
                {
                    dist = step * i;
                    ao += max(0.0, (dist - distanceField(p + n * dist)) / dist);
                }

                return (1.0 - ao * aoIntensity);
            }

            uniform float3 lightDir, lightCol;
            uniform float lightIntensity;
            uniform fixed4 mainColor;

            float3 GetLight(float3 p)
            {
                float3 result;
                
                float3 l = -normalize(p);
                float3 n = getNormal(p);

                float3 diff = (lightCol * dot(n, l) * 0.5 + 0.5) * lightIntensity;
                
                float shadow = softShadow(p, l, shadowDistance.x, shadowDistance.y, shadowPenumbra, n) * 0.5 + 0.5;
                shadow = max(0, pow(shadow, shadowIntensity));

                float ao = AmbientOcclusion(p, n);
                
                result = diff * shadow * ao;
                
                if(length(p) > 1.04)
                {
                    return result;
                }

                return diff * ao;
            }

            uniform int maxIterations;
            uniform float accuracy;
            uniform float maxDistance;

            fixed4 raymarching(float3 rayOrigin, float3 rayDirection, float depth)
            {
                //throw this all away
                fixed4 result = fixed4(1,1,1,0);
                float t = 0;
                float d = 0;
                float3 n = float3(1,1,1);
                
                for (int i = 0; i < maxIterations; i++)
                {
                    if(t > maxDistance || t >= depth)
                    {
                        //environment
                        result = fixed4(rayDirection, 0);
                        break;
                    }

                    float3 p = (rayOrigin + rayDirection * t);
                    d = distanceField(p);
                    
                    if(d < accuracy)
                    {
                        float3 s = GetLight(p);
                        
                        result = fixed4(s, 1);
                        break;
                    }
                    t += d;
                }

                // n = abs(n);
                // n = pow(n,5);
                // n = normalize(n);
                //
                // float4 colXY = tex2D(objectTexture, p.xy - boxPos.xy + 0.5);
                // float4 colYZ = tex2D(objectTexture, p.yz - boxPos.yz  + 0.5);
                // float4 colXZ = tex2D(objectTexture, p.xz - boxPos.xz  + 0.5);
                // float4 color = colXY * n.z + colYZ * n.x + colXZ * n.y;
                
                //return fixed4(fixed3(d,d,d), result.w);
                //result = fixed4(color.rgb, result.w);
                
                return result;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
                depth *= length(i.ray);
                fixed3 col = tex2D(mainTexture, i.uv);

                // float cd = length(i.uv - float2(0.5,0.5));
                // float light = 0.1 / cd;
                // col += light;
                
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin, rayDirection, depth);
                return fixed4(col * (1.0 - result.w) + result.xyz * result.w,1.0);
            }
            ENDCG
        }
    }
}

































