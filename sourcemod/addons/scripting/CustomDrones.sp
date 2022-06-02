#pragma semicolon 1
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <tf2attributes>
#include <customdrones>


#define FAR_FUTURE 	999999999.0

//Forwards

GlobalForward DroneCreated;
GlobalForward DroneEntered;
GlobalForward DroneExited;
GlobalForward DroneExplode;
GlobalForward DroneDestroy;
GlobalForward DroneChangeWeapon;
GlobalForward DroneAttack;

float FlyMinSpeed = 200.0;
DroneProp DroneInfo[2049];
DroneBomb BombInfo[2049];

int DroneRef[MAXPLAYERS+1];

int PlayerSpecCamera[MAXPLAYERS+1];
int PlayerSpecCameraAnchor[MAXPLAYERS+1];
int PlayerSpecDrone[MAXPLAYERS+1]; //drone being spectated
bool SpecDrone[MAXPLAYERS+1];
bool FirstPersonSpec[MAXPLAYERS+1];

int ExplosionSprite;
DroneWeapon WeaponProps[2048][MAXWEAPONS];
float DroneYaw[2048][2];
float TurnRate[2048];
float RollRate = 0.8;
float DroneExplodeDelay[2049];
float SparkDelay[2049];
float DroneSpeed[MAXPLAYERS+1][6];
float flRoll[MAXPLAYERS+1];

bool IsInDrone[MAXPLAYERS+1];
bool IsDrone[2048];

public Plugin MyInfo = {
	name 			= 	"[TF2] Custom Drones",
	author 			=	"Ivory",
	description		= 	"Customizable drones for Team Fortress 2",
	version 		= 	"1.3.6"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_drone", CmdDrone, ADMFLAG_ROOT);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("post_inventory_application", OnPlayerResupply);
	AddCommandListener(ChangeSpec, "spec_next");
	AddCommandListener(ChangeSpec, "spec_prev");
	AddCommandListener(ChangeSpecMode, "spec_mode");
	ExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");

	//Forwards
	DroneCreated = CreateGlobalForward("CD_OnDroneCreated", ET_Ignore, Param_Any, Param_String, Param_String); //drone struct, plugin, config
	DroneEntered = CreateGlobalForward("CD_OnPlayerEnterDrone", ET_Ignore, Param_Any, Param_Cell, Param_Cell, Param_String, Param_String); //drone struct, client, seat, plugin, config
	DroneExited = CreateGlobalForward("CD_OnPlayerExitDrone", ET_Ignore, Param_Any, Param_Cell, Param_Cell, Param_String, Param_String); //drone struct, client, seat, plugin, config
	DroneExplode = CreateGlobalForward("CD_OnDroneRemoved", ET_Ignore, Param_Cell, Param_String); //drone, plugin
	DroneChangeWeapon = CreateGlobalForward("CD_OnWeaponChanged", ET_Hook, Param_Cell, Param_Cell, Param_Any, Param_Cell, Param_String); //drone, owner, weapon, slot, plugin
	DroneDestroy = CreateGlobalForward("CD_OnDroneDestroyed", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_String); //drone, owner, attacker, damage, plugin
	DroneAttack = CreateGlobalForward("CD_OnDroneAttack", ET_Hook, Param_Cell, Param_Cell, Param_Any, Param_Cell, Param_String); //drone, gunner, weapon, slot, plugin
}

