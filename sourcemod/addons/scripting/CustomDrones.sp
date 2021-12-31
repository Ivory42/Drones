#pragma semicolon 1
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <tf2attributes>
#include <customdrones>


#define FAR_FUTURE 	999999999.0

//Forwards

GlobalForward g_DroneCreated;
GlobalForward g_DroneExplode;
GlobalForward g_DroneDestroy;
GlobalForward g_DroneChangeWeapon;
GlobalForward g_DroneAttack;

CDMoveType dMoveType[2048];

float FlyMinSpeed = 200.0;

char sPluginName[2048][PLATFORM_MAX_PATH];
char sName[2048][PLATFORM_MAX_PATH];
char sModelName[2048][PLATFORM_MAX_PATH];
char sModelDestroyed[2048][PLATFORM_MAX_PATH];
char sMoveType[2048][PLATFORM_MAX_PATH];

int ExplosionSprite;

int hDroneEntity[MAXPLAYERS+1];
int AmmoLoaded[2048][MAXWEAPONS+1];
int hDroneOwner[2048];
int iDroneWeapons[2048];
int iWeaponNumber[2048];
int dActiveWeapon[2048];
float CameraHeight[2048];
float flDroneHealth[2048];
float flDroneMaxHealth[2048];
float flDroneMaxSpeed[2048];
float flDroneAcceleration[2048];
float ReloadTime[2048][MAXWEAPONS+1];
float FireRate[2048][MAXWEAPONS+1];

char sDroneWeapon1[2048][PLATFORM_MAX_PATH];
char sDroneWeapon2[2048][PLATFORM_MAX_PATH];
char sDroneWeapon3[2048][PLATFORM_MAX_PATH];
char sDroneWeapon4[2048][PLATFORM_MAX_PATH];

float flRollRate = 0.8;

float flFireDelay[2048][MAXWEAPONS+1];

float flDroneExplodeDelay[2048];

float flAmmoChange[2048];
float flSpeed[MAXPLAYERS+1][6];
float flRoll[MAXPLAYERS+1];
bool DroneIsDead[2049];

bool bIsInDrone[MAXPLAYERS+1];
bool IsDrone[2048];

