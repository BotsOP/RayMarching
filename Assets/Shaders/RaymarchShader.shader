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
            uniform float maxDistance;
            uniform float3 lightDir;
            uniform fixed4 mainColor;
            uniform float3 p;
            uniform float4 voronoiP[50];
            float distP;

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

            float2 N22(float2 p)
            {
                float2 a = frac(p.xy * float3(123.34, 234.34, 345.65));
                a += dot(a, a+34.45);
                return frac(float2(a.x*a.y, a.y*a.x));
            }

            float voronoiGenerator(float3 p, float3 offset)
            {
                float d = 1;
                float d2 = 2;
                p -= offset;
                for (int i = 0; i < 10; i++)
                {
                    if(length(p - voronoiP[i]) < d)
                    {
                        d2 = d;
                        d = length(p - voronoiP[i]);
                    }
                }
                if(d2 > d - 0.02 && d2 < d + 0.02 && d < 5)
                {
                    return -1;
                }
                return d - 0.1;
            }

            float ballGyroid(float3 p)
            {
                p *= 10;
                return abs(0.7 * dot(sin(p), cos(p.zxy))/10) - 0.02;
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
                float Sphere1 = sdSphere(p, 1 );
                float box = sdBox(p, float3(2,2,2));
                float3 wNoiseD = WNoise((p - boxPos) * 10, _Time * 2).xyz;
                float d = wNoiseD.x;
                float d2 = wNoiseD.y;
                if(abs(d - d2) < 0.2)
                {
                    d = -1;
                }
                else
                {
                    d = 1;
                }
                float sNoiseD = TNoise((p - boxPos), _Time, 1);
                float d1 = sNoiseD;
                //return Sphere1;
                return box;
                return max(Sphere1, box);
                
                // float d2 = noiseD.y;
                // d = d + d2 - 0.5;
                // return sMin(Sphere1, d.x, -0.1);
                //float voronoi = voronoiGenerator(p, boxPos);
                
                // float Sphere1 = abs(sdSphere(p - fixed3(0,0,0), 1)) - 0.03;
                // float g = ballGyroid(p + boxPos);
                // return smin(Sphere1, g, -0.03);
            }

            float3 getNormal(float3 p)
            {
                const float2 offset = float2(0.001, 0.0);
                float3 n = float3(
                    distanceField(p + offset.xyy) - distanceField(p - offset.xyy),
                    distanceField(p + offset.yxy) - distanceField(p - offset.yxy),
                    distanceField(p + offset.yyx) - distanceField(p - offset.yyx)
                    );
                return normalize(n);
            }

            fixed4 raymarching(float3 rayOrigin, float3 rayDirection, float depth)
            {
                //throw this all away
                fixed4 result = fixed4(1,1,1,1);
                const int maxIteration = 100;
                float t = 0;
                float d = 0;
                p = float3(1,1,1);
                float3 n = float3(1,1,1);
                
                for (int i = 0; i < maxIteration; i++)
                {
                    if(t > maxDistance || t >= depth)
                    {
                        //environment
                        result = fixed4(rayDirection, 0);
                        break;
                    }

                    p = (rayOrigin + rayDirection * t);
                    d = distanceField(p);

                    
                    
                    if(d < 0.01)
                    {
                        //shading!
                        n = getNormal(p);
                        float light = dot(-lightDir, n);
                        
                        //result = fixed4(col, col, col,col);
                        result = fixed4(p, 1);
                        result = fixed4(light, light, light,1);
                        break;
                    }
                    t += d;
                }

                n = abs(n);
                n = pow(n,5);
                n = normalize(n);
                
                float4 colXY = tex2D(objectTexture, p.xy - boxPos.xy + 0.5);
                float4 colYZ = tex2D(objectTexture, p.yz - boxPos.yz  + 0.5);
                float4 colXZ = tex2D(objectTexture, p.xz - boxPos.xz  + 0.5);
                float4 color = colXY * n.z + colYZ * n.x + colXZ * n.y;
                d = d / 100 ;
                //return fixed4(fixed3(d,d,d), result.w);
                //result = fixed4(color.rgb, result.w);
                
                return result;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
                depth *= length(i.ray);
                fixed3 col = tex2D(mainTexture, i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin, rayDirection, depth);
                return fixed4(col * (1.0 - result.w) + result.xyz * result.w,1.0);
            }
            ENDCG
        }
    }
}

































