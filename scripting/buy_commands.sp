/*  SM Buy weapons by commands
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <zombiereloaded>
 
#define DATA "2.1.1"

char sConfig[PLATFORM_MAX_PATH];
Handle kv, trie_weapons[MAXPLAYERS + 1];

public Plugin:myinfo =
{
	name = "SM Buy weapons by commands",
	description = "",
	author = "Franc1sco franug",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("ZR_IsClientZombie");
	return APLRes_Success;
}
 
public OnPluginStart()
{
	CreateConVar("sm_buybycommands_version", DATA, "", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	AddCommandListener(SayC, "say");
	AddCommandListener(SayC, "say_team");
	
	HookEvent("player_spawn", PlayerSpawn);
	
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientConnected(client);
		}
	}
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	ClearTrie(trie_weapons[client]);
}

public OnClientConnected(client)
{
	trie_weapons[client] = CreateTrie();
}

public OnClientDisconnect(client)
{
	if(trie_weapons[client] != INVALID_HANDLE) CloseHandle(trie_weapons[client]);
}

public OnMapStart()
{
	RefreshKV();
}

public void RefreshKV()
{
	BuildPath(Path_SM, sConfig, PLATFORM_MAX_PATH, "configs/franug_buybycommands.txt");
	
	if(kv != INVALID_HANDLE) CloseHandle(kv);
	
	kv = CreateKeyValues("BuyCommands");
	FileToKeyValues(kv, sConfig);
}

public Action:SayC(client,const char[] command, args)
{
	if (!IsValidClient(client))return;
	
	decl String:buffer[255];
	GetCmdArgString(buffer,sizeof(buffer));
	StripQuotes(buffer);
	
	if (kv == INVALID_HANDLE)RefreshKV();
	
	KvRewind(kv);
	if (!KvJumpToKey(kv, buffer))return;
	
	int money = GetEntProp(client, Prop_Send, "m_iAccount");
	int cost = KvGetNum(kv, "price");
	
	if(money >= cost)
	{
		if(GetClientTeam(client) < 2)
		{
			PrintToChat(client, " \x04You need to be in a team for buy weapons");
			return;
		}
		if(!IsPlayerAlive(client))
		{
			PrintToChat(client, " \x04You need to be alive for buy weapons");
			return;
		}
		if ((GetFeatureStatus(FeatureType_Native, "ZR_IsClientZombie") == FeatureStatus_Available) && ZR_IsClientZombie(client))
		{
			PrintToChat(client, " \x04You need to be human for buy weapons");
			return;
		}
		
		char weapons[64];
		KvGetString(kv, "weapon", weapons, 64);
		int times = KvGetNum(kv, "times");
		int current;
		
		if(times == 0)
		{
			int drop = KvGetNum(kv, "slot", -1);
			if(drop != -1)		
			{
				int weapon = GetPlayerWeaponSlot(client, drop);
				if(weapon != -1) SDKHooks_DropWeapon(client, weapon);
			}
			
			GivePlayerItem(client, weapons);
			SetEntProp(client, Prop_Send, "m_iAccount", money-cost);
			PrintToChat(client, " \x04You have bought a %s", weapons);
			return;
		}
		
		if (!GetTrieValue(trie_weapons[client], weapons, current))current = 0;
		
		if(times <= current)
		{
			PrintToChat(client, " \x04You cant buy more %s this round", weapons);
			return;
		
		}
		SetTrieValue(trie_weapons[client], weapons, ++current);
		
		int drop = KvGetNum(kv, "slot", -1);
		if(drop != -1)		
		{
			int weapon = GetPlayerWeaponSlot(client, drop);
			if(weapon != -1) SDKHooks_DropWeapon(client, weapon);
		}
		
		GivePlayerItem(client, weapons);
		SetEntProp(client, Prop_Send, "m_iAccount", money-cost);
		PrintToChat(client, " \x04You have bought a %s %i/%i", weapons, current, times);
	}
	else PrintToChat(client, " \x04You dont have enought money. You need %i", cost);

}

stock bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}