public Plugin MyInfo = {
	name 			= 	"Custom Drones",
	author 			=	"Ivory",
	description		= 	"Customizable drones for players",
	version 		= 	"1.0"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_drone", CmdDrone, ADMFLAG_ROOT);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("teamplay_round_start", OnRoundStart);

	ExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");

	//Forwards
	g_DroneCreated = CreateGlobalForward("CD_OnDroneCreated", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String); //drone, owner, plugin, config
	g_DroneExplode = CreateGlobalForward("CD_OnDroneRemoved", ET_Ignore, Param_Cell, Param_Cell, Param_String); //drone, owner, plugin
	g_DroneChangeWeapon = CreateGlobalForward("CD_OnWeaponChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String); //drone, owner, weapon, plugin
	g_DroneDestroy = CreateGlobalForward("CD_OnDroneDestroyed", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_String); //drone, owner, attacker, damage, plugin
	g_DroneAttack = CreateGlobalForward("CD_OnDroneAttack", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String); //drone, owner, weapon, plugin
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CD_GetDroneHealth", Native_GetDroneHealth);
	CreateNative("CD_GetDroneMaxHealth", Native_GetDroneMaxHealth);
	CreateNative("CD_SpawnDroneByName", Native_SpawnDroneName);
	CreateNative("CD_GetDroneActiveWeapon", Native_GetDroneWeapon);
	CreateNative("CD_SetWeaponReloading", Native_SetWeaponReload);
	CreateNative("CD_GetParamFloat", Native_GetFloatParam);
	CreateNative("CD_GetParamInteger", Native_GetIntParam);
	CreateNative("CD_SpawnRocket", Native_SpawnRocket);
	CreateNative("CD_GetCameraHeight", Native_GetCameraHeight);
	CreateNative("CD_IsValidDrone", Native_ValidDrone);
	CreateNative("CD_DroneTakeDamage", Native_DroneTakeDamage);
	return APLRes_Success;
}

/********************************************************************************

	NATIVES

********************************************************************************/

public void Native_DroneTakeDamage(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	int attacker = GetNativeCell(2);
	int inflictor = GetNativeCell(3);
	float damage = GetNativeCell(4);
	bool crit = view_as<bool>(GetNativeCell(5));
	
	DroneTakeDamage(drone, attacker, inflictor, damage, crit);
}

public int Native_ValidDrone(Handle plugin, int args)
{
	int drone = GetNativeCell(1);

	//PrintToChatAll("checking entity: %i", drone);
	if (IsValidDrone(drone))
	{
		//PrintToChatAll("Entity %i is a drone");
		return true;
	}

	return false;
}

public int Native_GetDroneHealth(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	int iDroneHP2 = RoundFloat(flDroneHealth[drone]);
	return iDroneHP2;
}

public int Native_GetDroneMaxHealth(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	int iDroneMaxHP = RoundFloat(flDroneMaxHealth[drone]);
	return iDroneMaxHP;
}

public int Native_GetDroneWeapon(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	return dActiveWeapon[drone];
}

public int Native_SpawnDroneName(Handle plugin, int args)
{
	int client = GetNativeCell(1);
	char name[128];
	GetNativeString(2, name, sizeof(name));

	TryCreateDrone(client, name);
}

public int Native_SetWeaponReload(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	int weapon = GetNativeCell(2);
	float delay = GetNativeCell(3);

	if (!delay)
		delay = ReloadTime[drone][weapon];

	flFireDelay[drone][weapon] = GetEngineTime() + delay;
}

public any Native_GetFloatParam(Handle plugin, int args)
{
	float result;
	char config[64], key[64], weapon[64];
	int weaponId = GetNativeCell(3);
	GetNativeString(1, config, sizeof config);
	GetNativeString(2, key, sizeof key);

	KeyValues drone = new KeyValues("Drone");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", config);
	drone.ImportFromFile(path);

	if (weaponId)
	{
		drone.JumpToKey("weapons");
		Format(weapon, sizeof weapon, "weapon%i", weaponId);
		drone.JumpToKey(weapon);
	}
	result = drone.GetFloat(key);
	delete drone;
	return result;
}

public any Native_GetIntParam(Handle plugin, int args)
{
	int result;
	char config[64], key[64], weapon[64];
	int weaponId = GetNativeCell(3);
	GetNativeString(1, config, sizeof config);
	GetNativeString(2, key, sizeof key);

	KeyValues drone = new KeyValues("Drone");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", config);
	drone.ImportFromFile(path);

	if (weaponId)
	{
		drone.JumpToKey("weapons");
		Format(weapon, sizeof weapon, "weapon%i", weaponId);
		drone.JumpToKey(weapon);
	}
	result = drone.GetNum(key);
	delete drone;
	return result;
}

public any Native_SpawnRocket(Handle Plugin, int args)
{
	int owner = GetNativeCell(1);
	int drone = GetNativeCell(2);
	ProjType projectile = GetNativeCell(3);
	float damage = GetNativeCell(4);
	float speed = GetNativeCell(5);
	float overrideX = GetNativeCell(6);
	float overrideY = GetNativeCell(7);
	float overrideZ = GetNativeCell(8);
	float inaccuracy = GetNativeCell(9);

	//PrintToConsole(owner, "Damage: %.1f\nSpeed: %.1f\noffset x: %.1f\noffset y: %.1f\noffset z: %.1f", damage, speed, overrideX, overrideY, overrideZ);

	float pos[3], angle[3], spawnPos[3], velocity[3], aimAngle[3];
	char netname[64], classname[64];

	//Get Spawn Position
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);				//adjust position based on the physical weapon being used on the drone
	GetEntPropVector(drone, Prop_Send, "m_angRotation", angle);
	GetClientEyeAngles(owner, aimAngle);
	GetForwardPos(pos, angle, overrideX, overrideY, overrideZ, spawnPos);

	//Get where our drone is aiming and direct the rocket towards that angle
	float aimPos[3], aimVec[3], cameraPos[3];
	cameraPos = pos;
	cameraPos[2] += CameraHeight[drone];
	CD_GetDroneAimPosition(drone, cameraPos, aimAngle, aimPos);

	//TE_SetupBeamPoints(pos, aimPos, PrecacheModel("materials/sprites/laser.vmt"), PrecacheModel("materials/sprites/laser.vmt"), 0, 1, 1.0, 5.0, 5.0, 10, 0.0, {255, 0, 0, 255}, 10);
	//TE_SendToClient(owner);

	MakeVectorFromPoints(pos, aimPos, aimVec);
	GetVectorAngles(aimVec, angle);

	int rocket;

	if (inaccuracy)
	{
		angle[0] += GetRandomFloat((inaccuracy * -1), inaccuracy);
		angle[1] += GetRandomFloat((inaccuracy * -1), inaccuracy);
	}

	GetAngleVectors(angle, velocity, NULL_VECTOR, NULL_VECTOR);

	switch (projectile)
	{
		case DroneProj_Rocket:
		{
			Format(classname, sizeof classname, "tf_projectile_rocket");
			Format(netname, sizeof netname, "CTFProjectile_Rocket");
		}
		case DroneProj_Energy:
		{
			Format(classname, sizeof classname, "tf_projectile_energy_ball");
			Format(netname, sizeof netname, "CTFProjectile_EnergyBall");
		}
		case DroneProj_Sentry:
		{
			Format(classname, sizeof classname, "tf_projectile_sentryrocket");
			Format(netname, sizeof netname, "CTFProjectile_SentryRocket");
		}
	}

	rocket = CreateEntityByName(classname);
	ScaleVector(velocity, speed);
	SetEntPropVector(rocket, Prop_Send, "m_vInitialVelocity", velocity);
	int team = GetClientTeam(owner);

	//teleport to proper position and then spawn
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", owner);
	TeleportEntity(rocket, spawnPos, angle, velocity);

	SetVariantInt(team);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);

	SetVariantInt(team);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0);

	DispatchSpawn(rocket);

	SetEntDataFloat(rocket, FindSendPropInfo(netname, "m_iDeflected") + 4, damage); //Set Damage for rocket

	return rocket;
}

