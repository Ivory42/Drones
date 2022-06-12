#pragma semicolon 1
#include <customdrones>
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>

#define FAR_FUTURE 9999999999.0

#define PODMODEL "models/weapons/c_models/c_blackbox/c_blackbox.mdl"
#define MISSILEMODEL "models/weapons/c_models/c_rocketlauncher/c_rocketlauncher.mdl"
#define ENERGYMODEL "models/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl"
#define PLASMAMODEL	"models/weapons/c_models/c_drg_pomson/c_drg_pomson.mdl"

int ClientDrone[MAXPLAYERS+1];
bool ThisDrone[MAXPLAYERS+1];

bool Attributed[2049];

char sPluginName[2049][PLATFORM_MAX_PATH];

//Physical Weapons
int DroneRWeapon[2049];
int DroneLWeapon[2049];

//Weapon variables
float RocketFireDelay[2049];
float BarrageRate[2049];
int RocketCount[2049];
int BarrageMaxCount[2049];
bool IsDroneRocket[2049];
bool InBarrage[2049];
bool WeaponUseOppositeSide[2049][MAXWEAPONS];

CDDmgType pType[2049];

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
	BarrageMaxCount[drone] = CD_GetParamInteger(config, "burst_count", 4);
	BarrageRate[drone] = CD_GetParamFloat(config, "attack_time", 4);
}

public void OnMapStart()
{
	PrecacheModel(MISSILEMODEL);
	PrecacheModel(ENERGYMODEL);
	PrecacheModel(PODMODEL);
	PrecacheModel(PLASMAMODEL);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, PlayerTakeDamage);
}

public void OnEntityDestroyed(int entity)
{
	if (IsValidEntity(entity) && entity > MaxClients)
	{
		IsDroneRocket[entity] = false;
	}
}

stock void DetachDroneWeapons(int drone)
{
	int rWeapon = EntRefToEntIndex(DroneRWeapon[drone]);
	if (IsValidEntity(rWeapon))
		AcceptEntityInput(rWeapon, "ClearParent");

	int lWeapon = EntRefToEntIndex(DroneLWeapon[drone]);
	if (IsValidEntity(lWeapon))
		AcceptEntityInput(lWeapon, "ClearParent");
}

///
/// When a player fires the missile pod, it should continue firing until the weapon is switched or out of ammo
///

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsValidClient(client) && CD_IsValidDrone(ClientDrone[client]))
	{
		int drone = ClientDrone[client];
		if (Attributed[drone] && ThisDrone[client])
		{
			DroneProp Drone;
			CD_GetClientDrone(client, Drone);
			int droneHP = RoundFloat(Drone.health);
			if (droneHP > 0)
			{
				//Rocket Pods function
				if (InBarrage[drone] && Drone.activeweapon != 4)
				{
					InBarrage[drone] = false;
				}
				if (InBarrage[drone] && RocketCount[drone] > 0 && RocketFireDelay[drone] <= GetGameTime())
				{
					DroneWeapon weapon;
					CD_GetDroneWeapon(drone, 4, weapon);
					if (weapon.state == WeaponState_Reloading)
						InBarrage[drone] = false;

					CD_FireActiveWeapon(client, drone);
					RocketFireDelay[drone] = GetGameTime() + BarrageRate[drone];
				}
				else if (RocketCount[drone] <= 0)
				{
					InBarrage[drone] = false;
				}
			}
		}
	}
	return Plugin_Continue;
}

///
///Function for when the drone fires its active weapon
///

public Action CD_OnDroneAttack(int drone, int gunner, DroneWeapon weapon, int slot, const char[] plugin)
{
	if (Attributed[drone] && ThisDrone[gunner])
	{
		switch (slot)
		{
			case 3: //plasma rifle
			{
				//Fire from both weapons
				FireRocket(gunner, drone, weapon, slot, WeaponUseOppositeSide[drone][slot]);
				FireRocket(gunner, drone, weapon, slot, WeaponUseOppositeSide[drone][slot]);
			}
			case 4: //Rocket pods
			{
				if (!InBarrage[drone])
				{
					RocketCount[drone] = BarrageMaxCount[drone];
					FireRocket(gunner, drone, weapon, 4, WeaponUseOppositeSide[drone][slot]);
					RocketCount[drone]--;
					RocketFireDelay[drone] = GetGameTime() + BarrageRate[drone];
					InBarrage[drone] = true;
				}
				else
				{
					FireRocket(gunner, drone, weapon, 4, WeaponUseOppositeSide[drone][slot]);
					RocketCount[drone]--;
					RocketFireDelay[drone] = GetGameTime() + BarrageRate[drone];
				}

			}
			default: FireRocket(gunner, drone, weapon, slot, WeaponUseOppositeSide[drone][slot]);
		}
	}
	return Plugin_Continue;
}

public void FireRocket(int owner, int drone, DroneWeapon weapon, int slot, bool &opposite)
{
	//Get Spawn Position
	if (opposite)
		weapon.offset[1] *= -1.0;	//Adjust position based on the physical weapon being used on the drone

	opposite = !opposite;			//Alternate between firing positions each time we fire.
	int rocket;

	//Create Rocket
	switch (slot)
	{
		case 1: rocket = CD_SpawnRocket(owner, drone, weapon, DroneProj_Rocket); //Normal Rockets
		case 2: //Energy Rockets
		{
			rocket = CD_SpawnRocket(owner, drone, weapon, DroneProj_Energy);
			pType[rocket] = DmgType_Custom;
		}
		case 3: //Energy Orbs
		{
			rocket = CD_SpawnRocket(owner, drone, weapon, DroneProj_Impact);
			SetEntityModel(rocket, "models/weapons/w_models/w_baseball.mdl");
			SetEntPropFloat(rocket, Prop_Send, "m_flModelScale", 0.1);
			CreateParticle(rocket, "drg_cow_rockettrail_fire_blue", true);
		}
		case 4: rocket = CD_SpawnRocket(owner, drone, weapon, DroneProj_Sentry); //Rocekt Pods
	}
	IsDroneRocket[rocket] = true;
}

