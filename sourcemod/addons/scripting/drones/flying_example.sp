#pragma semicolon 1
#include <customdrones>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>

#define FAR_FUTURE 9999999999.0

#define FUELRODSOUND "weapons/cow_mangler_main_shot.wav"
#define PLASMASOUND "weapons/pomson_fire_01.wav"

int ClientDrone[MAXPLAYERS+1];
int Direction[2049];
float Inaccuracy[2049];
float BaseSpeed[2049];
float BoostSpeed[2049];
bool Attributed[2049] = false;
bool IsDrone[2049] = false;
bool Boosting[2049];

char sPluginName[2049][PLATFORM_MAX_PATH];

//Weapon variables
bool IsDroneRocket[2049];
bool FuelRod[2049];
int hLastWeaponFired[2049];

//Weapon function variables
float ProjDamage[2049][MAXWEAPONS+1];
float ProjSpeed[2049][MAXWEAPONS+1];

CDDmgType ProjDmgType[2049];

public Plugin MyInfo = {
	name 			= 	"[Custom Drones] Flying Drone",
	author 			=	"Ivory",
	description		= 	"Example of a flying drone",
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

void SetupWeaponStats(int drone, const char[] config)
{
	for (int i = 1; i <= 2; i++)
	{
		ProjDamage[drone][i] = CD_GetParamFloat(config, "damage", i);
		ProjSpeed[drone][i] = CD_GetParamFloat(config, "speed", i);
	}
	Inaccuracy[drone] = CD_GetParamFloat(config, "inaccuracy", 1);
	BoostSpeed[drone] = CD_GetParamFloat(config, "boost_speed");
	BaseSpeed[drone] = CD_GetParamFloat(config, "speed");
}

public void OnMapStart()
{
	PrecacheSound(PLASMASOUND);
	PrecacheSound(FUELRODSOUND);
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
		FuelRod[entity] = false;
	}
}

public void OnGameFrame()
{
	int hRocket = MaxClients+1;
	while ((hRocket = FindEntityByClassname(hRocket, "tf_projectile_energy_ball")) != -1)
	{
		ArcRocket(hRocket);
	}
}

//Drone weapon function
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
				if (buttons & IN_DUCK)
				{
					if (!Boosting[drone])
					{
						PrecacheSound("weapons/bumper_car_accelerate.wav");
						EmitSoundToAll("weapons/bumper_car_accelerate.wav", drone, SNDCHAN_AUTO, 100, _, 1.0);
						Boosting[drone] = true;
					}
					CD_OverrideMaxSpeed(drone, BoostSpeed[drone]);
				}
				else if (Boosting[drone])
				{
					Boosting[drone] = false;
					CD_OverrideMaxSpeed(drone, BaseSpeed[drone]);
					PrecacheSound("weapons/bumper_car_decelerate.wav");
					EmitSoundToAll("weapons/bumper_car_decelerate.wav", drone, SNDCHAN_AUTO, 100, _, 1.0);
				}
			}
		}
	}
}

public void CD_OnDroneAttack(int drone, int owner, int weapon, const char[] plugin)
{
	if (Attributed[drone] && !Boosting[drone])
	{
		//LogMessage("Active Drone Weapon: %i", weapon);
		switch (weapon)
		{
			case 1: //PlasmaCannon
			{
				FireRocket(owner, drone, weapon, hLastWeaponFired[drone], true);
				FireRocket(owner, drone, weapon, hLastWeaponFired[drone], false);
			}
			default: FireRocket(owner, drone, weapon, hLastWeaponFired[drone], true);
		}
	}
}

//Function for when the drone fires its active weapon
public void FireRocket(int owner, int drone, int pType, int fireLoc, bool playSound)
{
	char fireSound[64];

	float side = (fireLoc == 1) ? -10.0 : 10.0;
	float forwardPos = 65.0;
	int rocket;
	CDDmgType dType;

	float speed = ProjSpeed[drone][pType];
	float damage = ProjDamage[drone][pType];

	switch (pType)
	{
		case 1: //plasma
		{
			rocket = CD_SpawnRocket(owner, drone, DroneProj_Rocket, 0.0, speed, forwardPos, side, _, Inaccuracy[drone]);
			Format(fireSound, sizeof fireSound, PLASMASOUND);
			dType = DmgType_Plasma;
		}
		case 2: //fuelrod
		{
			rocket = CD_SpawnRocket(owner, drone, DroneProj_Energy, damage, speed, forwardPos, _, -15.0, Inaccuracy[drone]);
			Format(fireSound, sizeof fireSound, FUELRODSOUND);
			dType = DmgType_Missile;
		}
	}

	//Set rocket properties after spawning
	switch (pType)
	{
		case 1:
		{
			SetEntityModel(rocket, "models/weapons/w_models/w_baseball.mdl");
			SetEntPropFloat(rocket, Prop_Send, "m_flModelScale", 0.1);
			CreateParticle(rocket, "drg_cow_rockettrail_fire_blue", true);
			SDKHook(rocket, SDKHook_Touch, PlasmaHit);
		}
		case 2:
		{
			FuelRod[rocket] = true;
		}
	}

	ProjDmgType[rocket] = dType;
	if (playSound)
		EmitSoundToAll(fireSound, drone);

	IsDroneRocket[rocket] = true;

	hLastWeaponFired[drone] = GetNextWeapon(drone);
}

