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

bool Attributed[2049];

//weapon variables
float WeaponDamage[2049][MAXWEAPONS+1];
float Inaccuracy[2049][MAXWEAPONS+1];

//Chaingun variables
float CGAttackSpeed[2049];
float CGAttackDelay[2049];
float CGMaxAttackSpeed[2049];
float CGAccel[2049];
float CGStartRate[2049];
float CGIncreaseDelay[2049];

void SetDroneVars(const char[] config, int drone)
{
	for (int i = 0; i <= MAXWEAPONS; i++)
	{
		WeaponDamage[drone][i] = CD_GetParamFloat(config, "damage", i);
		Inaccuracy[drone][i] = CD_GetParamFloat(config, "inaccuracy", i);
	}
	
	//chaingun
	CGAccel[drone] = GetParamFloat(config, "attack_acceleration", 1);
	CGStartRate[drone] = GetParamFloat(config, "attack_start_rate:, 1);
	CGMaxAttackSpeed[drone] = GetParamFloat(config, "attack_time", 1);
}

public void CD_OnDroneAttack(int drone, int owner, int weapon, const char[] plugin)
{
	if (Attributed[drone])
	{
		switch (weapon)
		{
			case 1: //chaingun
			{
				float dronePos[3], offset[3], droneAngle[3], maxAngle[2];
				int tracerColor[4] = {230, 100, 0, 140};
				GetEntPropVector(drone, Prop_Data, "m_vecOrigin", dronePos);
				GetEntPropVector(drone, Prop_Send, "m_angRotation", droneAngle);
				offset = dronePos;
				maxAngle[0] = 20.0; //pitch
				maxAngle[1] = 40.0; //yaw
				offset[0] += 120.0;
				offset[2] -= 8.0;
				if (CGAttackSpeed[drone] == CGMaxAttackSpeed[drone])
				{
					CD_FireBullet(owner, drone, WeaponDamage[drone][weapon], dronePos, droneAngle, offset, 2.3, maxAngle, DmgType_Generic, tracerColor, CDWeapon_Auto);
				}
				else if (CGAttackDelay[drone] <= GetEngineTime())
				{
					CD_FireBullet(owner, drone, WeaponDamage[drone][weapon], dronePos, droneAngle, offset, 2.3, maxAngle, DmgType_Generic, tracerColor, CDWeapon_Auto);
					CGAttackSpeed[drone] -= CGAccel[drone];
					CGAttackDelay[drone] = GetEngineTime() + CGAttackSpeed[drone];
				}
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	int drone = ClientDrone[client];
	if (IsValidDrone(drone) && Attributed[drone])
	{
		bool attacking = (buttons & IN_ATTACK) != 0;
		if (!attacking && CGAttackSpeed[drone] < CGStartRate[drone])
		{
			CGAttackSpeed[drone] += CGAccel[drone] / 66.0;
			if (CGAttackSpeed[drone] >= CGStartRate[drone])
				CGAttackSpeed[drone] = CGStartRate[drone];
		}
	}
}

public void CD_OnDroneCreated(int drone, int owner, const char[] plugin, const char[] config)
{
	
}
