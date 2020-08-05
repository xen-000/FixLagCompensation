#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name 			= "FixLagCompensation",
	author 			= "BotoX + xen(CS:GO support)",
	description 	= "Disable player hitbox lag compensation when on moving objects",
	version 		= "1.0",
	url 			= ""
};

Handle g_hBacktrackPlayer;
Handle g_hBacktrackEntity;
Handle g_hIsMoving;

public void OnPluginStart()
{
	Handle hGameData = LoadGameConfigFile("FixLagCompensation.games");
	if(!hGameData)
		SetFailState("Failed to load FixLagCompensation gamedata.");

	if (GetEngineVersion() != Engine_CSGO)
	{
		// void CLagCompensationManager::BacktrackPlayer( CBasePlayer *pPlayer, float flTargetTime )
		g_hBacktrackPlayer = DHookCreateFromConf(hGameData, "CLagCompensationManager__BacktrackPlayer");
		if(!g_hBacktrackPlayer)
		{
			delete hGameData;
			SetFailState("Failed to setup detour for CLagCompensationManager__BacktrackPlayer");
		}

		if(!DHookEnableDetour(g_hBacktrackPlayer, false, Detour_OnBacktrackPlayer))
		{
			delete hGameData;
			SetFailState("Failed to detour CLagCompensationManager__BacktrackPlayer.");
		}
	}
	else
	{
		// bool CLagCompensationManager::BacktrackEntity( CBaseEntity *entity, float flTargetTime, LagRecordList *track, LagRecord *restore, LagRecord *change, bool wantsAnims )
		g_hBacktrackEntity = DHookCreateFromConf(hGameData, "CLagCompensationManager__BacktrackEntity");
		if(!g_hBacktrackEntity)
		{
			delete hGameData;
			SetFailState("Failed to setup detour for CLagCompensationManager__BacktrackEntity");
		}

		if(!DHookEnableDetour(g_hBacktrackEntity, false, Detour_OnBacktrackEntity))
		{
			delete hGameData;
			SetFailState("Failed to detour CLagCompensationManager__BacktrackEntity.");
		}
	}

	// CBaseEntity::IsMoving
	StartPrepSDKCall(SDKCall_Entity);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "IsMoving"))
	{
		delete hGameData;
		SetFailState("PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, \"IsMoving\") failed!");
	}
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hIsMoving = EndPrepSDKCall();

	delete hGameData;
}

// CS:S
public MRESReturn Detour_OnBacktrackPlayer(Handle hParams)
{
	if(DHookIsNullParam(hParams, 1))
		return MRES_Ignored;

	int client = DHookGetParam(hParams, 1);
	if(client < 1 || client > MaxClients)
		return MRES_Ignored;

	int GroundEntity = GetEntPropEnt(client, Prop_Data, "m_hGroundEntity");
	if(GroundEntity <= 0)
		return MRES_Ignored;

	bool bIsMoving = SDKCall(g_hIsMoving, GroundEntity);

	if(bIsMoving)
		return MRES_Supercede;

	return MRES_Ignored;
}

// CS:GO
public MRESReturn Detour_OnBacktrackEntity(Handle hReturn, Handle hParams)
{
	if(DHookIsNullParam(hParams, 1))
		return MRES_Ignored;

	int client = DHookGetParam(hParams, 1);
	if(client < 1 || client > MaxClients)
		return MRES_Ignored;

	int GroundEntity = GetEntPropEnt(client, Prop_Data, "m_hGroundEntity");
	if(GroundEntity <= 0)
		return MRES_Ignored;

	bool bIsMoving = SDKCall(g_hIsMoving, GroundEntity);

	if(bIsMoving)
	{
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}