public Action PlayerTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidClient(client) && IsDroneRocket[inflictor] && IsValidDrone(ClientDrone[attacker]))
	{
		if (Attributed[ClientDrone[attacker]])
		{
			int drone = ClientDrone[attacker];

			//remove damage falloff and rampup based on player distance
			damagetype = DMG_ENERGYBEAM;

			damage = CalcDamageFromDistance(drone, client, damage, inflictor);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}


public Action PlasmaHit(int entity, int victim)
{
	if (CD_IsValidDrone(victim))
	{
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		CD_DroneTakeDamage(victim, owner, entity, ProjDamage[ClientDrone[owner]][1], false);
		AcceptEntityInput(entity, "Kill");
		return Plugin_Handled;
	}
	else if (!IsValidClient(victim))
	{
		char classname[64];
		GetEntityClassname(victim, classname, sizeof(classname));
		if (victim == 0 || !StrContains(classname, "prop_", false) || !StrContains(classname, "func_door", false))
		{
			AcceptEntityInput(entity, "Kill");
			return Plugin_Handled;
		}
		else if (!StrContains(classname, "obj_", false)) //engineer buildings
		{
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			SDKHooks_TakeDamage(victim, entity, owner, ProjDamage[ClientDrone[owner]][1], DMG_ENERGYBEAM);
		}
	}
	if (IsValidEntity(entity) && entity > 0)
	{
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (IsValidClient(owner) && IsValidClient(victim))
		{
			if (GetClientTeam(owner) != GetClientTeam(victim))
			{
				int drone = ClientDrone[owner];
				float damage = ProjDamage[drone][1];
				damage = CalcDamageFromDistance(drone, victim, damage, entity);
				SDKHooks_TakeDamage(victim, entity, owner, damage, DMG_ENERGYBEAM);
			}
		}
	}
	AcceptEntityInput(entity, "kill");
	return Plugin_Handled;
}

float CalcDamageFromDistance(int drone, int victim, float damage, int inflictor)
{
	float vecDronePos[3], vecViPos[3], distance;

	//Setup distance between drone and target
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", vecDronePos);
	GetClientAbsOrigin(victim, vecViPos);
	distance = GetVectorDistance(vecDronePos, vecViPos);

	//Damage falloff and rampup
	switch (ProjDmgType[inflictor])
	{
		case DmgType_Missile: //Missiles and rockets
		{
			//Standard rocketlauncher damage falloff and rampup values
			float dmgMod = ClampFloat((512.0 / distance), 1.25, 0.528);
			damage *= dmgMod;
		}
		case DmgType_Plasma: //Energy rifle
		{
			//Slightly less standard hitscan rampup and falloff
			float dmgMod = ClampFloat((512.0 / distance), 1.4, 0.85);
			damage *= dmgMod;
		}
	}
	return damage;
}

public void ArcRocket(int entity)
{
	if (FuelRod[entity])
	{
		float vecVel2[3], rotAng[3];
		float gravity2 = 1.8;

		GetEntPropVector(entity, Prop_Data, "m_vecVelocity", vecVel2);
		GetEntPropVector(entity, Prop_Send, "m_angRotation", rotAng);

		vecVel2[2] -= Pow(gravity2, 2.0);

		GetVectorAngles(vecVel2, rotAng);
		ClampAngle(rotAng);
		TeleportEntity(entity, NULL_VECTOR, rotAng, vecVel2);
	}
}

stock void ClampAngle(float fAngles[3])
{
	while(fAngles[0] > 89.0)  fAngles[0] -= 360.0;
	while(fAngles[0] < -89.0) fAngles[0] += 360.0;
	while(fAngles[1] > 180.0) fAngles[1] -= 360.0;
	while(fAngles[1] <-180.0) fAngles[1] += 360.0;
}

public void CD_OnDroneCreated(int drone, int owner, const char[] plugin_name, const char[] config)
{
	if (StrEqual(plugin_name, "flying_example"))
	{
		Format(sPluginName[drone], PLATFORM_MAX_PATH, plugin_name);
		SetupWeaponStats(drone, config);
		ClientDrone[owner] = drone;
		Attributed[drone] = true;
		hLastWeaponFired[drone] = 1;
		IsDrone[drone] = true;
	}
}

public void CD_OnDroneDestroyed(int drone, int owner, int attacker, float damage, const char[] plugin_name)
{
	if (Attributed[drone])
		Boosting[drone] = false;
}

public void CD_OnDroneRemoved(int drone, int owner, const char[] plugin_name)
{
	if (Attributed[drone])
	{
		IsDrone[drone] = false;
		Attributed[drone] = false;
		ClientDrone[owner] = -1;
	}
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