public any Native_GetCameraHeight(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	return CameraHeight[drone];
}

void CD_GetDroneAimPosition(int drone, float pos[3], float angle[3], float buffer[3])
{
	Handle trace = TR_TraceRayFilterEx(pos, angle, MASK_SHOT, RayType_Infinite, FilterDrone, drone);
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(buffer, trace);
		CloseHandle(trace);
		return;
	}
	CloseHandle(trace);
}

bool FilterDrone(int entity, int mask, int exclude)
{
	if (entity == exclude)
		return false;

	return true;
}

public void TryCreateDrone(int client, const char[] drone_name)
{
	char Directory[PLATFORM_MAX_PATH];
	char FileName[PLATFORM_MAX_PATH];
	FileType type;
	BuildPath(Path_SM, Directory, sizeof(Directory), "configs/drones");
	Handle hDir = OpenDirectory(Directory);

	while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
	{
		if (type != FileType_File) continue;
		ReplaceString(FileName, sizeof FileName, ".txt", "", false);
		if (StrEqual(drone_name, FileName))
		{
			//PrintToChatAll("Found drone %s", drone_name);
			SpawnDrone(client, drone_name);
			CloseHandle(hDir);
			return;
		}
		LogMessage("Found Config %s", FileName);
	}

	//PrintToChatAll("Unable to find drone %s", drone_name);
	CloseHandle(hDir);
	return;
}

public void OnMapStart()
{
	char DroneDir[PLATFORM_MAX_PATH];
	char FileName[PLATFORM_MAX_PATH];
	char PathName[PLATFORM_MAX_PATH];
	int droneCount, pluginCount;
	FileType type;
	BuildPath(Path_SM, DroneDir, sizeof(DroneDir), "configs/drones");
	if (!DirExists(DroneDir))
		SetFailState("Drones directory (%s) does not exist!", DroneDir);

	Handle hDir = OpenDirectory(DroneDir);
	while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
	{
		if (type != FileType_File) continue;
		Format(PathName, sizeof(PathName), "%s/%s", DroneDir, FileName);
		KeyValues kv = new KeyValues("Drone");
		if (!kv.ImportFromFile(PathName))
		{
			LogMessage("Unable to open %s. It will be excluded from drone list.", PathName);
			CloseHandle(hDir);
			delete kv;
			continue;
		}
		if (!kv.JumpToKey("plugin"))
		{
			LogMessage("Drone config %s does not have a specified plugin, please specify a plugin for this drone!", PathName);
			CloseHandle(hDir);
			delete kv;
			continue;
		}
		LogMessage("Found Drone Config: %s", FileName);
		droneCount++;
		kv.Rewind();
		delete kv;
	}

	CloseHandle(hDir);

	char pDirectory[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, pDirectory, sizeof(pDirectory), "plugins/drones");
	if (!DirExists(pDirectory))
		SetFailState("Plugin directory (%s) does not exist!", pDirectory);

	hDir = OpenDirectory(pDirectory);

	while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
	{
		if (type != FileType_File) continue;
		if (StrContains(FileName, ".smx") == -1) continue;
		Format(FileName, sizeof(FileName), "drones/%s", FileName);
		ServerCommand("sm plugins load %s", FileName);
		pluginCount++;
	}
	CloseHandle(hDir);

	LogMessage("Custom Drones loaded successfully with %i drones and %i plugins.", droneCount, pluginCount);
}

public Action OnRoundStart(Event event, const char[] name, bool dBroad)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && bIsInDrone[i])
		{
			ResetClientView(i);
			hDroneEntity[i] = INVALID_ENT_REFERENCE;
		}
	}
}

public Action OnPlayerDeath(Event hEvent, const char[] name, bool dBroad)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if (IsValidClient(client) && bIsInDrone[client])
	{
		bIsInDrone[client] = false;
		KillDrone(hDroneEntity[client], attacker, 0.0);
		ResetClientView(client);
	}
}

