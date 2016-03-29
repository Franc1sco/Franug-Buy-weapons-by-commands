#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
 
#define DATA "1.0"

Handle array_weapons, array_commands, array_prices;

public Plugin:myinfo =
{
	name = "SM Buy weapons by commands",
	description = "",
	author = "Franc1sco franug",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};
 
public OnPluginStart()
{
	CreateConVar("sm_buybycommands_version", DATA, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	AddCommandListener(SayC, "say");
	AddCommandListener(SayC, "say_team");
	
	array_commands = CreateArray(124);
	array_weapons = CreateArray(64);
	array_prices = CreateArray();
}

public OnMapStart()
{
	ClearArray(array_weapons);
	ClearArray(array_commands);
	ClearArray(array_prices);
	
	new String:path[PLATFORM_MAX_PATH];
	BuildPath(PathType:Path_SM, path, sizeof(path), "configs/franug_buybycommands.txt");
	
	new Handle:file = OpenFile(path, "r");
	if(file == INVALID_HANDLE)
	{
		SetFailState("Unable to read file %s", path);
	}
	
	new String:line[256];
	new String:bit[3][256];

	while(!IsEndOfFile(file) && ReadFileLine(file, line, sizeof(line)))
	{
		if (line[0] == ';' || IsCharSpace(line[0]))
		{
			continue;
		}
		
		ExplodeString(line, ";", bit, 3, 256);

		PushArrayString(array_commands, bit[0]);
		PushArrayString(array_weapons, bit[1]);
		PushArrayCell(array_prices, StringToInt(bit[2]));
	}
	
	CloseHandle(file);
}

public Action:SayC(client,const char[] command, args)
{
	if (client == 0)return;
	
	decl String:buffer[255];
	GetCmdArgString(buffer,sizeof(buffer));
	StripQuotes(buffer);
	
	int index = FindStringInArray(array_commands, buffer);
	
	if (index == -1)return;
	
	int money = GetEntProp(client, Prop_Send, "m_iAccount");
	int cost = GetArrayCell(array_prices, index);
	
	if(money >= cost)
	{
		
		SetEntProp(client, Prop_Send, "m_iAccount", money-cost);
		char weapons[64];
		GetArrayString(array_weapons, index, weapons, 64);
		GivePlayerItem(client, weapons);
		PrintToChat(client, "You buy a %s", weapons);
		
	}
	else PrintToChat(client, "You dont have enought money. You need %i", cost);

}