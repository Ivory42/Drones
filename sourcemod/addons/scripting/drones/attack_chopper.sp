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

//weapon variables
float WeaponDamage[2049][MAXWEAPONS+1];
float Inaccuracy[2049][MAXWEAPONS+1];

//Chaingun variables
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
	for (int i = 0; i <= MAXWEAPONS; i++)
	{
		WeaponDamage[drone][i] = CD_GetParamFloat(config, "damage", i);
		Inaccuracy[drone][i] = CD_GetParamFloat(config, "inaccuracy", i);
	}

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

public Action CD_OnDroneAttack(int drone, int owner, int weapon, const char[] plugin)
{
	if (Attributed[drone])
	{
		char fireSound[64];
		bool hasSound = CD_GetWeaponAttackSound(Config[drone], weapon, fireSound, sizeof fireSound);
		if (hasSound)
			PrecacheSound(fireSound);
		switch (weapon)
		{
			case 1: //chaingun
			{
				float dronePos[3], droneAngle[3], maxAngle[2];
				GetEntPropVector(drone, Prop_Data, "m_vecOrigin", dronePos);
				GetEntPropVector(drone, Prop_Send, "m_angRotation", droneAngle);
				maxAngle[0] = 180.0; //pitch
				maxAngle[1] = 40.0; //yaw
				if (CGAttackSpeed[drone] <= CGMaxAttackSpeed[drone])
				{
					CD_FireBullet(owner, drone, WeaponDamage[drone][weapon], dronePos, droneAngle, 160.0, 0.0, -60.0, Inaccuracy[drone][weapon], maxAngle, DmgType_Generic, CDWeapon_Auto);
				}
				else if (CGAttackDelay[drone] <= GetEngineTime())
				{
					CD_FireBullet(owner, drone, WeaponDamage[drone][weapon], dronePos, droneAngle, 160.0, 0.0, -60.0, Inaccuracy[drone][weapon], maxAngle, DmgType_Generic, CDWeapon_Auto);
					CGAttackSpeed[drone] -= CGAccel[drone];
					if (CGAttackSpeed[drone] <= CGMaxAttackSpeed[drone]) CGAttackSpeed[drone] = CGMaxAttackSpeed[drone];
					CGAttackDelay[drone] = GetEngineTime() + CGAttackSpeed[drone];
				}
				else return Plugin_Stop;
			}
			case 2: //missiles
			{
				FireRocket(owner, drone, weapon, LastWeaponFired[drone]);
				FireRocket(owner, drone, weapon, LastWeaponFired[drone]);
			}
			case 3:
			{
				SpawnBomb(drone, weapon);
			}
		}
		if (hasSound)
			EmitSoundToAll(fireSound, drone);
	}
	return Plugin_Continue;
}

void FireRocket(int owner, int drone, int type, int fireLoc)
{
	//Get Spawn Position
	float sideOffset = (fireLoc == 1) ? 45.0 : -45.0;					//adjust position based on the physical weapon being used on the drone

	float speed = MissileSpeed[drone];
	float damage = WeaponDamage[drone][type];
	float pos[3], angle[3];
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
	GetEntPropVector(drone, Prop_Send, "m_angRotation", angle);
	CD_SpawnRocket(owner, drone, pos, angle, DroneProj_Rocket, damage, speed, 125.0, sideOffset, -80.0, Inaccuracy[drone][type]);

	LastWeaponFired[drone] = (LastWeaponFired[drone] == 1) ? 0 : 1;	//Get next physical weapon to fire from
}

void SpawnBomb(int drone, int weapon)
{
	float pos[3], angle[3];
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
	GetEntPropVector(drone, Prop_Send, "m_angRotation", angle);
	float offset[3] = {0.0, 0.0, -60.0};

	DroneBomb bombEnt;
	CD_SpawnDroneBomb(drone, pos, angle, DroneProj_BombDelayed, WeaponDamage[drone][weapon], BombModel[drone], BombFuseTime[drone], offset, bombEnt);
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

public void CD_OnDroneCreated(int drone, int owner, const char[] plugin, const char[] config)
{
	if (StrEqual(plugin, "attack_chopper"))
	{
		SetEntPropFloat(drone, Prop_Send, "m_flModelScale", 0.35);
		Format(Config[drone], PLATFORM_MAX_PATH, config);
		SetDroneVars(config, drone);
		Attributed[drone] = true;
		ClientDrone[owner] = drone;
	}
}

public void OnDroneRemoved(int drone, int owner, const char[] plugin)
{
	if (Attributed[drone])
	{
		Attributed[drone] = false;
		ClientDrone[owner] = INVALID_ENT_REFERENCE;
	}
}