public Action CmdDrone(int client, int args)
{
	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int	target_count;
	bool targets = true;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		targets = false;
	}

	if (targets)
	{
		for (int i = 0; i < target_count; i++)
		{
			int target = target_list[i];

			if (IsPlayerAlive(target) && IsValidClient(target))
			{
				OpenMenu(target);
			}
		}
	}
	else
	{
		if (IsPlayerAlive(client) && IsValidClient(client))
		{
			OpenMenu(client);
		}
	}
	return Plugin_Handled;
}

public Action OpenMenu(int client)
{
	Menu DroneMenu = new Menu(DroneMenuCallback, MENU_ACTIONS_ALL);
	DroneMenu.SetTitle("Drone Selection");

	char DroneDir[PLATFORM_MAX_PATH];
	char FileName[PLATFORM_MAX_PATH];

	FileType type;
	BuildPath(Path_SM, DroneDir, sizeof(DroneDir), "configs/drones");
	Handle hDir = OpenDirectory(DroneDir);
	while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
	{
		ReplaceString(FileName, sizeof FileName, ".txt", "", false);
		DroneMenu.AddItem(FileName, FileName);
	}
	CloseHandle(hDir);
	DroneMenu.AddItem("-1", "Exit");
	SetMenuExitButton(DroneMenu, true);
	DroneMenu.Display(client, 60);
	return Plugin_Handled;
}

public int DroneMenuCallback(Menu menu, MenuAction action, int client, int param1)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param1, info, sizeof(info));
			if (StrEqual(info, "-1"))
			{
				return 0;
			}
			else
				TryCreateDrone(client, info);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

public void OnEntityDestroyed(int entity)
{
	//preserved
}

public void OnClientPutInServer(int client)
{
	bIsInDrone[client] = false;
	hDroneEntity[client] = -1;
}

stock void GetWeaponName(int drone, int type, char[] buffer, int size)
{
	switch (type)
	{
		case 1: Format(buffer, size, sDroneWeapon1[drone]);
		case 2: Format(buffer, size, sDroneWeapon2[drone]);
		case 3: Format(buffer, size, sDroneWeapon3[drone]);
		case 4: Format(buffer, size, sDroneWeapon4[drone]);
	}
}

stock void IsProjReloaded(int drone, int weapon, char[] buffer, int size)
{
	if (flFireDelay[drone][weapon] <= GetEngineTime())
		Format(buffer, size, "Ready");
	else
		Format(buffer, size, "Reloading...");
}

public Action OnDroneDamaged(int drone, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidEntity(drone))
	{
		//PrintToChatAll("damaged");

		if ((damagetype & DMG_CRIT) && attacker != drone)
		{
			damage *= 3.0; //triple damage for crits
			damagetype = DMG_ENERGYBEAM; //no damage falloff
		}

		if (attacker != hDroneOwner[drone])
		{
			//PrintToChatAll("Attacker is not owner");
			DroneTakeDamage(drone, attacker, inflictor, damage, false);
		}

		
	}
}

void DroneTakeDamage(int drone, int &attacker, int &inflictor, float &damage, bool crit)
{
	bool sendEvent = true;
	
	if (DroneIsDead[drone]) return;
	
	if (attacker == hDroneOwner[drone]) //significantly reduce damage if the drone damages itself
	{
		damage *= 0.25; //Should probably be a convar
		sendEvent = false;
	}
	
	if (sendEvent)
		SendDamageEvent(drone, attacker, damage, false);

	flDroneHealth[drone] -= damage;
	if (flDroneHealth[drone] <= 0.0)
	{
		KillDrone(drone, attacker, damage);
	}
}

void KillDrone(int drone, int attacker, float damage)
{
	flDroneHealth[drone] = 0.0;
	DroneIsDead[drone] = true;
	flDroneExplodeDelay[drone] = GetEngineTime() + 3.0;
	CreateParticle(drone, "burningplayer_flyingbits", true);
	Call_StartForward(g_DroneDestroy);

	Call_PushCell(drone);
	Call_PushCell(hDroneOwner[drone]);
	Call_PushCell(attacker);
	Call_PushFloat(damage);
	Call_PushString(sPluginName[drone]);

	Call_Finish();
}

public void ResetClientView(int client)
{
	SetClientViewEntity(client, client);
	bIsInDrone[client] = false;
	SetEntityMoveType(client, MOVETYPE_WALK);
}

