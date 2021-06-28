﻿#if OPENGL
	#define SV_POSITION POSITION
	#define VS_SHADERMODEL vs_3_0
	#define PS_SHADERMODEL ps_3_0
#else
	#define VS_SHADERMODEL vs_4_0_level_9_1
	#define PS_SHADERMODEL ps_4_0_level_9_1
#endif

//Change this value depending on how much point lights you might have in one place in your project
static const int MAX_POINT_LIGHTS  = 16;

//Change this value depending on how much spot lights you might have in one place in your project
#define MAX_SPOT_LIGHTS 8

//Directional light can only have one ACTIVE instance per scene

matrix WorldViewProjection;

float4x4 World;
float4x4 View;
float4x4 Projection;
float4x4 WorldInverseTranspose;

float4 AmbientLightColor;
float AmbientLightIntensity;

texture BaseTexture;

sampler2D textureSampler = sampler_state
{
	Texture = (BaseTexture);
	MagFilter = Linear;
	MinFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
};

struct VertexShaderInput
{
	float4 Position : POSITION0;
	float4 Color : COLOR0;
	float2 TextureCoordinate:TEXCOORD0;
	float4 Normal:NORMAL0;
};

struct VertexShaderOutput
{
	float4 Position : SV_POSITION;
	float4 Color : COLOR0;
	float2 TextureCoordinate : TEXCOORD0;
	float3 WorldPos : TEXCOORD2;
	float4 Normal:NORMAL0;
};

//point lights data. Not using structs because they tend to cause "shader has corrupt ctab data" error during shader compilation
float4 pointLightsColor[MAX_POINT_LIGHTS];
float3 pointLightsLocation[MAX_POINT_LIGHTS];
float pointLightsIntensity[MAX_POINT_LIGHTS];
bool pointLightsValid[MAX_POINT_LIGHTS];

float Vec3LenghtSquared(float3 vec)
{
	return vec.x*vec.x+vec.y*vec.y+vec.z*vec.z;
}

VertexShaderOutput MainVS(in VertexShaderInput input)
{
	VertexShaderOutput output = (VertexShaderOutput)0;

	float4 worldPosition = mul(input.Position, World);
    float4 viewPosition = mul(worldPosition, View);
	output.Position = mul(viewPosition,Projection);

	float4 normal = mul(input.Normal,WorldInverseTranspose);

	output.WorldPos = mul(input.Position,World).xyz;
	
	//output.Position = mul(input.Position, WorldViewProjection);
	output.Color = AmbientLightColor*AmbientLightIntensity;

	output.TextureCoordinate=input.TextureCoordinate;

	output.Normal = normal;

	float4 resultColor = output.Color;
	for(int i = 0; i < MAX_POINT_LIGHTS; i++)
	{
		if(pointLightsValid[i] == true)
		{
			float3 pointLightDirection = output.WorldPos - pointLightsLocation[i];
			float distance = sqrt(Vec3LenghtSquared(pointLightDirection));
			if(distance > 0)
			{
				pointLightDirection /= distance;
				
				float res = saturate(dot(normal,-pointLightDirection));
				//dot(input.Normal,-pointLightDirection) <- causes freezing, removing input.Normal seems to have good effect
				//resultColor += pointLightsColor[i]*pointLightsIntensity[i]; // doesn't freeze the game
				//resultColor += saturate(dot(input.Normal,-pointLightDirection))*pointLightsIntensity[i]*pointLightsColor[i]; // freezes the game
				resultColor += res* pointLightsColor[i]*pointLightsIntensity[i]; // freezes the game
				//resultColor += pointLightsColor[i]*pointLightsIntensity[i]*cos(clamp(dot(input.Normal,pointLightDirection),0,1));resultColor += pointLightsColor[i]*pointLightsIntensity[i];
				
			}
		}
				
	}
	output.Color += resultColor;

	return output;
}



float3 CalculatePointLight(float3 pointLightColor,float3 pointLightLocation,float pointLightIntensity, VertexShaderOutput input)
{
	float3 pointLightDirection = input.WorldPos - pointLightLocation;
	float distanceSq = Vec3LenghtSquared(pointLightDirection);

	float distance = sqrt(distanceSq);
	pointLightDirection /= distance;
	return pointLightColor*pointLightIntensity*1*cos(clamp(dot(input.Normal,pointLightDirection),0,1));
}

float4 MainPS(VertexShaderOutput input) : COLOR
{
	
	//return tex2D(textureSampler, input.TextureCoordinate)*(AmbientLightColor + resultColor);
	return (input.Color + AmbientLightColor*AmbientLightIntensity) * tex2D(textureSampler, input.TextureCoordinate);
}

technique BasicTexture
{
	pass P0
	{
		VertexShader = compile VS_SHADERMODEL MainVS();
		PixelShader = compile PS_SHADERMODEL MainPS();
	}
};