Action OnPlayerResupply(Event event, const char[] name, bool dBroad)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsInDrone[client])
	{
		CreateTimer(0.5, DroneResupplied, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action DroneResupplied(Handle timer, int client)
{
	RemoveWearables(client);
	//TF2_RemoveAllWeapons(client);
}

Action ChangeSpec(int client, const char[] command, int args)
{
	RemoveSpecCamera(client);
}

Action ChangeSpecMode(int client, const char[] command, int args)
{
	if (SpecDrone[client] && !FirstPersonSpec[client])
	{
		int camera = GetDroneCamera(PlayerSpecDrone[client]);
		if (IsValidEntity(camera) && camera > MaxClients)
		{
			SetClientViewEntity(client, camera);
			FirstPersonSpec[client] = true;
		}
	}
	else if (SpecDrone[client] && FirstPersonSpec[client])
	{
		SetClientViewEntity(client, PlayerSpecCamera[client]);
		FirstPersonSpec[client] = false;
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CD_GetDroneHealth", Native_GetDroneHealth); //deprecated
	CreateNative("CD_GetDroneMaxHealth", Native_GetDroneMaxHealth); //deprecated
	CreateNative("CD_SpawnDroneByName", Native_SpawnDroneName);
	CreateNative("CD_GetDroneWeapon", Native_GetDroneWeapon);
	CreateNative("CD_GetDroneActiveWeapon", Native_GetDroneActiveWeapon); //deprecated
	CreateNative("CD_SetDroneActiveWeapon", Native_SetDroneWeapon);
	CreateNative("CD_SetWeaponReloading", Native_SetWeaponReload);
	CreateNative("CD_GetParamFloat", Native_GetFloatParam);
	CreateNative("CD_GetParamInteger", Native_GetIntParam);
	CreateNative("CD_SpawnRocket", Native_SpawnRocket);
	CreateNative("CD_GetClientDrone", Native_GetDrone);
	CreateNative("CD_IsValidDrone", Native_ValidDrone);
	CreateNative("CD_DroneTakeDamage", Native_DroneTakeDamage);
	CreateNative("CD_FireActiveWeapon", Native_FireWeapon);
	CreateNative("CD_FireBullet", Native_HitscanAttack);
	CreateNative("CD_OverrideMaxSpeed", Native_OverrideMaxSpeed);
	CreateNative("CD_ToggleViewLocked", Native_ViewLock);
	CreateNative("CD_GetWeaponAttackSound", Native_AttackSound); //deprecated
	CreateNative("CD_GetParamString", Native_GetString);
	CreateNative("CD_SpawnDroneBomb", Native_SpawnBomb);
	return APLRes_Success;
}

/********************************************************************************

	NATIVES

********************************************************************************/

public any Native_ViewLock(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	if (IsValidDrone(drone))
		DroneInfo[drone].viewlocked = !DroneInfo[drone].viewlocked;
	else
		ThrowNativeError(017, "Entity index %i is not a valid drone", drone);

	return DroneInfo[drone].viewlocked;
}

public int Native_OverrideMaxSpeed(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	float speed = GetNativeCell(2);

	if (IsValidDrone(drone))
		DroneInfo[drone].speedoverride = speed;
	else
		ThrowNativeError(017, "Entity index %i is not a valid drone", drone);
}

public int Native_FireWeapon(Handle plugin, int args)
{
	int owner = GetNativeCell(1);
	int drone = GetNativeCell(2);
	int slot = DroneInfo[drone].activeweapon;

	if (WeaponProps[drone][slot].CanFire(true))
		FireWeapon(owner, drone, slot, WeaponProps[drone][slot]);
}

public int Native_DroneTakeDamage(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	int attacker = GetNativeCell(2);
	int inflictor = GetNativeCell(3);
	float damage = GetNativeCell(4);
	bool crit = view_as<bool>(GetNativeCell(5));

	DroneTakeDamage(DroneInfo[drone], drone, attacker, inflictor, damage, crit);
}

public int Native_ValidDrone(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	if (IsValidDrone(drone))
		return true;

	return false;
}

public int Native_GetDroneHealth(Handle plugin, int args)
{
	/*
	int drone = GetNativeCell(1);
	int iDroneHP2 = RoundFloat(DroneHealth[drone]);
	return iDroneHP2;
	*/
}

public int Native_GetDroneMaxHealth(Handle plugin, int args)
{
	/*
	int drone = GetNativeCell(1);
	int iDroneMaxHP = RoundFloat(DroneMaxHealth[drone]);
	return iDroneMaxHP;
	*/
}

public any Native_GetDroneWeapon(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	int slot = GetNativeCell(2);
	SetNativeArray(3, WeaponProps[drone][slot], sizeof DroneWeapon);
}


public any Native_GetDroneActiveWeapon(Handle plugin, int args)
{
	/*
	int drone = GetNativeCell(1);
	int owner = GetEntPropEnt(drone, Prop_Data, "m_hOwnerEntity");
	if (IsValidClient(owner))
		SetNativeArray(2, WeaponProps[drone][DroneInfo[owner].activeweapon], sizeof DroneWeapon);
		*/
}

public int Native_SetDroneWeapon(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	int slot = GetNativeCell(2);
	if (IsValidDrone(drone))
		DroneInfo[drone].activeweapon = slot;
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
	//int drone = GetNativeCell(1);
	float delay = GetNativeCell(3);
	DroneWeapon weapon;
	GetNativeArray(2, weapon, sizeof DroneWeapon);

	if (!delay)
		delay = weapon.reloadtime;

	weapon.SimulateReload();
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

public any Native_GetString(Handle plugin, int args)
{
	char config[64], key[64], weapon[64];
	int weaponId = GetNativeCell(3);
	GetNativeString(1, config, sizeof config);
	GetNativeString(2, key, sizeof key);
	int size = GetNativeCell(5);
	char[] result = new char[size];

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
	drone.GetString(key, result, size);
	delete drone;
	SetNativeString(4, result, size);
}

public any Native_AttackSound(Handle plugin, int args)
{
	/*
	char config[64], weapon[64];
	int weaponId = GetNativeCell(2);
	GetNativeString(1, config, sizeof config);
	int size = GetNativeCell(4);
	char[] result = new char[size];

	KeyValues drone = new KeyValues("Drone");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", config);
	drone.ImportFromFile(path);
	drone.JumpToKey("weapons");
	Format(weapon, sizeof weapon, "weapon%i", weaponId);
	if (drone.JumpToKey(weapon))
	{
		drone.GetString("sound", result, size);
		delete drone;
		if (strlen(result) <= 0) return false;
		SetNativeString(3, result, size);
		return true;
	}
	else
	{
		delete drone;
		ThrowNativeError(017, "Drone %s does not have weapon with ID %i", config, weaponId);
	}
	delete drone;
	return false;
	*/
}

public any Native_HitscanAttack(Handle plugin, int args)
{
	int owner = GetNativeCell(1);
	int drone = GetNativeCell(2);
	DroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof DroneWeapon);
	float pos[3], rot[3];
	weapon.GetMuzzleTransform(pos, rot); //get our weapon's muzzle position
	CDDmgType dmgType = view_as<CDDmgType>(GetNativeCell(4));
	CDWeaponType type = view_as<CDWeaponType>(GetNativeCell(5));
	if (IsValidClient(owner) && IsValidDrone(drone))
	{
		float angle[3], aimPos[3], aimVec[3], aimAngle[3], cameraPos[3], droneAngle[3], dronePos[3];
		GetClientEyeAngles(owner, aimAngle);
		GetEntPropVector(drone, Prop_Send, "m_angRotation", droneAngle);
		GetEntPropVector(drone, Prop_Data, "m_vecOrigin", dronePos);
		GetForwardPos(dronePos, droneAngle, 0.0, 0.0, DroneInfo[drone].cameraheight, cameraPos); //Get our camera height relative to our drone's forward vector
		CD_GetDroneAimPosition(drone, cameraPos, aimAngle, aimPos);	//find where the client is aiming at in relation to the drone

		MakeVectorFromPoints(pos, aimPos, aimVec); //draw vector from offset position to our aim position
		GetVectorAngles(aimVec, angle);

		//restrict angle at which projectiles can be fired, not yet working
		//if (angle[0] >= forwardAngle[0] + maxAngle[0]) angle[0] = forwardAngle[0] + maxAngle[0];
		//if (angle[0] >= forwardAngle[0] - maxAngle[0]) angle[0] = forwardAngle[0] - maxAngle[0];
		//if (angle[1] >= forwardAngle[1] + maxAngle[1]) angle[1] = forwardAngle[1] + maxAngle[1];
		//if (angle[1] >= forwardAngle[1] - maxAngle[1]) angle[1] = forwardAngle[1] - maxAngle[1];

		if (weapon.inaccuracy)
		{
			angle[0] += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
			angle[1] += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
		}

		Handle bullet = TR_TraceRayFilterEx(pos, angle, MASK_SHOT, RayType_Infinite, FilterDroneShoot, drone);
		if (TR_DidHit(bullet))
		{
			int victim = TR_GetEntityIndex(bullet);
			bool isDrone = IsValidDrone(victim);
			float endPos[3];

			TR_GetEndPosition(endPos, bullet);
			switch (type)
			{
				case CDWeapon_Auto:
				{
					CreateTracer(drone, pos, endPos);
				}
				case CDWeapon_Laser:
				{
					//TE_SetupBeamPoints(pos, endPos, PrecacheModel("materials/sprites/laser.vmt"), PrecacheModel("materials/sprites/laser.vmt"), 0, 1, 0.1, 7.0, 0.1, 10, 0.0, color, 10);
					//TE_SendToAll();
				}
				case CDWeapon_SlowFire:
				{
					CreateTracer(drone, pos, endPos);
				}
			}

			switch (dmgType)
			{
				case DmgType_Rangeless: //no damage falloff
				{
					if (isDrone)
						DroneTakeDamage(DroneInfo[victim], victim, owner, drone, weapon.damage, false);
					else
						SDKHooks_TakeDamage(victim, owner, owner, weapon.damage, DMG_ENERGYBEAM);
				}
				default:
				{
					if (victim > 0)
					{
						float damage = Damage_Hitscan(victim, drone, weapon.damage);
						if (isDrone)
							DroneTakeDamage(DroneInfo[victim], victim, owner, drone, damage, false);
						else
							SDKHooks_TakeDamage(victim, owner, owner, damage, DMG_ENERGYBEAM);
					}
				}
			}
		}
	}
}

//create a visual bullet tracer
void CreateTracer(int owner, float start[3], float end[3])
{
	if (!IsDrone[owner]) return;
	int target = CreateEntityByName("prop_dynamic_override"); //env_gunfire requres an entity to use as a target
	char targetname[64];
	Format(targetname, sizeof targetname, "target%i", target);
	DispatchKeyValue(target, "targetname", targetname);
	SetEntityModel(target, "models/empty.mdl");
	DispatchSpawn(target);
	TeleportEntity(target, end, NULL_VECTOR, NULL_VECTOR);

	int tracer = CreateEntityByName("env_gunfire"); //create the actual tracer
	DispatchKeyValue(tracer, "target", targetname);
	DispatchKeyValue(tracer, "minburstsize", "1");
	DispatchKeyValue(tracer, "maxburstsize", "1");
	DispatchKeyValue(tracer, "minburstdelay", "5.0");
	DispatchKeyValue(tracer, "maxburstdelay", "10.0");
	DispatchKeyValue(tracer, "rateoffire", "1.0");
	DispatchKeyValue(tracer, "collisions", "1");
	DispatchKeyValue(tracer, "spread", "0");

	DispatchSpawn(tracer);
	ActivateEntity(tracer);

	TeleportEntity(tracer, start, NULL_VECTOR, NULL_VECTOR);

	//remove our tracer and target shortly after
	int targRef = EntIndexToEntRef(target);
	CreateTimer(0.5, RemoveTarget, targRef);
	int traceRef = EntIndexToEntRef(tracer);
	CreateTimer(0.5, RemoveTracer, traceRef);
}

Action RemoveTarget(Handle timer, any ref)
{
	int target = EntRefToEntIndex(ref);
	if (IsValidEntity(target) && target > MaxClients)
	{
		RemoveEntity(target);
	}
}

Action RemoveTracer(Handle timer, any ref)
{
	int tracer = EntRefToEntIndex(ref);
	if (IsValidEntity(tracer) && tracer > MaxClients)
	{
		RemoveEntity(tracer);
	}
}

bool FilterDroneShoot(int entity, int mask, int drone)
{
	int owner = DroneInfo[drone].GetOwner();
	if (IsValidClient(entity)) //ignore teammates
	{
		if (IsValidClient(owner) && GetClientTeam(owner) == GetClientTeam(entity))
			return false;
	}
	if (entity == drone)
		return false;

	return true;
}

float Damage_Hitscan(int victim, int drone, float baseDamage)
{
	float dronePos[3], vicPos[3], distance;

	//Setup distance between drone and target
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", dronePos);
	GetEntPropVector(victim, Prop_Data, "m_vecOrigin", vicPos);
	distance = GetVectorDistance(dronePos, vicPos);
	float dmgMod = ClampFloat((512.0 / distance), 1.5, 0.528);
	baseDamage *= dmgMod;

	return baseDamage;
}

public any Native_SpawnRocket(Handle Plugin, int args)
{
	int owner = GetNativeCell(1);
	int drone = GetNativeCell(2);
	float pos[3];
	DroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof DroneWeapon);
	float rot[3];
	weapon.GetMuzzleTransform(pos, rot);
	ProjType projectile = GetNativeCell(4);

	//PrintToConsole(owner, "Damage: %.1f\nSpeed: %.1f\noffset x: %.1f\noffset y: %.1f\noffset z: %.1f", damage, speed, overrideX, overrideY, overrideZ);

	float velocity[3], aimAngle[3], dronePos[3], droneAngle[3], aimPos[3], aimVec[3], cameraPos[3];
	char netname[64], classname[64];

	//Get Spawn Position
	GetClientEyeAngles(owner, aimAngle);
	GetEntPropVector(drone, Prop_Send, "m_angRotation", droneAngle);
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", dronePos);
	cameraPos = dronePos;
	GetForwardPos(cameraPos, droneAngle, 0.0, 0.0, DroneInfo[drone].cameraheight, cameraPos); //Get our camera height relative to our drone's forward vector
	CD_GetDroneAimPosition(drone, cameraPos, aimAngle, aimPos);	//find where the client is aiming at in relation to the drone

	MakeVectorFromPoints(pos, aimPos, aimVec); //draw vector from offset position to our aim position
	GetVectorAngles(aimVec, aimAngle);

	if (weapon.inaccuracy)
	{
		aimAngle[0] += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
		aimAngle[1] += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
	}
	GetAngleVectors(aimAngle, velocity, NULL_VECTOR, NULL_VECTOR);
	switch (projectile)
	{
		case DroneProj_Energy:
		{
			FormatEx(classname, sizeof classname, "tf_projectile_energy_ball");
			FormatEx(netname, sizeof netname, "CTFProjectile_EnergyBall");
		}
		case DroneProj_Sentry:
		{
			FormatEx(classname, sizeof classname, "tf_projectile_sentryrocket");
			FormatEx(netname, sizeof netname, "CTFProjectile_SentryRocket");
		}
		default:
		{
			FormatEx(classname, sizeof classname, "tf_projectile_rocket");
			FormatEx(netname, sizeof netname, "CTFProjectile_Rocket");
		}
	}
	int rocket = CreateEntityByName(classname);
	ScaleVector(velocity, weapon.projspeed);
	SetEntPropVector(rocket, Prop_Send, "m_vInitialVelocity", velocity);
	int team = GetClientTeam(owner);

	//teleport to proper position and then spawn
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", owner);
	TeleportEntity(rocket, pos, aimAngle, velocity);

	SetVariantInt(team);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);

	SetVariantInt(team);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0);

	DispatchSpawn(rocket);
	SetEntDataFloat(rocket, FindSendPropInfo(netname, "m_iDeflected") + 4, weapon.damage); //Set Damage for rocket

	if (projectile == DroneProj_Impact)
		SDKHook(rocket, SDKHook_Touch, OnProjHit);

	return rocket;
}