public void SendDamageEvent(int victim, int attacker, float damage, bool crit)
{
	if (IsValidClient(attacker) && IsValidDrone(victim))
	{
		int damageamount = RoundFloat(damage);
		int health = RoundFloat(flDroneHealth[victim]);
		Event PropHurt = CreateEvent("npc_hurt", true);

		//setup components for event
		PropHurt.SetInt("entindex", victim);
		PropHurt.SetInt("attacker_player", GetClientUserId(attacker));
		PropHurt.SetInt("damageamount", damageamount);
		PropHurt.SetInt("health", health - damageamount);
		
		PropHurt.FireEvent(false);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client))
	{
		if (IsValidDrone(hDroneEntity[client]))
		{
			int iDroneHP;
			int hDrone = hDroneEntity[client];
			int activeWeapon = iWeaponNumber[hDrone];
			iDroneHP = RoundFloat(flDroneHealth[hDrone]);
			float vPos[3], vAngles[3], vVel[3], vVel2[3], vVel3[3], vVel4[3], vVel5[3], vVel6[3], vAbsVel[3]; //need to condense these into a single 2d array
			char sAmmoType[64], ammo[64];
			float flMaxSpeed = flDroneMaxSpeed[hDrone];
			if (!DroneIsDead[hDrone])
			{

				GetWeaponName(hDrone, activeWeapon, sAmmoType, sizeof sAmmoType);
				IsProjReloaded(hDrone, activeWeapon, activeWeapon, ammo, sizeof ammo);
				
				if (AmmoLoaded[hDrone][activeWeapon] == -1)
				{
					Format(ammo, sizeof ammo, "");
				}

				SetHudTextParams(0.6, -1.0, 0.01, 255, 255, 255, 150);
				char sDroneHp[64];
				Format(sDroneHp, sizeof sDroneHp, "Health: %i\nWeapon: %s\n%s", iDroneHP, sAmmoType, sIsReady);
				ShowHudText(client, -1, "%s", sDroneHp);

				GetEntPropVector(hDrone, Prop_Data, "m_vecOrigin", vPos);
				GetClientEyeAngles(client, vAngles);

				switch (dMoveType[hDrone])
				{
					case DroneMove_Hover:
					{
						GetAngleVectors(vAngles, vVel, NULL_VECTOR, NULL_VECTOR);

						if (buttons & IN_FORWARD)
						{
							flSpeed[client][0] += flDroneAcceleration[hDrone];
						}
						else
						{
							flSpeed[client][0] -= flDroneAcceleration[hDrone];
						}

						ScaleVector(vVel, flSpeed[client][0]);

						GetAngleVectors(vAngles, vVel3, NULL_VECTOR, NULL_VECTOR);
						if (buttons & IN_BACK)
						{
							flSpeed[client][2] += flDroneAcceleration[hDrone];
						}
						else
						{
							flSpeed[client][2] -= flDroneAcceleration[hDrone];
						}

						ScaleVector(vVel3, -flSpeed[client][2]);

						GetAngleVectors(vAngles, NULL_VECTOR, vVel2, NULL_VECTOR);
						if (buttons & IN_MOVERIGHT)
						{
							flSpeed[client][1] += flDroneAcceleration[hDrone];
							flRoll[client] += flRollRate;
						}
						else
						{
							flSpeed[client][1] -= flDroneAcceleration[hDrone];
						}

						ScaleVector(vVel2, flSpeed[client][1]);

						GetAngleVectors(vAngles, NULL_VECTOR, vVel4, NULL_VECTOR);
						if (buttons & IN_MOVELEFT)
						{
							flSpeed[client][3] += flDroneAcceleration[hDrone];
							flRoll[client] -= flRollRate;
						}
						else
						{
							flSpeed[client][3] -= flDroneAcceleration[hDrone];
						}

						ScaleVector(vVel4, -flSpeed[client][3]);

						GetAngleVectors(vAngles, NULL_VECTOR, NULL_VECTOR, vVel5);
						if (buttons & IN_JUMP)
						{
							flSpeed[client][4] += flDroneAcceleration[hDrone];
						}
						else
						{
							flSpeed[client][4] -= flDroneAcceleration[hDrone];
						}

						ScaleVector(vVel5, flSpeed[client][4]);

						GetAngleVectors(vAngles, NULL_VECTOR, NULL_VECTOR, vVel6);
						if (buttons & IN_DUCK)
						{
							flSpeed[client][5] += flDroneAcceleration[hDrone];
						}
						else
						{
							flSpeed[client][5] -= flDroneAcceleration[hDrone];
						}

						ScaleVector(vVel6, -flSpeed[client][5]);

						AddMultipleVectors(vVel, vVel2, vVel3, vVel4, vVel5, vVel6, vAbsVel);

						for (int v = 0; v < 6; v++)
						{
							flSpeed[client][v] = ClampFloat(flSpeed[client][v], flMaxSpeed);
						}

						if (!ClientSideMovement(client, buttons) && (flRoll[client] > 0.6 || flRoll[client] < 0.6))
							flRoll[client] = SetRollTowardsZero(flRoll[client]);

						flRoll[client] = ClampFloat(flRoll[client], 30.0, -30.0);
						vAngles[2] = flRoll[client];
					}
					case DroneMove_Fly: //flying drones can only move forward
					{
						//specific variables for flying drones
						float forwardVec[3];

						GetAngleVectors(vAngles, forwardVec, NULL_VECTOR, NULL_VECTOR);

						if (buttons & IN_FORWARD)
						{
							flSpeed[client][0] += flDroneAcceleration[hDrone];
						}
						else
						{
							flSpeed[client][0] -= flDroneAcceleration[hDrone];
						}

						flSpeed[client][0] = ClampFloat(flSpeed[client][0], flMaxSpeed, FlyMinSpeed);
						ScaleVector(forwardVec, flSpeed[client][0]);
						vAbsVel = forwardVec;
						float turnRate = AngleDifference(hDrone, vAngles, turnRate);
						if (FloatAbs(turnRate) >= 0.45)
						{
							if (turnRate > 0) //Right turn
							{
								flRoll[client] += flRollRate * GetFactorFromSpeed(hDrone, flSpeed[client][0]);
							}
							else
							{
								flRoll[client] -= flRollRate * GetFactorFromSpeed(hDrone, flSpeed[client][0]);
							}
						}
						else
							flRoll[client] = SetRollTowardsZero(flRoll[client], true);

						PrintCenterText(client, "Roll: %.1f", flRoll[client]);

						//flRoll[client] = ClampFloat(flRoll[client], 50.0, -50.0);
						vAngles[2] = flRoll[client];
					}
					case DroneMove_Ground:
					{

					}
				}

				if (buttons & IN_ATTACK2 && flAmmoChange[hDrone] <= GetEngineTime())
				{
					if (iWeaponNumber[hDrone] >= iDroneWeapons[hDrone])
						iWeaponNumber[hDrone] = 1;
					else
						iWeaponNumber[hDrone]++;

					dActiveWeapon[hDrone] = iWeaponNumber[hDrone];
					flAmmoChange[hDrone] = GetEngineTime() + 0.5;
					Call_StartForward(g_DroneChangeWeapon);

					Call_PushCell(hDrone);
					Call_PushCell(client);
					Call_PushCell(iWeaponNumber[hDrone]);
					Call_PushString(sPluginName[hDrone]);

					Call_Finish();
				}
				if (buttons & IN_ATTACK && flFireDelay[hDrone][activeWeapon] <= GetEngineTime() && AmmoLoaded[hDrone][activeWeapon] != 0) //TODO - Change this to fire rates defined in the drone config
				{
					flFireDelay[hDrone][activeWeapon] = GetEngineTime() + FireRate[hDrone][activeWeapon];

					Call_StartForward(g_DroneAttack);

					Call_PushCell(hDrone);
					Call_PushCell(client);
					Call_PushCell(dActiveWeapon[hDrone]);
					Call_PushString(sPluginName[hDrone]);

					Call_Finish();
					
					AmmoLoaded[hDrone][activeWeapon]--;
					if (AmmoLoaded[hDrone][activeWeapon] == 0)
					{
						StartWeaponReload(hDrone, activeWeapon, ReloadTime);
					}
				}
				TeleportEntity(hDrone, NULL_VECTOR, vAngles, vAbsVel);
			}
			else if (flDroneExplodeDelay[hDrone] <= GetEngineTime())
			{
				flDroneExplodeDelay[hDrone] = FAR_FUTURE;
				ResetClientView(hDroneOwner[hDrone]);
				ExplodeDrone(hDrone);
				TryRemoveDrone(hDroneOwner[hDrone]);
			}
		}
	}
}