public Action PlayerTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidClient(client) && IsDroneRocket[inflictor] && CD_IsValidDrone(ClientDrone[attacker]))
	{
		if (Attributed[ClientDrone[attacker]] && pType[inflictor] == DmgType_Custom)
		{
			//remove damage falloff and rampup
			damagetype = DMG_ENERGYBEAM;
			pType[inflictor] = DmgType_Default;
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

public void CD_OnWeaponChanged(int drone, int owner, DroneWeapon weapon, int slot, const char[] plugin_name)
{
	if (StrEqual(plugin_name, "example_drone"))
		SetWeaponModels(drone, slot); //set model to weapon being switched to
}

public void CD_OnDroneCreated(DroneProp drone, const char[] plugin_name, const char[] config)
{
	if (StrEqual(plugin_name, "example_drone"))
	{
		int droneEnt = drone.GetDrone();
		if (CD_IsValidDrone(droneEnt))
		{
			Format(sPluginName[droneEnt], PLATFORM_MAX_PATH, plugin_name);
			SetupWeaponStats(config, droneEnt);
			float angles[3], pos[3];
			GetEntPropVector(droneEnt, Prop_Data, "m_vecOrigin", pos);
			GetEntPropVector(droneEnt, Prop_Send, "m_angRotation", angles);
			Attributed[droneEnt] = true;
			CreateDroneWeapons(droneEnt, pos, angles);
		}
	}
}

public void CD_OnPlayerEnterDrone(DroneProp Drone, int client, int seat, const char[] plugin, const char[] config)
{
	int drone = Drone.GetDrone();
	switch (seat)
	{
		case 0: //pilot seat
		{
			ClientDrone[client] = drone;
			ThisDrone[client] = true;
		}
	}
}

public void CD_OnPlayerExitDrone(DroneProp Drone, int client, int seat)
{
	ClientDrone[client] = INVALID_ENT_REFERENCE;
	ThisDrone[client] = false;
}

public void CD_OnDroneRemoved(int drone, const char[] plugin_name)
{
	if (Attributed[drone])
	{
		Attributed[drone] = false;
		int weapon = EntRefToEntIndex(DroneRWeapon[drone]);
		if (IsValidEntity(weapon) && weapon > MaxClients)
			RemoveEntity(weapon);

		weapon = EntRefToEntIndex(DroneLWeapon[drone]);
		if (IsValidEntity(weapon) && weapon > MaxClients)
			RemoveEntity(weapon);

		DroneRWeapon[drone] = INVALID_ENT_REFERENCE;
		DroneLWeapon[drone] = INVALID_ENT_REFERENCE;
	}
}

///
/// Set the actual models of our weapons
///

stock void SetWeaponModels(int drone, int slot)
{
	int lWeapon = EntRefToEntIndex(DroneLWeapon[drone]);
	int rWeapon = EntRefToEntIndex(DroneRWeapon[drone]);

	//if either of these are not valid, do not proceed
	if (!IsValidEntity(lWeapon)) return;
	if (!IsValidEntity(rWeapon)) return;

	switch (slot)
	{
		case 1:
		{
			SetEntityModel(rWeapon, MISSILEMODEL);
			SetEntityModel(lWeapon, MISSILEMODEL);
		}
		case 2:
		{
			SetEntityModel(rWeapon, ENERGYMODEL);
			SetEntityModel(lWeapon, ENERGYMODEL);
		}
		case 3:
		{
			SetEntityModel(rWeapon, PLASMAMODEL);
			SetEntityModel(lWeapon, PLASMAMODEL);
		}
		case 4:
		{
			SetEntityModel(rWeapon, PODMODEL);
			SetEntityModel(lWeapon, PODMODEL);
		}
	}
}

///
///Create and set visual models for weapons
///This is completely cosmetic and is not required
///This drone just uses a city scanner model so there isn't enough room to place weapons around the drone.
///To get around this, we will use a single pair of models that will change based on the active weapon.
///

stock void CreateDroneWeapons(int drone, float spawnPos[3], float spawnAngle[3])
{
	float lPos[3], rPos[3];
	float flSide;

	//Right weapon
	int rWeapon = CreateEntityByName("prop_physics_override");
	DispatchKeyValue(rWeapon, "model", MISSILEMODEL);

	DispatchSpawn(rWeapon);
	ActivateEntity(rWeapon);

	flSide = 15.0;
	GetForwardPos(spawnPos, spawnAngle, 0.0, flSide, 0.0, rPos);

	TeleportEntity(rWeapon, rPos, spawnAngle, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(rWeapon, "SetParent", drone, rWeapon, 0);

	DroneRWeapon[drone] = EntIndexToEntRef(rWeapon);

	//Left Weapon
	int lWeapon = CreateEntityByName("prop_physics_override");
	DispatchKeyValue(lWeapon, "model", MISSILEMODEL);

	DispatchSpawn(lWeapon);
	ActivateEntity(lWeapon);

	flSide = -15.0;
	GetForwardPos(spawnPos, spawnAngle, 0.0, flSide, 0.0, lPos);

	TeleportEntity(lWeapon, lPos, spawnAngle, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(lWeapon, "SetParent", drone, lWeapon, 0);

	DroneLWeapon[drone] = EntIndexToEntRef(lWeapon);
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
