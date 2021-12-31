#pragma semicolon 1
#include <customdrones>
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>

#define FAR_FUTURE 9999999999.0

#define ENERGY_SOUND "weapons/cow_mangler_main_shot.wav"
#define ROCKETSOUND "weapons/sentry_rocket.wav"
#define PODMODEL "models/weapons/c_models/c_blackbox/c_blackbox.mdl"
#define MISSILEMODEL "models/weapons/c_models/c_rocketlauncher/c_rocketlauncher.mdl"
#define ENERGYMODEL "models/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl"
#define PLASMAMODEL	"models/weapons/c_models/c_drg_pomson/c_drg_pomson.mdl"

int ClientDrone[MAXPLAYERS+1];
bool Attributed[2048] = false;
bool IsDrone[2048] = false;

char sPluginName[2048][PLATFORM_MAX_PATH];

//Physical Weapons
int hDroneRWeapon[2048];
int hDroneLWeapon[2048];
int hLastWeaponFired[2048];

//Weapon variables
float flRocketFireDelay[2048] = FAR_FUTURE;
float BarrageRate[2048];
int iRocketCount[2048];
int BarrageMaxCount[2048];
bool bIsDroneRocket[2048];
bool InBarrage[2048];

//Weapon function variables
float flProjDamage[2048][MAXWEAPONS+1];
float flProjSpeed[2048][MAXWEAPONS+1];

CDDmgType dProjDmgType[2048];

public Plugin MyInfo = {
	name 			= 	"[Combat Drones] Example Drone",
	author 			=	"Ivory",
	description		= 	"Example plugin for a custom drone setup",
	version 		= 	"1.0"
};

public void OnPluginStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			OnClientPutInServer(i);
	}
}

void SetupWeaponStats(const char[] config, int drone)
{
	for (int i = 1; i <= 4; i++)
	{
		flProjDamage[drone][i] = CD_GetParamFloat(config, "damage", i);
		flProjSpeed[drone][i] = CD_GetParamFloat(config, "speed", i);
	}
	BarrageMaxCount[drone] = CD_GetParamInteger(config, "burst", 4);
	BarrageRate[drone] = CD_GetParamFloat(config, "attack_time", 4);
}

public void OnMapStart()
{
	PrecacheModel(MISSILEMODEL);
	PrecacheModel(ENERGYMODEL);
	PrecacheModel(PODMODEL);
	PrecacheModel(PLASMAMODEL);
	PrecacheSound(ROCKETSOUND);
	PrecacheSound(ENERGY_SOUND);
	PrecacheSound("weapons/custom/plasmarifle/shoot1.mp3");
	PrecacheSound("weapons/custom/plasmarifle/shoot2.mp3");
	PrecacheSound("weapons/custom/plasmarifle/shoot3.mp3");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, PlayerTakeDamage);
}

public void OnEntityDestroyed(int entity)
{
	if (IsValidEntity(entity) && entity > MaxClients)
	{
		bIsDroneRocket[entity] = false;
	}
}

stock void DetachDroneWeapons(int drone)
{
	AcceptEntityInput(hDroneRWeapon[drone], "ClearParent");
	AcceptEntityInput(hDroneLWeapon[drone], "ClearParent");
}

//Drone weapon functions
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client) && IsValidDrone(ClientDrone[client]))
	{
		int drone = ClientDrone[client];
		if (Attributed[drone])
		{
			int droneHP = CD_GetDroneHealth(drone);
			if (droneHP > 0)
			{
				//Rocket Pods function
				if (InBarrage[drone] && iRocketCount[drone] > 0 && flRocketFireDelay[drone] <= GetEngineTime())
				{
					CD_FireActiveWeapon(client, drone);
					iRocketCount[drone]--;
					flRocketFireDelay[drone] = GetEngineTime() + BarrageRate[drone];
				}
				else if (iRocketCount[drone] <= 0)
				{
					InBarrage[drone] = false;
				}
			}
		}
	}
}

public void CD_OnDroneAttack(int drone, int owner, int weapon, const char[] plugin)
{
	if (Attributed[drone])
	{
		//LogMessage("Active Drone Weapon: %i", weapon);
		switch (weapon)
		{
			case 3: //plasma rifle
			{
				//Fire from both weapons
				FireRocket(owner, drone, weapon, hLastWeaponFired[drone], false);
				FireRocket(owner, drone, weapon, hLastWeaponFired[drone], false);
			}
			case 4: //Rocket pods
			{
				if (!InBarrage[drone])
				{
					iRocketCount[drone] = BarrageMaxCount[drone];
					FireRocket(owner, drone, 4, hLastWeaponFired[drone], false);
					iRocketCount[drone]--;
					flRocketFireDelay[drone] = GetEngineTime() + BarrageRate[drone];
					InBarrage[drone] = true;
				}

			}
			default: FireRocket(owner, drone, weapon, hLastWeaponFired[drone], false);
		}
	}
}