void StartWeaponReload(int drone, int weapon, float time)
{
	ReloadDelay[drone][weapon] = GetEngineTime() + ReloadTime[drone][weapon];
}

float GetFactorFromSpeed(int drone, float speed)
{
	float factor = speed / flDroneMaxSpeed[drone];
	factor = ClampFloat(factor * 1.85, 5.0, 0.75);
	return factor;
}

float AngleDifference(int drone, float aimAngle[3], float turnRate)
{
	float droneAngle[3];
	GetEntPropVector(drone, Prop_Send, "m_angRotation", droneAngle);
	turnRate = droneAngle[1] - aimAngle[1];

	return turnRate;
}

stock void AddMultipleVectors(float vec1[3], float vec2[3], float vec3[3] = {0.0, 0.0, 0.0}, float vec4[3] = {0.0, 0.0, 0.0}, float vec5[3] = {0.0, 0.0, 0.0}, float vec6[3] = {0.0, 0.0, 0.0}, float newVec[3])
{
	float curVec[3];
	AddVectors(vec1, vec2, curVec);
	AddVectors(curVec, vec3, curVec);
	AddVectors(curVec, vec4, curVec);
	AddVectors(curVec, vec5, curVec);
	AddVectors(curVec, vec6, curVec);

	newVec = curVec;
}

