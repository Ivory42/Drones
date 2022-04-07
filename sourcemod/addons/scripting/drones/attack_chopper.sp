#pragma semicolon 1
#include <customdrones>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>

#define FAR_FUTURE 9999999999.0

public Plugin MyInfo = {
	name 			= 	"[Combat Drones] Combine Chopper",
	author 			=	"Ivory",
	description		= 	"Combine Chopper attack drone",
	version 		= 	"1.0"
};

int LastWeaponFired[2049];
int ClientDrone[MAXPLAYERS+1];
bool Attributed[2049];
char Config[2049][PLATFORM_MAX_PATH];

//Chaingun variables
bool CGActive[2049];
float CGPos[2049][3];
float CGAttackSpeed[2049];
float CGAttackDelay[2049];
float CGMaxAttackSpeed[2049];
float CGAccel[2049];
float CGStartRate[2049];
//float CGIncreaseDelay[2049];

//Missile variables
float MissileSpeed[2049];

//Bomb variables
float BombFuseTime[2049];
char BombModel[2049][PLATFORM_MAX_PATH];
bool BombProj[2049];

void SetDroneVars(const char[] config, int drone)
{
	//chaingun
	CGAccel[drone] = CD_GetParamFloat(config, "attack_acceleration", 1);
	CGStartRate[drone] = CD_GetParamFloat(config, "attack_start_rate", 1);
	CGMaxAttackSpeed[drone] = CD_GetParamFloat(config, "attack_time", 1);

	//Missiles
	MissileSpeed[drone] = CD_GetParamFloat(config, "speed", 2);

	//Bombs
	CD_GetParamString(config, "model", 3, BombModel[drone], PLATFORM_MAX_PATH);
	BombFuseTime[drone] = CD_GetParamFloat(config, "fuse", 3);
}

public Action CD_OnDroneAttack(int drone, int owner, DroneWeapon weapon, int slot, const char[] plugin)
{
	if (Attributed[drone])
	{
		switch (slot)
		{
			case 1: //chaingun
			{
				if (CGAttackSpeed[drone] <= CGMaxAttackSpeed[drone])
				{
					CD_FireBullet(owner, drone, weapon, DmgType_Generic, CDWeapon_Auto);
				}
				else if (CGAttackDelay[drone] <= GetEngineTime())
				{
					CD_FireBullet(owner, drone, weapon, DmgType_Generic, CDWeapon_Auto);
					CGAttackSpeed[drone] -= CGAccel[drone];
					if (CGAttackSpeed[drone] <= CGMaxAttackSpeed[drone]) CGAttackSpeed[drone] = CGMaxAttackSpeed[drone];
					CGAttackDelay[drone] = GetEngineTime() + CGAttackSpeed[drone];
				}
				else return Plugin_Stop;
			}
			case 2: //missiles
			{
				FireRocket(owner, drone, weapon, false);
				FireRocket(owner, drone, weapon, true);
			}
			case 3:
			{
				SpawnBomb(owner, drone, weapon);
			}
		}
	}
	return Plugin_Continue;
}

void FireRocket(int owner, int drone, DroneWeapon weapon, bool opposite)
{
	//Get Spawn Position
	if (opposite)
		weapon.offset[1] *= -1.0;	//adjust position based on the physical weapon being used on the drone

	float speed = MissileSpeed[drone];
	CD_SpawnRocket(owner, drone, weapon, DroneProj_Rocket, speed);
}

void SpawnBomb(int owner, int drone, DroneWeapon weapon)
{
	DroneBomb bombEnt;
	CD_SpawnDroneBomb(owner, drone, weapon, DroneProj_BombDelayed, BombModel[drone], BombFuseTime[drone], bombEnt);
}

public void OnEntityDestroyed(int entity)
{
	if (IsValidEntity(entity) && entity >= MaxClients)
	{
		BombProj[entity] = false;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	int drone = ClientDrone[client];
	if (CD_IsValidDrone(drone) && Attributed[drone])
	{
		bool attacking = (buttons & IN_ATTACK) != 0;
		if (!attacking && CGAttackSpeed[drone] < CGStartRate[drone])
		{
			CGAttackSpeed[drone] += CGAccel[drone] / 33.0;
			if (CGAttackSpeed[drone] >= CGStartRate[drone])
				CGAttackSpeed[drone] = CGStartRate[drone];
		}
	}
}

public void CD_OnDroneCreated(DroneProp Drone, const char[] plugin, const char[] config)
{
	if (StrEqual(plugin, "attack_chopper"))
	{
		int drone = Drone.GetDrone();
		SetEntPropFloat(drone, Prop_Send, "m_flModelScale", 0.35);
		Format(Config[drone], PLATFORM_MAX_PATH, config);
		SetDroneVars(config, drone);
		Attributed[drone] = true;
	}
}

public void CD_OnPlayerEnterDrone(DroneProp Drone, int client, int seat, const char[] plugin, const char[] config)
{
	int drone = Drone.GetDrone();
	switch (seat)
	{
		case 0: //pilot seat
		{
			ClientDrone[owner] = drone;
		}
	}
}

public void CD_OnPlayerExitDrone(DroneProp Drone, int client, int seat)
{
	ClientDrone[owner] = INVALID_ENT_REFERENCE;
}

public void OnDroneRemoved(int drone, int owner, const char[] plugin)
{
	if (Attributed[drone])
	{
		Attributed[drone] = false;
	}
}