Action OnProjHit(int entity, int victim)
{
	if (!IsValidClient(victim))
	{
		if (IsValidDrone(victim))
		{
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			float damage = GetEntDataFloat(entity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4); //get our damage
			DroneTakeDamage(DroneInfo[victim], victim, owner, entity, damage, false);
			RemoveEntity(entity);
			return Plugin_Handled;
		}
		char classname[64];
		GetEntityClassname(victim, classname, sizeof(classname));
		if (victim == 0 || !StrContains(classname, "prop_", false))
		{
			RemoveEntity(entity);
			return Plugin_Handled;
		}
		else if (StrContains(classname, "obj_", false)) //engineer buildings
		{
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			float damage = GetEntDataFloat(entity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4); //get our damage
			SDKHooks_TakeDamage(victim, entity, owner, damage, DMG_ENERGYBEAM);
			RemoveEntity(entity);
			return Plugin_Handled;
		}
		else return Plugin_Continue;
	}
	else
	{
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (IsValidClient(owner) && IsValidClient(victim))
		{
			if (GetClientTeam(owner) != GetClientTeam(victim))
			{
				int drone = GetClientDrone(owner);
				float dronePos[3], victimPos[3], distance, damage;
				damage = GetEntDataFloat(entity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4);

				//Setup distance between drone and target
				GetEntPropVector(drone, Prop_Data, "m_vecOrigin", dronePos);
				GetClientAbsOrigin(victim, victimPos);
				distance = GetVectorDistance(dronePos, victimPos);

				//Standard rampup and falloff for rockets
				float dmgMod = ClampFloat((512.0 / distance), 1.25, 0.528);
				damage *= dmgMod;
				SDKHooks_TakeDamage(victim, entity, owner, damage, DMG_ENERGYBEAM);
			}
		}
	}
	RemoveEntity(entity);
	return Plugin_Handled;
}

///
///	Drone Bomb Functions
///