stock bool ClientMovementInput(int client, int &buttons)
{
	if (buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT || buttons & IN_JUMP || buttons & IN_DUCK)
		return true;

	return false;
}

stock bool ClientSideMovement(int client, int &buttons)
{
	if (buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
		return true;

	return false;
}

stock float SetRollTowardsZero(float roll, bool flying = false)
{
	if (roll > 0.0)
		roll -= flying ? flRollRate * 2.5 : flRollRate;

	if (roll < 0.0)
		roll += flying ? flRollRate * 2.5 : flRollRate;

	return roll;
}

public void ExplodeDrone(int drone)
{
	float dronePos[3];
	GetEntPropVector(drone, Prop_Send, "m_vecOrigin", dronePos);
	TE_SetupExplosion(dronePos, ExplosionSprite, 4.0, 1, 0, 450, 400);
	TE_SendToAll();

	Call_StartForward(g_DroneExplode);

	Call_PushCell(drone);
	Call_PushCell(hDroneOwner[drone]);
	Call_PushString(sPluginName[drone]);

	Call_Finish();
}

stock float ClampFloat(float value, float max, float min = 0.0)
{
	if (value > max)
		value = max;

	if (value < min)
		value = min;

	return value;
}

stock void ClampVector(float vec[3], float max, float min = 0.0, float vBuffer[3])
{
	for (int i = 0; i < 3; i++)
	{
		if (vec[i] >= max)
			vec[i] = max;

		if (vec[i] <= min)
			vec[i] = min;
	}
}

stock void SpawnDrone(int client, const char[] drone_name)
{
	KeyValues kv = new KeyValues("Drone");
	char sPath[64];
	BuildPath(Path_SM, sPath, sizeof sPath, "configs/drones/%s.txt", drone_name);

	if (!FileExists(sPath))
	{
		Handle fFile = OpenFile(sPath, "w");
		CloseHandle(fFile);
	}
	kv.ImportFromFile(sPath);

	float vAngles[3], vPos[3], vVel[3];
	GetClientEyeAngles(client, vAngles);
	GetClientEyePosition(client, vPos);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);

	//Spawn drone and get its index
	hDroneEntity[client] = CreateEntityByName("prop_physics_override");
	int hDrone = hDroneEntity[client];

	//Establish drone attributes
	kv.GetString("name", sName[hDrone], PLATFORM_MAX_PATH);
	kv.GetString("model", sModelName[hDrone], PLATFORM_MAX_PATH);
	kv.GetString("destroyed_model", sModelDestroyed[hDrone], PLATFORM_MAX_PATH, sModelName[hDrone]);
	flDroneMaxHealth[hDrone] = kv.GetFloat("health", 100.0);
	flDroneMaxSpeed[hDrone] = kv.GetFloat("speed", 300.0);
	flDroneAcceleration[hDrone] = kv.GetFloat("acceleration", 5.0);
	kv.GetString("movetype", sMoveType[hDrone], PLATFORM_MAX_PATH, "drone_hover");
	kv.GetString("plugin", sPluginName[hDrone], PLATFORM_MAX_PATH, "INVALID_PLUGIN");
	float height = kv.GetFloat("camera_height", 30.0);

	dMoveType[hDrone] = GetMoveType(sMoveType[hDrone]);

	//Find total number of weapons for this drone
	iDroneWeapons[hDrone] = 0;
	if (kv.JumpToKey("weapons"))
	{
		char sWeapon[MAXWEAPONS][PLATFORM_MAX_PATH], sNumber[8];
		for (int i = 1; i <= MAXWEAPONS; i++)
		{
			Format(sNumber, sizeof sNumber, "weapon%i", i);
			if (kv.JumpToKey(sNumber))
			{
				kv.GetString("name", sWeapon[i], PLATFORM_MAX_PATH, "INVALID_WEAPON");
				ReloadTime[hDrone][i] = kv.GetFloat("reload_time", 0.5);
				FireRate[hDrone][i] = 60.0 / kv.GetFloat("fire_rate", 100);
				MaxAmmo[hDrone][i] = kv.GetNum("ammo", 1);
				kv.GoBack();
			}
			else
			{
				LogMessage("Found %i weapons for %s", iDroneWeapons[hDrone], drone_name);
				break;
			}
			SetDroneWeaponName(hDrone, sWeapon[i], i);
			iDroneWeapons[hDrone]++;
		}
		kv.Rewind();
	}

	//Setup drone
	DispatchKeyValue(hDrone, "model", sModelName[hDrone]);
	DispatchKeyValue(hDrone, "health", "900");

	if(HasEntProp(hDrone, Prop_Data, "m_takedamage"))
		SetEntProp(hDrone, Prop_Data, "m_takedamage", 1);
	else
		LogMessage("Tried to spawn a drone with no m_takedamage netprop!");
	flDroneHealth[hDrone] = flDroneMaxHealth[hDrone];
	DroneIsDead[hDrone] = false;

	DispatchSpawn(hDrone);
	ActivateEntity(hDrone);
	TeleportEntity(hDrone, vPos, vAngles, vVel);

	hDroneOwner[hDrone] = client;
	SetEntityMoveType(client, MOVETYPE_NONE);
	IsDrone[hDrone] = true;
	SetEntityGravity(hDrone, 0.01);
	SetupViewPosition(client, hDrone, vPos, vAngles, height);
	SDKHook(hDrone, SDKHook_OnTakeDamage, OnDroneDamaged);

	iWeaponNumber[hDrone] = 1;
	dActiveWeapon[hDrone] = iWeaponNumber[hDrone];

	//PrintToChat(client, "Successfully created drone (%s) with owner: %i", drone_name, hDroneOwner[hDrone]);

	bIsInDrone[client] = true;

	Call_StartForward(g_DroneCreated);

	Call_PushCell(hDrone);
	Call_PushCell(client);
	Call_PushString(sPluginName[hDrone]);
	Call_PushString(drone_name);

	Call_Finish();
}