//Function for when the drone fires its active weapon
public void FireRocket(int owner, int drone, int pType, int fireLoc, bool reload)
{
	char fireSound[64];

	//Get Spawn Position
	float sideOffset = (fireLoc == 1) ? 15.0 : -15.0;					//adjust position based on the physical weapon being used on the drone
	int rocket;
	CDDmgType dType;

	float speed = flProjSpeed[drone][pType];
	float damage = flProjDamage[drone][pType];

	//Create Rocket
	switch (pType)
	{
		case 1: //Normal Rockets
		{
			rocket = CD_SpawnRocket(owner, drone, DroneProj_Rocket, damage, speed, 60.0, sideOffset);
			Format(fireSound, sizeof fireSound, ROCKETSOUND);
			dType = DmgType_Missile;

		}
		case 2: //Energy Rockets
		{
			rocket = CD_SpawnRocket(owner, drone, DroneProj_Energy, damage, speed, 60.0, sideOffset);
			Format(fireSound, sizeof fireSound, ENERGY_SOUND);
			dType = DmgType_Energy;
		}
		case 3: //Energy Orbs
		{
			rocket = CD_SpawnRocket(owner, drone, DroneProj_Rocket, 0.0, speed, 60.0, sideOffset, _, 1.0);
			int sound = GetRandomInt(1, 3);
			Format(fireSound, sizeof fireSound, "weapons/custom/plasmarifle/shoot%i.mp3", sound);
			dType = DmgType_Plasma;
		}
		case 4: //Rocekt Pods
		{
			rocket = CD_SpawnRocket(owner, drone, DroneProj_Sentry, damage, speed, 60.0, sideOffset, _, 5.0);
			Format(fireSound, sizeof fireSound, ROCKETSOUND);
			dType = DmgType_Missile;
		}
	}
	if (pType == 3) //orbs/
	{
		SetEntityModel(rocket, "models/weapons/w_models/w_baseball.mdl");
		SetEntPropFloat(rocket, Prop_Send, "m_flModelScale", 0.1);
		CreateParticle(rocket, "drg_cow_rockettrail_fire_blue", true);
		SDKHook(rocket, SDKHook_Touch, PlasmaHit);
	}

	dProjDmgType[rocket] = dType;
	EmitSoundToAll(fireSound, drone);
	bIsDroneRocket[rocket] = true;

	if (reload)
		CD_SetWeaponReloading(drone, pType);

	hLastWeaponFired[drone] = GetNextWeapon(drone);	//Get next physical weapon to fire from
}

public Action PlasmaHit(int entity, int victim)
{
	if (!IsValidClient(victim))
	{
		if (CD_IsValidDrone(victim))
		{
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			CD_DroneTakeDamage(victim, owner, entity, flProjDamage[ClientDrone[owner]][3], false);
			AcceptEntityInput(entity, "Kill");
			return Plugin_Handled;
		}
		char classname[64];
		GetEntityClassname(victim, classname, sizeof(classname));
		if (victim == 0 || !StrContains(classname, "prop_", false))
		{
			AcceptEntityInput(entity, "Kill");
			return Plugin_Handled;
		}
		else if (StrContains(classname, "obj_", false)) //engineer buildings
		{
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			SDKHooks_TakeDamage(victim, entity, owner, flProjDamage[ClientDrone[owner]][3], DMG_ENERGYBEAM);
			AcceptEntityInput(entity, "Kill");
			return Plugin_Handled;
		}
		else return Plugin_Continue;
	}
	if (IsValidEntity(entity) && entity > 0)
	{
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (IsValidClient(owner) && IsValidClient(victim))
		{
			if (GetClientTeam(owner) != GetClientTeam(victim))
			{
				int drone = ClientDrone[owner];
				float dronePos[3], victimPos[3], distance, damage;
				damage = flProjDamage[drone][3];

				//Setup distance between drone and target
				GetEntPropVector(drone, Prop_Data, "m_vecOrigin", dronePos);
				GetClientAbsOrigin(victim, victimPos);
				distance = GetVectorDistance(dronePos, victimPos);

				//Slightly less standard hitscan rampup and falloff
				float dmgMod = ClampFloat((512.0 / distance), 1.4, 0.85);
				damage *= dmgMod;
				SDKHooks_TakeDamage(victim, entity, owner, damage, DMG_ENERGYBEAM);
			}
		}
	}
	AcceptEntityInput(entity, "kill");
	return Plugin_Handled;
}