public any Native_SpawnBomb(Handle Plugin, int args)
{
	int drone = GetNativeCell(2);
	int owner = GetNativeCell(1);
	DroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof DroneWeapon);
	float pos[3];
	float angle[3];
	weapon.GetMuzzleTransform(pos, angle);
	ProjType projectile = GetNativeCell(4);
	char modelname[256];
	GetNativeString(5, modelname, sizeof modelname);
	float fuse = GetNativeCell(6);
	DroneBomb bombEnt;
	bombEnt.create(owner, modelname, weapon.damage, fuse, 200.0, pos);
	SetEntPropEnt(bombEnt.bomb, Prop_Send, "m_hOwnerEntity", owner);
	bombEnt.type = projectile;
	bombEnt.isBomb = true;
	bombEnt.drone = drone;
	switch (projectile)
	{
		case DroneProj_BombDelayed:
		{
			BombInfo[bombEnt.bomb] = bombEnt;
			SDKHook(bombEnt.bomb, SDKHook_VPhysicsUpdate, BombDelayUpdate);
		}
		case DroneProj_BombImpact:
		{
			BombInfo[bombEnt.bomb] = bombEnt;
			SDKHook(bombEnt.bomb, SDKHook_VPhysicsUpdate, BombImpactUpdate);
		}
		case DroneProj_Custom:
		{
			//Use this type to prevent any default behavior with bombs.
			//Everything can safely be handled within your sub-plugin if using this type.
		}
		default:
		{
			BombInfo[bombEnt.bomb] = bombEnt;
			CreateTimer(bombEnt.fuseTime, DetonateBombTimer, bombEnt.bomb, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	SetNativeArray(7, bombEnt, sizeof bombEnt);
	return IsValidEntity(bombEnt.bomb);
}

Action DetonateBombTimer(Handle timer, int bomb)//
{
	if (IsValidEntity(bomb) && bomb > MaxClients)
	{
		BombInfo[bomb].detonate();
	}
}

Action BombDelayUpdate(int bomb)
{
	if (IsValidEntity(bomb))
	{
		if (BombInfo[bomb].type == DroneProj_BombDelayed)
		{
			if (!BombInfo[bomb].primed && BombCollision(bomb))
			{
				CreateTimer(BombInfo[bomb].fuseTime, DetonateBombTimer, bomb, TIMER_FLAG_NO_MAPCHANGE);
				BombInfo[bomb].primed = true;
				SDKUnhook(bomb, SDKHook_VPhysicsUpdate, BombDelayUpdate);
			}
		}
	}
}

Action BombImpactUpdate(int bomb)
{
	if (IsValidEntity(bomb))
	{
		if (BombInfo[bomb].type == DroneProj_BombImpact)
		{
			if (!BombInfo[bomb].primed && BombCollision(bomb))
			{
				BombInfo[bomb].touched = true;
				BombInfo[bomb].detonate();
			}
		}
	}
}

//SDKHook_Touch does not reliably detect when physics props collide with the world.. so we have to check manually
bool BombCollision(int bomb)
{
	bool result = false;
	if (BombInfo[bomb].isBomb && BombInfo[bomb].tickTime <= GetGameTime())
	{
		BombInfo[bomb].tickTime = GetGameTime() + 0.1;
		float min[3], max[3], pos[3];
		GetEntPropVector(bomb, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(bomb, Prop_Send, "m_vecMins", min);
		GetEntPropVector(bomb, Prop_Send, "m_vecMaxs", max);

		Handle hull = TR_TraceHullFilterEx(pos, pos, min, max, MASK_SOLID, BombTraceFilter, bomb);
		if (TR_DidHit(hull))
			result = true;

		CloseHandle(hull);
	}
	return result;
}

bool BombTraceFilter(int entity, int mask, int bomb)
{
	if (BombInfo[bomb].isBomb)
	{
		if (entity == bomb || entity == BombInfo[bomb].drone)
			return false;

		return true;
	}
	return false;
}

public any Native_GetDrone(Handle plugin, int args)
{
	int client = GetNativeCell(1);
	int drone = GetClientDrone(client);
	SetNativeArray(2, DroneInfo[drone], sizeof DroneProp);
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
	int owner = DroneInfo[exclude].GetOwner();
	if (IsValidClient(owner) && entity == owner)
		return false;
	if (entity == exclude)
		return false;

	return true;
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dBroad)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	RemoveSpecCamera(client);
}

public Action OnPlayerDeath(Event hEvent, const char[] name, bool dBroad)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if (IsValidClient(client) && IsInDrone[client])
	{
		int drone = GetClientDrone(client);
		if (IsValidDrone(drone))
		{
			KillDrone(DroneInfo[drone], drone, attacker, 0.0, 0);
			ResetClientView(client);
		}
	}
	//if (IsInDrone[attacker] && IsValidDrone(DroneEnt[attacker] && attacker != client))
	//{
	//	CreateSpecCamera(client, DroneEnt[attacker]);
	//}
}


void CreateSpecCamera(int client, int drone)
{
	if (!IsDrone[drone]) return;

	//spawn the camera anchor
	int cameraAnchor = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(cameraAnchor, "model", "models/empty.mdl");

	DispatchSpawn(cameraAnchor);
	ActivateEntity(cameraAnchor);

	float pos[3], angle[3];
	GetClientEyeAngles(client, angle);
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
	TeleportEntity(cameraAnchor, pos, angle, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(cameraAnchor, "SetParent", drone, cameraAnchor, 0);
	PlayerSpecCameraAnchor[client] = EntIndexToEntRef(cameraAnchor);

	//Now setup the actual camera
	int camera = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(camera, "model", "models/empty.mdl");

	DispatchSpawn(camera);
	ActivateEntity(camera);

	float forwardVec[3];
	GetAngleVectors(angle, forwardVec, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(forwardVec, -200.0);
	AddVectors(pos, forwardVec, pos);
	TeleportEntity(camera, pos, angle, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(camera, "SetParent", cameraAnchor, camera, 0);
	SetClientViewEntity(client, camera);
	PlayerSpecCamera[client] = EntIndexToEntRef(camera);
	SpecDrone[client] = true;
	PlayerSpecDrone[client] = drone;
}

//Spawns a drone for a client and sets them as the pilot
public void TryCreateDrone(int client, const char[] drone_name)
{
	char Directory[PLATFORM_MAX_PATH];
	char FileName[PLATFORM_MAX_PATH];
	FileType type;
	BuildPath(Path_SM, Directory, sizeof Directory, "configs/drones");
	Handle hDir = OpenDirectory(Directory);

	while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
	{
		if (type != FileType_File) continue;
		ReplaceString(FileName, sizeof FileName, ".txt", "", false);
		if (StrEqual(drone_name, FileName))
		{
			//PrintToChatAll("Found drone %s", drone_name);
			int drone = CreateEntityByName("prop_physics_override");
			SpawnDrone(client, drone_name, DroneInfo[drone], drone);
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
		if (IsValidClient(i) && IsInDrone[i])
			ResetClientView(i);
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
	BuildPath(Path_SM, DroneDir, sizeof DroneDir, "configs/drones");
	Handle hDir = OpenDirectory(DroneDir);
	while (ReadDirEntry(hDir, FileName, sizeof FileName, type))
	{
		char dirName[PLATFORM_MAX_PATH];
		Format(dirName, sizeof dirName, "%s/%s", DroneDir, FileName);
		if (FileExists(dirName))
		{
			ReplaceString(FileName, sizeof FileName, ".txt", "", false);
			DroneMenu.AddItem(FileName, FileName);
		}
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
	if (IsValidDrone(entity))
	{
		DroneInfo[entity].Clear();
	}
}

public void OnClientPutInServer(int client)
{
	IsInDrone[client] = false;
}

public void OnClientDisconnect(int client)
{
	int drone = GetClientDrone(client);
	if (IsValidDrone(drone))
		TryRemoveDrone(DroneInfo[drone]);
}

public Action OnDroneDamaged(int drone, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidEntity(drone))
	{
		bool crit = false;
		damagetype |= DMG_PREVENT_PHYSICS_FORCE;
		//PrintToChatAll("damaged");

		if ((damagetype & DMG_CRIT) && attacker != drone)
		{
			crit = true;
			damage *= 3.0; //triple damage for crits
			damagetype = (DMG_ENERGYBEAM|DMG_PREVENT_PHYSICS_FORCE); //no damage falloff
		}

		if (attacker != DroneInfo[drone].GetOwner())
		{
			//PrintToChatAll("Attacker is not owner");
			DroneTakeDamage(DroneInfo[drone], drone, attacker, inflictor, damage, crit);
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

stock void DroneTakeDamage(DroneProp Drone, int drone, int &attacker, int &inflictor, float &damage, bool crit, int weapon = 0)
{
	bool sendEvent = true;
	if (Drone.dead) return;

	if (attacker == Drone.GetOwner()) //significantly reduce damage if the drone damages itself
	{
		damage *= 0.25; //Should probably be a convar
		sendEvent = false;
	}

	if (sendEvent)
		SendDamageEvent(Drone, attacker, damage, crit);

	Drone.health -= damage;
	if (Drone.health <= 0.0)
	{
		KillDrone(Drone, drone, attacker, damage, weapon);
	}
}

stock void KillDrone(DroneProp Drone, int drone, int attacker, float damage, int weapon)
{
	int client = Drone.GetOwner();
	if (IsValidClient(client))
		PlayerExitVehicle(client);
	Drone.health = 0.0;
	Drone.dead = true;
	DroneExplodeDelay[drone] = GetGameTime() + 3.0;
	//SendKillEvent(drone, attacker, weapon);
	CreateParticle(drone, "burningplayer_flyingbits", true);
	Call_StartForward(DroneDestroy);

	Call_PushCell(drone);
	Call_PushCell(client);
	Call_PushCell(attacker);
	Call_PushFloat(damage);
	Call_PushString(Drone.plugin);

	Call_Finish();
}

public void ResetClientView(int client)
{
	SetClientViewEntity(client, client);
	IsInDrone[client] = false;
	SetEntityMoveType(client, MOVETYPE_WALK);
}

/*
void SendKillEvent(int drone, int attacker, int weapon)
{
	if (IsValidDrone(drone))
	{
		Event DroneDeath = CreateEvent("rd_robot_killed", true);

		DroneDeath.SetInt("userid", GetClientUserId(DroneOwner[drone]));
		DroneDeath.SetInt("victim_entindex", drone);
		DroneDeath.SetInt("inflictor_entindex", attacker);
		DroneDeath.SetInt("attacker", GetClientUserId(attacker));

		DroneDeath.Fire(false);
	}
}
*/

public void SendDamageEvent(DroneProp Drone, int attacker, float damage, bool crit)
{
	if (IsValidClient(attacker) && IsValidDrone(Drone.GetDrone()))
	{
		int damageamount = RoundFloat(damage);
		int health = RoundFloat(Drone.health);
		Event PropHurt = CreateEvent("npc_hurt", true);

		//setup components for event
		PropHurt.SetInt("entindex", Drone.GetDrone());
		PropHurt.SetInt("attacker_player", GetClientUserId(attacker));
		PropHurt.SetInt("damageamount", damageamount);
		PropHurt.SetInt("health", health - damageamount);
		PropHurt.SetBool("crit", crit);

		PropHurt.Fire(false);
	}
}

void RemoveSpecCamera(int client)
{
	int camera = EntRefToEntIndex(PlayerSpecCamera[client]);
	if (IsValidEntity(camera) && camera > MaxClients)
	{
		RemoveEntity(camera);
	}
	int anchor = EntRefToEntIndex(PlayerSpecCameraAnchor[client]);
	if (IsValidEntity(anchor) && anchor > MaxClients)
	{
		RemoveEntity(anchor);
	}
	SetClientViewEntity(client, client);
	SpecDrone[client] = false;
}

///
/// Drone tick functions
///

public void OnGameFrame()
{
	int drone = MaxClients + 1;
	while ((drone = FindEntityByClassname(drone, "prop_physics")) != -1)
	{
		if (IsValidDrone(drone))
			DroneTick(DroneInfo[drone]);
	}
}

void DroneTick(DroneProp Drone)
{
	int drone = Drone.GetDrone();
	if (!IsValidDrone(drone)) return;
	float pos[3];
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
	float hpRatio = Drone.health / Drone.maxhealth;
	if (hpRatio <= 0.3) //30% or less hp
	{
		if (SparkDelay[drone] <= GetGameTime())
		{
			float direction[3], sparkAngle[3];
			for (int i = 0; i < 3; i++)
			{
				pos[i] += GetRandomFloat(-20.0, 20.0);
				sparkAngle[i] = GetRandomFloat(-89.0, 89.0);

			}
			GetAngleVectors(sparkAngle, direction, NULL_VECTOR, NULL_VECTOR);
			TE_SetupMetalSparks(pos, direction);
			TE_SendToAll();
			SparkDelay[drone] = GetGameTime() + ClampFloat(hpRatio, 1.0, 0.3);
		}
	}

	if (Drone.dead && DroneExplodeDelay[drone] <= GetGameTime())
	{
		DroneExplodeDelay[drone] = FAR_FUTURE;
		TryRemoveDrone(DroneInfo[drone]);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client))
	{
		//Check if we are spectating a player with an active drone
		if (!IsPlayerAlive(client) || GetClientTeam(client) == 1 || GetClientTeam(client) == 0) //player is dead or in spectate
		{
			int observerTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			if (IsValidClient(observerTarget) && IsValidDrone(GetClientDrone(observerTarget)) && observerTarget != client && !SpecDrone[client])
			{
				CreateSpecCamera(client, GetClientDrone(observerTarget));
			}
			else if (!SpecDrone[client])
			{
				RemoveSpecCamera(client);
			}
		}
		int cameraAnchor = EntRefToEntIndex(PlayerSpecCameraAnchor[client]);
		if (IsValidEntity(cameraAnchor) && cameraAnchor > MaxClients)
		{
			float angle[3];
			GetClientEyeAngles(client, angle);
			TeleportEntity(cameraAnchor, NULL_VECTOR, angle, NULL_VECTOR);
		}
		int drone = GetClientDrone(client);
		if (IsValidDrone(drone))
		{
			int droneHp;
			int activeWeapon = DroneInfo[drone].activeweapon;
			droneHp = RoundFloat(DroneInfo[drone].health);
			float vPos[3], vAngles[3], cAngles[3], vVel[7][3], vAbsVel[3];
			char weaponname[MAX_WEAPON_LENGTH], ammo[32];
			float flMaxSpeed = DroneInfo[drone].speedoverride > 0.0 ? DroneInfo[drone].speedoverride : DroneInfo[drone].maxspeed;
			if (!DroneInfo[drone].dead)
			{
				float droneAngles[3];
				GetClientEyeAngles(client, cAngles);
				WeaponProps[drone][activeWeapon].GetName(weaponname, sizeof weaponname);
				FormatAmmoString(WeaponProps[drone][activeWeapon], ammo, sizeof ammo); //should probably only update on attack and reload

				SetHudTextParams(0.6, -1.0, 0.01, 255, 255, 255, 150);
				char sDroneHp[64];
				Format(sDroneHp, sizeof sDroneHp, "Health: %i\nWeapon: %s\n%s", droneHp, weaponname, ammo);
				ShowHudText(client, -1, "%s", sDroneHp);

				DroneYaw[drone][1] = DroneYaw[drone][0];
				GetEntPropVector(drone, Prop_Data, "m_vecOrigin", vPos);
				GetEntPropVector(drone, Prop_Send, "m_angRotation", droneAngles);
				float seatPos[3];
				seatPos = vPos;
				GetForwardPos(vPos, droneAngles, -30.0, 0.0, 30.0, seatPos);
				TeleportEntity(client, seatPos, NULL_VECTOR, NULL_VECTOR);
				vAngles = droneAngles;
				DroneYaw[drone][0] = droneAngles[1];
				UpdateWeaponAngles(WeaponProps[drone][activeWeapon], cAngles, drone);

				switch (DroneInfo[drone].movetype)
				{
					case DroneMove_Hover:
					{
						if (DroneInfo[drone].viewlocked)
							GetAngleFromTurnRate(cAngles, vPos, droneAngles, DroneInfo[drone].turnrate, drone, vAngles);

						GetAngleVectors(vAngles, vVel[1], NULL_VECTOR, NULL_VECTOR); //forward movement
						if (buttons & IN_FORWARD)
							DroneSpeed[client][0] += DroneInfo[drone].acceleration;
						else
							DroneSpeed[client][0] -= DroneInfo[drone].acceleration;
						ScaleVector(vVel[1], DroneSpeed[client][0]);

						GetAngleVectors(vAngles, vVel[3], NULL_VECTOR, NULL_VECTOR); //back movement
						if (buttons & IN_BACK)
							DroneSpeed[client][2] += DroneInfo[drone].acceleration;
						else
							DroneSpeed[client][2] -= DroneInfo[drone].acceleration;
						ScaleVector(vVel[3], -DroneSpeed[client][2]);

						GetAngleVectors(vAngles, NULL_VECTOR, vVel[2], NULL_VECTOR); //right movement
						if (buttons & IN_MOVERIGHT)
						{
							DroneSpeed[client][1] += DroneInfo[drone].acceleration;
							flRoll[client] += RollRate;
						}
						else
							DroneSpeed[client][1] -= DroneInfo[drone].acceleration;
						ScaleVector(vVel[2], DroneSpeed[client][1]);

						GetAngleVectors(vAngles, NULL_VECTOR, vVel[4], NULL_VECTOR); //left movement
						if (buttons & IN_MOVELEFT)
						{
							DroneSpeed[client][3] += DroneInfo[drone].acceleration;
							flRoll[client] -= RollRate;
						}
						else
							DroneSpeed[client][3] -= DroneInfo[drone].acceleration;
						ScaleVector(vVel[4], -DroneSpeed[client][3]);

						GetAngleVectors(vAngles, NULL_VECTOR, NULL_VECTOR, vVel[5]); //up movement
						if (buttons & IN_JUMP)
							DroneSpeed[client][4] += DroneInfo[drone].acceleration;
						else
							DroneSpeed[client][4] -= DroneInfo[drone].acceleration;
						ScaleVector(vVel[5], DroneSpeed[client][4]);

						GetAngleVectors(vAngles, NULL_VECTOR, NULL_VECTOR, vVel[6]); //down movement
						if (buttons & IN_DUCK)
							DroneSpeed[client][5] += DroneInfo[drone].acceleration;
						else
							DroneSpeed[client][5] -= DroneInfo[drone].acceleration;
						ScaleVector(vVel[6], -DroneSpeed[client][5]);

						AddMultipleVectors(vVel[1], vVel[2], vVel[3], vVel[4], vVel[5], vVel[6], vAbsVel);

						for (int v = 0; v < 6; v++) //clamp our speed
						{
							DroneSpeed[client][v] = ClampFloat(DroneSpeed[client][v], flMaxSpeed);
						}

						if (!ClientSideMovement(client, buttons) && (flRoll[client] > 0.6 || flRoll[client] < 0.6))
							flRoll[client] = SetRollTowardsZero(flRoll[client]);

						flRoll[client] = ClampFloat(flRoll[client], 30.0, -30.0);
						vAngles[2] = flRoll[client];
					}
					case DroneMove_Fly: //flying drones can only move forward
					{
						if (DroneInfo[drone].viewlocked) //only adjust angles if our view is locked to our client view angles
							GetAngleFromTurnRate(cAngles, vPos, droneAngles, DroneInfo[drone].turnrate, drone, vAngles);

						//specific variables for flying drones
						float forwardVec[3];

						GetAngleVectors(vAngles, forwardVec, NULL_VECTOR, NULL_VECTOR);

						if (buttons & IN_FORWARD)
						{
							DroneSpeed[client][0] += DroneInfo[drone].acceleration;
						}
						else
						{
							DroneSpeed[client][0] -= DroneInfo[drone].acceleration;
						}

						DroneSpeed[client][0] = ClampFloat(DroneSpeed[client][0], flMaxSpeed, FlyMinSpeed);
						ScaleVector(forwardVec, DroneSpeed[client][0]);
						vAbsVel = forwardVec;

						float turnRate = AngleDifference(vAngles, cAngles);
						float diff = DroneYaw[drone][1] - DroneYaw[drone][0];
						bool positive = (diff > 0) ? true : false;
						//PrintCenterText(client, "Turn Rate: %.1f\n%s\nCur: %.1f\nPrev: %.1f\n%.1f", turnRate, positive ? "right" : "left", DroneYaw[hDrone][0], DroneYaw[hDrone][1], diff);
						if (FloatAbs(turnRate) >= 0.2 && FloatAbs(diff) <= 80.0)
						{
							if (positive) //Right turn
							{
								flRoll[client] = (turnRate / 1.0);
							}
							else
							{
								flRoll[client] = ((turnRate / 1.0) * -1.0);
							}
						}
						vAngles[2] = flRoll[client];
					}
					case DroneMove_Ground: //Not functioning
					{
						GetAngleVectors(vAngles, vVel[1], NULL_VECTOR, NULL_VECTOR); //forward movement
						if (buttons & IN_FORWARD)
							DroneSpeed[client][0] += DroneInfo[drone].acceleration;
						if (buttons & IN_BACK)
							DroneSpeed[client][0] -= DroneInfo[drone].acceleration;

						DroneSpeed[client][0] = ClampFloat(DroneSpeed[client][0], flMaxSpeed);
						ScaleVector(vVel[1], DroneSpeed[client][0]);

						if (FloatAbs(DroneSpeed[client][0]) >= 50.0) //only steer if we have enough speed
						{
							if (buttons & IN_MOVERIGHT)
								vAngles[1] += TurnRate[drone];
							if (buttons & IN_MOVELEFT)
								vAngles[2] -= TurnRate[drone];
						}
					}
				}

				//manual reload
				if (buttons & IN_RELOAD)
					WeaponProps[drone][activeWeapon].SimulateReload();

				//Swap weapons on alt-fire
				if (buttons & IN_ATTACK2 && DroneInfo[drone].changecooldown <= GetGameTime())
				{
					int weaponId = DroneInfo[drone].activeweapon;
					int oldweapon = weaponId;
					if (weaponId >= DroneInfo[drone].weapons)
						weaponId = 1;
					else
						weaponId++;

					Action result;
					Call_StartForward(DroneChangeWeapon);

					Call_PushCell(drone);
					Call_PushCell(client);
					Call_PushArray(WeaponProps[drone][weaponId], sizeof DroneWeapon);
					Call_PushCell(weaponId);
					Call_PushString(DroneInfo[drone].plugin);

					Call_Finish(result);

					ResetWeaponRotation(WeaponProps[drone][oldweapon], droneAngles[1]);

					DroneInfo[drone].activeweapon = weaponId;
					DroneInfo[drone].changecooldown = GetGameTime() + 0.3;
				}

				//Use active weapon on drone
				if (buttons & IN_ATTACK && WeaponProps[drone][activeWeapon].CanFire(false))
				{
					FireWeapon(client, drone, activeWeapon, WeaponProps[drone][activeWeapon]);
				}

				buttons &= ~IN_ATTACK;
				WeaponProps[drone][activeWeapon].Simulate();

				//update drone speed and angles
				TeleportEntity(drone, NULL_VECTOR, vAngles, vAbsVel);
			}
		}
	}
}

//Entering and exiting drones
public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	char szBuffer[64];
	kv.GetSectionName(szBuffer, sizeof szBuffer);
	if (StrEqual(szBuffer, "+inspect_server", false))
	{
		int drone = GetClientDrone(client);
		if (IsValidDrone(drone))
		{
			PlayerExitVehicle(client);
		}
		else
		{
			int entity = GetClientAimTarget(client, false);
			if (IsValidDrone(entity) && !DroneInfo[entity].occupied && InRange(client, entity))
				PlayerEnterDrone(client, DroneInfo[entity]);
		}
	}
	return Plugin_Continue;
}

void FormatAmmoString(DroneWeapon weapon, char[] buffer, int size)
{
	switch (weapon.ammo)
	{
		case 0: FormatEx(buffer, size, "Reloading...");
		case -1: FormatEx(buffer, size, "");
		default: FormatEx(buffer, size, "Ammo: %i", weapon.ammo);
	}
}

void UpdateWeaponAngles(DroneWeapon weapon, float angles[3], int drone)
{
	if (!weapon.fixed) //only bother with this if the weapon is not fixed
	{
		int owner = GetEntPropEnt(drone, Prop_Data, "m_hOwnerEntity");
		if (!IsValidClient(owner)) return;

		int model = weapon.GetWeapon();
		if (!IsValidEntity(model)) return;

		float pos[3], rot[3], aimangle[3], aimpos[3], cameraPos[3], aimvec[3];

		GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(drone, Prop_Send, "m_angRotation", rot);
		GetForwardPos(pos, rot, 0.0, 0.0, DroneInfo[drone].cameraheight, cameraPos); //Get our camera height relative to our drone's forward vector

		CD_GetDroneAimPosition(drone, cameraPos, angles, aimpos);	//find where the client is aiming at in relation to the drone

		MakeVectorFromPoints(pos, aimpos, aimvec); //draw vector from offset position to our aim position
		GetVectorAngles(aimvec, aimangle);
		//Need to clamp this angle based on weapon's max rotation parameters
		//Ignoring for now

		TeleportEntity(model, NULL_VECTOR, aimangle, NULL_VECTOR);
	}
}

void ResetWeaponRotation(DroneWeapon weapon, float yaw)
{
	if (!weapon.fixed)
	{
		int model = weapon.GetWeapon();
		if (IsValidEntity(model))
		{
			float angle[3] = {0.0, 0.0, 0.0};
			angle[1] = yaw;
			TeleportEntity(model, NULL_VECTOR, angle, NULL_VECTOR);
		}
	}
}

void GetAngleFromTurnRate(const float angles[3], float pos[3], float droneAngles[3], float rate, int drone, float bufferAngles[3])
{
	float forwardPos[3], newDir[3], droneVel[3], bufferAngle[3];
	GetForwardPos(pos, angles, rate, _, _, forwardPos);

	MakeVectorFromPoints(pos, forwardPos, newDir);
	GetEntPropVector(drone, Prop_Data, "m_vecAbsVelocity", droneVel);
	float forwardSpeed = GetVectorLength(droneVel);
	GetAngleVectors(droneAngles, droneVel, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(droneVel, forwardSpeed);
	AddVectors(droneVel, newDir, droneVel);
	NormalizeVector(droneVel, droneVel);
	GetVectorAngles(droneVel, bufferAngle);
	bufferAngles = bufferAngle;
}

void FireWeapon(int gunner, int drone, int slot, DroneWeapon weapon)
{
	Action result = Plugin_Continue;

	//Play fire sound if one exists
	if (strlen(weapon.firesound) > 3)
	{
		PrecacheSound(weapon.firesound);
		int wep = weapon.GetWeapon();
		if (IsValidEntity(wep) && wep > MaxClients)
			EmitSoundToAll(weapon.firesound, wep); //emit from weapon if physical entity exists
		else
			EmitSoundToAll(weapon.firesound, drone); //otherwise just emit from the drone
	}
	Call_StartForward(DroneAttack);

	Call_PushCell(drone);
	Call_PushCell(gunner);
	Call_PushArray(WeaponProps[drone][slot], sizeof DroneWeapon);
	Call_PushCell(slot);
	Call_PushString(DroneInfo[drone].plugin);

	Call_Finish(result);
	weapon.SimulateFire(result);
}

float AngleDifference(float droneAngle[3], float aimAngle[3])
{
	float forwardVec[3], aimVec[3];
	float droneAngle2[3]; droneAngle2 = droneAngle;
	float aimAngle2[3]; aimAngle2 = aimAngle;

	float turnRate;

	//zero pitch and roll
	droneAngle2[0] = 0.0;
	droneAngle2[2] = 0.0;
	aimAngle2[0] = 0.0;
	aimAngle2[2] = 0.0;
	GetAngleVectors(droneAngle2, forwardVec, NULL_VECTOR, NULL_VECTOR);
	GetAngleVectors(aimAngle2, aimVec, NULL_VECTOR, NULL_VECTOR);

	turnRate = RadToDeg(ArcCosine(GetVectorDotProduct(forwardVec, aimVec) / GetVectorLength(forwardVec, true)));
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

stock float SetRollTowardsZero(float roll)
{
	if (roll > 0.0)
		roll -= RollRate;

	if (roll < 0.0)
		roll += RollRate;

	return roll;
}

public void ExplodeDrone(int drone)
{
	float dronePos[3];
	GetEntPropVector(drone, Prop_Send, "m_vecOrigin", dronePos);
	TE_SetupExplosion(dronePos, ExplosionSprite, 4.0, 1, 0, 450, 400);
	TE_SendToAll();

	Call_StartForward(DroneExplode);

	Call_PushCell(drone);
	Call_PushString(DroneInfo[drone].plugin);

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

stock void SpawnDrone(int client, const char[] drone_name, DroneProp Drone, int drone)
{
	//PrintToChatAll("Drone spawned");
	KeyValues kv = new KeyValues("Drone");
	char sPath[64];
	BuildPath(Path_SM, sPath, sizeof sPath, "configs/drones/%s.txt", drone_name);

	if (!FileExists(sPath))
	{
		Handle fFile = OpenFile(sPath, "w");
		CloseHandle(fFile);
	}
	kv.ImportFromFile(sPath);

	float angles[3], pos[3], vel[3];
	GetClientEyeAngles(client, angles);
	GetClientEyePosition(client, pos);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel); //reset velocity
	Drone.SetConfig(drone_name);
	SetupDrone(Drone, kv, drone, pos, angles, vel);
	switch (Drone.movetype)
	{
		case DroneMove_Ground:
		{
			Drone.viewlocked = false;
			SetEntityGravity(drone, 1.0);
		}
		default:
		{
			Drone.viewlocked = true;
			SetEntityGravity(drone, 0.01);
		}
	}

	//Find total number of weapons for this drone
	//DroneWeapons[hDrone] = 0;
	Drone.weapons = 0;
	if (kv.JumpToKey("weapons"))
	{
		char sNumber[8];
		for (int i = 1; i <= MAXWEAPONS; i++)
		{
			FormatEx(sNumber, sizeof sNumber, "weapon%i", i);
			if (kv.JumpToKey(sNumber))
			{
				SetupWeapon(kv, WeaponProps[drone][i], drone);
				kv.GoBack();
			}
			else
			{
				LogMessage("Found %i weapons for %s", Drone.weapons, drone_name);
				break;
			}
			Drone.weapons++;
		}
		kv.Rewind();
	}
	delete kv;

	Call_StartForward(DroneCreated);

	Call_PushArray(Drone, sizeof DroneProp);
	Call_PushString(Drone.plugin);
	Call_PushString(drone_name);

	Call_Finish();

	PlayerEnterDrone(client, Drone);
}

void SetupDrone(DroneProp Drone, KeyValues kv, int drone, float pos[3], float angles[3], float vel[3])
{
	Drone.Spawn(kv, drone, pos, angles, vel);
	IsDrone[drone] = true;
	SDKHook(drone, SDKHook_OnTakeDamage, OnDroneDamaged);
}

void PlayerEnterDrone(int client, DroneProp Drone)
{
	IsInDrone[client] = true;
	DroneRef[client] = Drone.drone; //Reference to a reference, no need to use GetDrone()
	Drone.PlayerPilot(client);

	float angles[3], pos[3];
	int drone = Drone.GetDrone();
	if (IsValidDrone(drone))
	{
		GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(drone, Prop_Send, "m_angRotation", angles);
	}
	SetupViewPosition(client, drone, Drone, pos, angles, Drone.cameraheight);

	SetVariantInt(1);
	AcceptEntityInput(client, "SetForcedTauntCam");
	SetPlayerOnDrone(client);

	Call_StartForward(DroneEntered);

	Call_PushArray(Drone, sizeof DroneProp);
	Call_PushCell(client);
	Call_PushCell(0);
	Call_PushString(Drone.plugin);
	Call_PushString(Drone.config);

	Call_Finish();
}

void SetupWeapon(KeyValues kv, DroneWeapon weapon, int drone)
{
	char weaponname[MAX_WEAPON_LENGTH], modelname[PLATFORM_MAX_PATH], firesound[PLATFORM_MAX_PATH];
	float offset[3], projoffset[3];
	kv.GetString("name", weaponname, sizeof weaponname, "INVALID_WEAPON");
	kv.GetString("model", modelname, sizeof modelname);
	kv.GetString("sound", firesound, sizeof firesound);

	weapon.drone = EntIndexToEntRef(drone);
	kv.GetVector("offset", offset);
	weapon.SetOffset(offset, false);
	kv.GetVector("proj_offset", projoffset);
	weapon.SetOffset(projoffset, true);
	weapon.SetName(weaponname);
	weapon.SetFire(firesound);
	weapon.maxammo = kv.GetNum("ammo_loaded", 1);
	weapon.ammo = weapon.maxammo;
	weapon.inaccuracy = kv.GetFloat("inaccuracy", 0.0);
	weapon.reloadtime = kv.GetFloat("reload_time", 1.0);
	weapon.firerate = kv.GetFloat("attack_time", 0.5);
	weapon.fixed = view_as<bool>(kv.GetNum("fixed", 1));
	weapon.damage = kv.GetFloat("damage", 1.0);
	weapon.projspeed = kv.GetFloat("speed", 1100.0);
	if (!weapon.fixed)
	{
		weapon.pitch = kv.GetFloat("max_angle_y", 0.0);
		weapon.yaw = kv.GetFloat("max_angle_x", 0.0);
	}
	if (strlen(modelname) > 3) //only spawn the weapon if a model is given
	{
		weapon.SetModel(modelname);
		weapon.Spawn();
	}
}

void SetupViewPosition(int client, int drone, DroneProp Drone, const float pos[3], const float angle[3], float height)
{
	float rPos[3];

	int camera = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(camera, "model", "models/empty.mdl"); //models/weapons/w_models/w_baseball.mdl

	DispatchSpawn(camera);
	ActivateEntity(camera);

	rPos = pos;
	GetForwardPos(rPos, angle, 0.0, _, height, rPos);
	Drone.cameraheight = height;

	TeleportEntity(camera, rPos, angle, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(camera, "SetParent", drone, camera, 0);

	SetClientViewEntity(client, camera);
	Drone.camera = EntIndexToEntRef(camera);
}

//Makes the player invisible and sets the model to something without hitboxes
//Only used to set the pilot of the drone
void SetPlayerOnDrone(int client)
{
	SetEntityRenderFx(client, RENDERFX_FADE_FAST);
	RemoveWearables(client);
	TF2_RemoveAllWeapons(client);
	SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);
	SetVariantString("models/empty.mdl");
	AcceptEntityInput(client, "SetCustomModel");
}

//passenger seats
stock void SetPlayerSeatPosition(int client, int drone, KeyValues kv, const char[] seatname)
{
	float offset[3], seat[3], pos[3], angle[3];
	char attach[64];
	if (kv.JumpToKey("seats"))
	{
		if (kv.JumpToKey(seatname))
		{
			//If this seat uses an attachment on the model, lets set the player to its position
			if (kv.GetString("attachment", attach, sizeof attach))
			{
				//preserved
			}
			else //...otherwise use the offset position
			{
				kv.GetVector("offset", offset);
				GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
				GetEntPropVector(drone, Prop_Send, "m_angRotation", angle);
				GetOffsetPos(pos, angle, offset, seat);

				TeleportEntity(client, seat, NULL_VECTOR, NULL_VECTOR);
				SetVariantString("!activator");
				AcceptEntityInput(client, "SetParent", drone, client, 0);
			}
			if (!kv.GetNum("visible"))
			{
				SetEntityRenderFx(client, RENDERFX_FADE_FAST);
				RemoveWearables(client);
				TF2_RemoveAllWeapons(client);
				SetVariantString("models/empty.mdl");
				AcceptEntityInput(client, "SetCustomModel");
			}
			//TODO - Set player animation to kart animation
		}
	}
}

int GetClientDrone(int client)
{
	int drone = EntRefToEntIndex(DroneRef[client]);
	if (IsValidDrone(drone))
		return drone;

	return -1;
}

void RemoveWearables(int client)
{
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "tf_wearable")) != -1)
	{
		if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == client)
		{
			switch(GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex"))
			{
				default:
				{
					TF2_RemoveWearable(client, entity);
				}
			}
		}
	}
	entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "tf_powerup_bottle")) != -1) //mvm canteens
	{
		if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == client)
		{
			TF2_RemoveWearable(client, entity);
		}
	}
}

void SetVehicleUnoccupied(DroneProp drone, int pilot)
{
	drone.owner = INVALID_ENT_REFERENCE;
	drone.occupied = false;

	int camera = drone.GetCamera();
	if (IsValidEntity(camera) && camera > MaxClients)
		RemoveEntity(camera);

	Call_StartForward(DroneExited);

	Call_PushArray(drone, sizeof DroneProp);
	Call_PushCell(pilot);
	Call_PushCell(0);

	Call_Finish();
}

void PlayerExitVehicle(int client)
{
	int drone = GetClientDrone(client);
	SetVehicleUnoccupied(DroneInfo[drone], client);
	DroneRef[client] = INVALID_ENT_REFERENCE;

	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	ResetClientView(client);
	SetEntityRenderFx(client, RENDERFX_NONE);
	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
	float pos[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);
	TF2_RespawnPlayer(client);
	TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
}

stock bool TryRemoveDrone(DroneProp Drone)
{
	int drone = Drone.GetDrone();
	if (IsValidDrone(drone))
	{
		ExplodeDrone(drone);
		IsDrone[drone] = false;
		AcceptEntityInput(drone, "KillHierarchy");
		return true;
	}
	return false;
}

int GetDroneCamera(int drone)
{
	if (IsValidDrone(drone))
	{
		int camera = DroneInfo[drone].GetCamera();
		return camera;
	}
	return -1;
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

bool InRange(int client, int drone)
{
	float cPos[3], dPos[3];
	GetClientEyePosition(client, cPos);
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", dPos);

	return (GetVectorDistance(cPos, dPos) <= 300.0);
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