void SetupViewPosition(int client, int drone, const float pos[3], const float angle[3], float height)
{
	char sTargetName[64];
	float rPos[3];
	Format(sTargetName, sizeof sTargetName, "camerapos%d", drone);
	DispatchKeyValue(drone, "targetname", sTargetName);

	//Right weapon
	int camera = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(camera, "model", "models/empty.mdl");

	DispatchSpawn(camera);
	ActivateEntity(camera);

	rPos = pos;
	rPos[2] += height;

	CameraHeight[drone] = height;

	TeleportEntity(camera, rPos, angle, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(camera, "SetParent", drone, camera, 0);

	SetClientViewEntity(client, camera);
}

/*
Action OnFlyingDroneTouch(int drone, int victim)
{
	if (!IsValidClient(victim))
	{
		char classname[64];
		GetEntityClassname(victim, classname, sizeof(classname));
		if (victim == 0 || !StrContains(classname, "prop_", false) || !StrContains(classname, "func_door", false) || !StrContains(classname, "obj_", false))
		{
			return Plugin_Handled;
		}
	}
	else
		return Plugin_Handled;

	return Plugin_Continue;
}
*/

stock CDMoveType GetMoveType(const char[] movetype)
{
	if (StrEqual(movetype, "drone_hover"))
		return DroneMove_Hover;
	else if (StrEqual(movetype, "drone_fly"))
		return DroneMove_Fly;
	else if (StrEqual(movetype, "drone_ground"))
		return DroneMove_Ground;

	return DroneMove_Hover;
}

stock void SetDroneWeaponName(int drone, char[] weapon_name, int weaponID)
{
	switch (weaponID)
	{
		case 1: Format(sDroneWeapon1[drone], PLATFORM_MAX_PATH, weapon_name);
		case 2: Format(sDroneWeapon2[drone], PLATFORM_MAX_PATH, weapon_name);
		case 3: Format(sDroneWeapon3[drone], PLATFORM_MAX_PATH, weapon_name);
		case 4: Format(sDroneWeapon4[drone], PLATFORM_MAX_PATH, weapon_name);
	}
}

stock bool TryRemoveDrone(int client)
{
	if (IsValidDrone(hDroneEntity[client]))
	{
		ExplodeDrone(hDroneEntity[client]);
		hDroneOwner[hDroneEntity[client]] = -1;
		IsDrone[hDroneEntity[client]] = false;
		AcceptEntityInput(hDroneEntity[client], "Kill");
		hDroneEntity[client] = -1;
		return true;
	}
	return false;
}

stock int CreateParticle(int iEntity = 0, char[] sParticle, bool bAttach = false, float pos[3]={0.0, 0.0, 0.0})
{
	int iParticle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(iParticle))
	{
		if (iEntity > 0)
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", pos);

		TeleportEntity(iParticle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(iParticle, "effect_name", sParticle);

		if (bAttach)
		{
			SetVariantString("!activator");
			AcceptEntityInput(iParticle, "SetParent", iEntity, iParticle, 0);
		}

		DispatchSpawn(iParticle);
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start");
	}
	return iParticle;
}

stock bool IsValidDrone(int drone)
{
	if (IsValidEntity(drone) && drone > MaxClients)
	{
		if (IsDrone[drone])
			return true;
	}

	return false;
}

stock bool IsValidClient(int client)
{
    if (!( 1 <= client <= MaxClients ) || !IsClientInGame(client))
        return false;

    return true;
}