public Action PlayerTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidClient(client) && bIsDroneRocket[inflictor] && IsValidDrone(ClientDrone[attacker]))
	{
		if (Attributed[ClientDrone[attacker]])
		{
			int hDrone = ClientDrone[attacker];
			float vecDronePos[3], vecViPos[3], flDistance;

			//remove damage falloff and rampup based on player distance
			damagetype = DMG_ENERGYBEAM;

			//Setup distance between drone and target
			GetEntPropVector(hDrone, Prop_Data, "m_vecOrigin", vecDronePos);
			GetClientAbsOrigin(client, vecViPos);
			flDistance = GetVectorDistance(vecDronePos, vecViPos);

			//Damage falloff and rampup
			switch (dProjDmgType[inflictor])
			{
				case DmgType_Missile: //Missiles and rockets
				{
					//Standard rocketlauncher damage falloff and rampup values
					float dmgMod = ClampFloat((512.0 / flDistance), 1.25, 0.528);
					damage *= dmgMod;
				}
			}
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public void CD_OnDroneDestroyed(int drone, int owner, int attacker, float damage, const char[] plugin_name)
{
	if (Attributed[drone])
		DetachDroneWeapons(drone);
}

public void CD_OnWeaponChanged(int drone, int owner, int newWeapon, const char[] plugin_name)
{
	if (StrEqual(plugin_name, "example_drone"))
		SetWeaponModels(drone, newWeapon);
}

public void CD_OnDroneCreated(int drone, int owner, const char[] plugin_name, const char[] config)
{
	Format(sPluginName[drone], PLATFORM_MAX_PATH, plugin_name);
	SetupWeaponStats(config, drone);
	if (StrEqual(plugin_name, "example_drone"))
	{
		float vAngles[3], vPos[3];
		GetClientEyeAngles(owner, vAngles);
		GetClientEyePosition(owner, vPos);

		ClientDrone[owner] = drone;
		Attributed[drone] = true;
		CreateDroneWeapons(owner, drone, vPos, vAngles);
		hLastWeaponFired[drone] = 1;
		IsDrone[drone] = true;
	}
}

public void CD_OnDroneRemoved(int drone, int owner, const char[] plugin_name)
{
	if (Attributed[drone])
	{
		IsDrone[drone] = false;
		Attributed[drone] = false;
		ClientDrone[owner] = -1;
		AcceptEntityInput(hDroneRWeapon[drone], "Kill");
		AcceptEntityInput(hDroneLWeapon[drone], "Kill");
		hDroneRWeapon[drone] = -1;
		hDroneLWeapon[drone] = -1;
	}
}

stock void SetWeaponModels(int drone, int pType)
{
	switch (pType)
	{
		case 1:
		{
			SetEntityModel(hDroneRWeapon[drone], MISSILEMODEL);
			SetEntityModel(hDroneLWeapon[drone], MISSILEMODEL);
		}
		case 2:
		{
			SetEntityModel(hDroneRWeapon[drone], ENERGYMODEL);
			SetEntityModel(hDroneLWeapon[drone], ENERGYMODEL);
		}
		case 3:
		{
			SetEntityModel(hDroneRWeapon[drone], PLASMAMODEL);
			SetEntityModel(hDroneLWeapon[drone], PLASMAMODEL);
		}
		case 4:
		{
			SetEntityModel(hDroneRWeapon[drone], PODMODEL);
			SetEntityModel(hDroneLWeapon[drone], PODMODEL);
		}
	}
}


//Create and set visual models for weapons
//This is completely cosmetic and is not required

stock void CreateDroneWeapons(int client, int drone, float spawnPos[3], float spawnAngle[3])
{
	char sTargetName[64];
	float lPos[3], rPos[3];
	Format(sTargetName, sizeof sTargetName, "sentrymuzzle%d", drone);
	DispatchKeyValue(drone, "targetname", sTargetName);
	float flSide;

	//Right weapon
	hDroneRWeapon[drone] = CreateEntityByName("prop_physics_override");
	DispatchKeyValue(hDroneRWeapon[drone], "model", MISSILEMODEL);

	DispatchSpawn(hDroneRWeapon[drone]);
	ActivateEntity(hDroneRWeapon[drone]);

	flSide = 15.0;
	GetForwardPos(spawnPos, spawnAngle, 0.0, flSide, 0.0, rPos);

	TeleportEntity(hDroneRWeapon[drone], rPos, spawnAngle, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(hDroneRWeapon[drone], "SetParent", drone, hDroneRWeapon[drone], 0);

	//Left Weapon
	hDroneLWeapon[drone] = CreateEntityByName("prop_physics_override");
	DispatchKeyValue(hDroneLWeapon[drone], "model", MISSILEMODEL);

	DispatchSpawn(hDroneLWeapon[drone]);
	ActivateEntity(hDroneLWeapon[drone]);

	flSide = -15.0;
	GetForwardPos(spawnPos, spawnAngle, 0.0, flSide, 0.0, lPos);

	TeleportEntity(hDroneLWeapon[drone], lPos, spawnAngle, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(hDroneLWeapon[drone], "SetParent", drone, hDroneLWeapon[drone], 0);
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

stock float ClampFloat(float value, float max, float min = 0.0)
{
	if (value > max)
		value = max;

	if (value < min)
		value = min;

	return value;
}

stock int GetNextWeapon(int drone)
{
	//return ((hLastWeaponFired[drone] == hDroneRWeapon[drone]) ? hDroneLWeapon[drone] : hDroneRWeapon[drone]);
	return ((hLastWeaponFired[drone] == 1) ? 0 : 1);
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
