#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>

#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN

#define UPDATE_URL "https://raw.githubusercontent.com/eyal282/SourceMod-GameData-Updater/master/Offsets/PlayerMaxSpeed/updatefile.txt"

new Handle:DHook_PlayerMaxSpeed = INVALID_HANDLE;
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo = 
{
	name = "Max Speed Example Plugin",
	author = "Eyal282",
	description = "Example plugin for using the updater offset checker",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{

	#if defined _updater_included
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	#endif
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	HandleGameData();
}

HandleGameData()
{	
	new Handle:hGameConf;
	
	hGameConf = LoadGameConfigFile("PlayerMaxSpeedOffset");
	
	if(hGameConf == INVALID_HANDLE)
	{
		Updater_ForceUpdate();

		return;
	}	
	new PlayerMaxSpeedOffset = GameConfGetOffset(hGameConf, "PlayerMaxSpeedOffset");
	
	if(PlayerMaxSpeedOffset == -1)
	{
		Updater_ForceUpdate();
		
		return;
	}
	DHook_PlayerMaxSpeed = DHookCreate(PlayerMaxSpeedOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, CCSPlayer_GetPlayerMaxSpeed);
	
	if(DHook_PlayerMaxSpeed == INVALID_HANDLE)
	{
		Updater_ForceUpdate();

		return;
	}	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		DHookEntity(DHook_PlayerMaxSpeed, true, i);
	}
}

public OnClientPutInServer(client)
{
	if(DHook_PlayerMaxSpeed != INVALID_HANDLE)
		DHookEntity(DHook_PlayerMaxSpeed, true, client);		
}

public OnLibraryAdded(const String:name[])
{
	#if defined _updater_included
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	#endif
}


public Updater_OnPluginUpdated()
{
	new String:MapName[128];
	GetCurrentMap(MapName, sizeof(MapName));

	ServerCommand("changelevel %s", MapName);
}

public Action:Event_PlayerSpawn(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsMaxSpeedHookWorking())
	{
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0 + (320.0 / 250.0));
		
		PrintToChat(client, "Sorry, couldn't use max speed, using bugged gravity thingy instead.");
	}
}


public MRESReturn:CCSPlayer_GetPlayerMaxSpeed(client, Handle:hReturn, Handle:hParams)
{		
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
		return MRES_Ignored;
	
	new Float:Maxspeed = DHookGetReturn(hReturn);
	
	if(Maxspeed < 1.0) // I don't remember about Maxspeed being zero but this appeared in all my codes...
		return MRES_Ignored; 
	
	Maxspeed += (320.0 - 250.0); // Capped at 320.0 ( sv_maxspeed in most server s) but affected by held weapon.
	
	DHookSetReturn(hReturn, Maxspeed);
	return MRES_Supercede;
}


stock bool:IsMaxSpeedHookWorking()
{
	return DHook_PlayerMaxSpeed != INVALID_HANDLE;
}