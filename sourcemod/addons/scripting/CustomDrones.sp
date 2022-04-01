
///
/// Custom Drones Staging
/// Experimental branch for new features - not recommended for actual use.
/// Most features in this will not be working properly and are in development.
/// If you would like to use the plugin, check out the main branch instead.
///

#pragma semicolon 1
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

DroneBomb BombInfo[2049];

int PlayerSpecCamera[MAXPLAYERS+1];
int PlayerSpecCameraAnchor[MAXPLAYERS+1];
int PlayerSpecDrone[MAXPLAYERS+1]; //drone being spectated
bool SpecDrone[MAXPLAYERS+1];
bool FirstPersonSpec[MAXPLAYERS+1];

char sPluginName[2048][PLATFORM_MAX_PATH];
char sName[2048][PLATFORM_MAX_PATH];
char sModelName[2048][PLATFORM_MAX_PATH];
char sModelDestroyed[2048][PLATFORM_MAX_PATH];
char sMoveType[2048][PLATFORM_MAX_PATH];

int ExplosionSprite;

int DroneEnt[MAXPLAYERS+1];
int AmmoLoaded[2048][MAXWEAPONS+1];
int MaxAmmo[2048][MAXWEAPONS+1];
int DroneOwner[2048];
int DroneWeapons[2048];
DroneWeapon WeaponProps[2048][MAXWEAPONS];
int WeaponNumber[2048];
int DroneActiveWeapon[2048];
int DroneCamera[2049];
float CameraHeight[2048];
float DroneHealth[2048];
float DroneMaxHealth[2048];
float DroneMaxSpeed[2048];
float DroneAcceleration[2048];
float ReloadTime[2048][MAXWEAPONS+1];
float ReloadDelay[2048][MAXWEAPONS+1];
float FireRate[2048][MAXWEAPONS+1];
float DroneYaw[2048][2];
float TurnRate[2048];
float SpeedOverride[2048];

float flRollRate = 0.8;

float AttackDelay[2048][MAXWEAPONS+1];

float flDroneExplodeDelay[2048];

float AmmoChangeCooldown[2048];
float DroneSpeed[MAXPLAYERS+1][6];
float flRoll[MAXPLAYERS+1];
bool DroneIsDead[2049];
bool ViewLocked[2049];

bool IsInDrone[MAXPLAYERS+1];
bool IsDrone[2048];

public Plugin MyInfo = {
	name 			= 	"Custom Drones",
	author 			=	"Ivory",
	description		= 	"Customizable drones for players",
	version 		= 	"1.3.0"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_drone", CmdDrone, ADMFLAG_ROOT);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("teamplay_round_start", OnRoundStart);
	AddCommandListener(ChangeSpec, "spec_next");
	AddCommandListener(ChangeSpec, "spec_prev");
	AddCommandListener(ChangeSpecMode, "spec_mode");
	ExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");

	//Forwards
	g_DroneCreated = CreateGlobalForward("CD_OnDroneCreated", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String); //drone, owner, plugin, config
	g_DroneExplode = CreateGlobalForward("CD_OnDroneRemoved", ET_Ignore, Param_Cell, Param_Cell, Param_String); //drone, owner, plugin
	g_DroneChangeWeapon = CreateGlobalForward("CD_OnWeaponChanged", ET_Hook, Param_Cell, Param_Cell, Param_Any, Param_Cell, Param_String); //drone, owner, weapon, slot, plugin
	g_DroneDestroy = CreateGlobalForward("CD_OnDroneDestroyed", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_String); //drone, owner, attacker, damage, plugin
	g_DroneAttack = CreateGlobalForward("CD_OnDroneAttack", ET_Hook, Param_Cell, Param_Cell, Param_Any, Param_Cell, Param_String); //drone, owner, weapon, slot, plugin
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
	CreateNative("CD_GetDroneHealth", Native_GetDroneHealth);
	CreateNative("CD_GetDroneMaxHealth", Native_GetDroneMaxHealth);
	CreateNative("CD_SpawnDroneByName", Native_SpawnDroneName);
	CreateNative("CD_GetDroneActiveWeapon", Native_GetDroneWeapon);
	CreateNative("CD_SetDroneActiveWeapon", Native_SetDroneWeapon);
	CreateNative("CD_SetWeaponReloading", Native_SetWeaponReload);
	CreateNative("CD_GetParamFloat", Native_GetFloatParam);
	CreateNative("CD_GetParamInteger", Native_GetIntParam);
	CreateNative("CD_SpawnRocket", Native_SpawnRocket);
	CreateNative("CD_GetCameraHeight", Native_GetCameraHeight);
	CreateNative("CD_IsValidDrone", Native_ValidDrone);
	CreateNative("CD_DroneTakeDamage", Native_DroneTakeDamage);
	CreateNative("CD_FireActiveWeapon", Native_FireWeapon);
	CreateNative("CD_FireBullet", Native_HitscanAttack);
	CreateNative("CD_OverrideMaxSpeed", Native_OverrideMaxSpeed);
	CreateNative("CD_ToggleViewLocked", Native_ViewLock);
	CreateNative("CD_GetWeaponAttackSound", Native_AttackSound);
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
		ViewLocked[drone] = !ViewLocked[drone];
	else
		ThrowNativeError(017, "Entity index %i is not a valid drone", drone);

	return ViewLocked[drone];
}

public int Native_OverrideMaxSpeed(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	float speed = GetNativeCell(2);

	SpeedOverride[drone] = speed;
}

public int Native_FireWeapon(Handle plugin, int args)
{
	int owner = GetNativeCell(1);
	int drone = GetNativeCell(2);
	int slot = DroneActiveWeapon[drone];

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
	int iDroneHP2 = RoundFloat(DroneHealth[drone]);
	return iDroneHP2;
}

public int Native_GetDroneMaxHealth(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	int iDroneMaxHP = RoundFloat(DroneMaxHealth[drone]);
	return iDroneMaxHP;
}

public int Native_GetDroneWeapon(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	return DroneActiveWeapon[drone];
}

public int Native_SetDroneWeapon(Handle plugin, int args)
{
	int drone = GetNativeCell(1);
	int weapon = GetNativeCell(2);
	DroneActiveWeapon[drone] = weapon;
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

	AttackDelay[drone][weapon] = GetEngineTime() + delay;
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
}

public any Native_HitscanAttack(Handle plugin, int args)
{
	int owner = GetNativeCell(1);
	int drone = GetNativeCell(2);
	float damage = GetNativeCell(3);
	float pos[3];
	GetNativeArray(4, pos, sizeof pos);
	float forwardAngle[3];
	GetNativeArray(5, forwardAngle, sizeof forwardAngle);
	float overrideX = GetNativeCell(6);
	float overrideY = GetNativeCell(7);
	float overrideZ = GetNativeCell(8);
	float inaccuracy = GetNativeCell(9);
	float maxAngle[2];
	GetNativeArray(10, maxAngle, sizeof maxAngle);
	CDDmgType dmgType = view_as<CDDmgType>(GetNativeCell(11));
	CDWeaponType type = view_as<CDWeaponType>(GetNativeCell(12));
	if (IsValidClient(owner) && IsValidDrone(drone))
	{
		float angle[3], aimPos[3], aimVec[3], aimAngle[3], cameraPos[3];
		GetClientEyeAngles(owner, aimAngle);
		cameraPos = pos;
		GetForwardPos(cameraPos, forwardAngle, 0.0, 0.0, CameraHeight[drone], cameraPos); //Get our camera height relative to our drone's forward vector
		if (inaccuracy)
		{
			aimAngle[0] += GetRandomFloat((inaccuracy * -1.0), inaccuracy);
			aimAngle[1] += GetRandomFloat((inaccuracy * -1.0), inaccuracy);
		}
		CD_GetDroneAimPosition(drone, cameraPos, aimAngle, aimPos);	//find where the client is aiming at in relation to the drone
		GetForwardPos(pos, forwardAngle, overrideX, overrideY, overrideZ, pos); //offset start position of trace

		MakeVectorFromPoints(pos, aimPos, aimVec); //draw vector from offset position to our aim position
		GetVectorAngles(aimVec, angle);

		//restrict angle at which projectiles can be fired, not yet working
		//if (angle[0] >= forwardAngle[0] + maxAngle[0]) angle[0] = forwardAngle[0] + maxAngle[0];
		//if (angle[0] >= forwardAngle[0] - maxAngle[0]) angle[0] = forwardAngle[0] - maxAngle[0];
		//if (angle[1] >= forwardAngle[1] + maxAngle[1]) angle[1] = forwardAngle[1] + maxAngle[1];
		//if (angle[1] >= forwardAngle[1] - maxAngle[1]) angle[1] = forwardAngle[1] - maxAngle[1];

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
						DroneTakeDamage(victim, owner, drone, damage, false);
					else
						SDKHooks_TakeDamage(victim, owner, owner, damage, DMG_ENERGYBEAM);
				}
				default:
				{
					if (victim > 0)
					{
						damage = Damage_Hitscan(victim, drone, damage);
						if (isDrone)
							DroneTakeDamage(victim, owner, drone, damage, false);
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

	PrintToServer("[DRONES] ********** HITSCAN ATTACK ****************");
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
		AcceptEntityInput(target, "Kill");
	}
}

Action RemoveTracer(Handle timer, any ref)
{
	int tracer = EntRefToEntIndex(ref);
	if (IsValidEntity(tracer) && tracer > MaxClients)
	{
		AcceptEntityInput(tracer, "Kill");
	}
}

bool FilterDroneShoot(int entity, int mask, int drone)
{
	int owner = DroneOwner[drone];
	if (IsValidClient(entity) && GetClientTeam(entity) == GetClientTeam(owner)) //ignore teammates
		return false;

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
	GetNativeArray(3, pos, sizeof pos);
	float angle[3];
	GetNativeArray(4, angle, sizeof angle);
	ProjType projectile = GetNativeCell(5);
	float damage = GetNativeCell(6);
	float speed = GetNativeCell(7);
	float overrideX = GetNativeCell(8);
	float overrideY = GetNativeCell(9);
	float overrideZ = GetNativeCell(10);
	float inaccuracy = GetNativeCell(11);

	//PrintToConsole(owner, "Damage: %.1f\nSpeed: %.1f\noffset x: %.1f\noffset y: %.1f\noffset z: %.1f", damage, speed, overrideX, overrideY, overrideZ);

	float spawnPos[3], velocity[3], aimAngle[3];
	char netname[64], classname[64];

	//Get Spawn Position
	//GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);				//adjust position based on the physical weapon being used on the drone
	//GetEntPropVector(drone, Prop_Send, "m_angRotation", angle);
	GetClientEyeAngles(owner, aimAngle);
	GetForwardPos(pos, angle, overrideX, overrideY, overrideZ, spawnPos);

	//Get where our drone is aiming and direct the rocket towards that angle
	float aimPos[3], aimVec[3], cameraPos[3];
	cameraPos = pos;
	cameraPos[2] += CameraHeight[drone];
	CD_GetDroneAimPosition(drone, cameraPos, aimAngle, aimPos);

	//TE_SetupBeamPoints(pos, aimPos, PrecacheModel("materials/sprites/laser.vmt"), PrecacheModel("materials/sprites/laser.vmt"), 0, 1, 1.0, 5.0, 5.0, 10, 0.0, {255, 0, 0, 255}, 10);
	//TE_SendToClient(owner);

	MakeVectorFromPoints(spawnPos, aimPos, aimVec);
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
		default:
		{
			Format(classname, sizeof classname, "tf_projectile_rocket");
			Format(netname, sizeof netname, "CTFProjectile_Rocket");
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

/*
	Drone Bomb Functions
*/
public any Native_SpawnBomb(Handle Plugin, int args)
{
	int drone = GetNativeCell(1);
	int owner = DroneOwner[drone];
	float pos[3];
	GetNativeArray(2, pos, sizeof pos);
	float angle[3];
	GetNativeArray(3, angle, sizeof angle);
	ProjType projectile = GetNativeCell(4);
	float damage = GetNativeCell(5);
	char modelname[256];
	GetNativeString(6, modelname, sizeof modelname);
	float fuse = GetNativeCell(7);
	float offset[3];
	GetNativeArray(8, offset, sizeof offset);

	float spawnPos[3];

	GetForwardPos(pos, angle, offset[0], offset[1], offset[2], spawnPos);
	DroneBomb bombEnt;
	bombEnt.create(owner, modelname, damage, fuse, 200.0, spawnPos);
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
		default:
		{
			BombInfo[bombEnt.bomb] = bombEnt;
			CreateTimer(bombEnt.fuseTime, DetonateBombTimer, bombEnt.bomb, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	SetNativeArray(9, bombEnt, sizeof bombEnt);
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
	if (BombInfo[bomb].isBomb && BombInfo[bomb].tickTime <= GetEngineTime())
	{
		BombInfo[bomb].tickTime = GetEngineTime() + 0.1;
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
		IsInDrone[client] = false;
		KillDrone(DroneEnt[client], attacker, 0.0, 0);
		ResetClientView(client);
	}
	if (IsInDrone[attacker] && IsValidDrone(DroneEnt[attacker] && attacker != client))
	{
		CreateSpecCamera(client, DroneEnt[attacker]);
	}
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
		if (IsValidClient(i) && IsInDrone[i])
		{
			ResetClientView(i);
			DroneEnt[i] = INVALID_ENT_REFERENCE;
		}
	}
}

public Action CmdDrone(int client, int args)
{
	if (!CanOpenMenu(client)) return Plugin_Continue;
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
		if (IsPlayerAlive(client) && IsValidClient(client) && CanOpenMenu(client))
		{
			OpenMenu(client);
		}
	}
	return Plugin_Handled;
}

bool CanOpenMenu(int client)
{
	return true; //temp
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
	//preserved
}

public void OnClientPutInServer(int client)
{
	IsInDrone[client] = false;
	DroneEnt[client] = -1;
}

public void OnClientDisconnect(int client)
{
	TryRemoveDrone(client);
}

/*
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
*/

/*
void GetAmmoCount(int drone, int weapon, char[] buffer, int size)
{
	switch (AmmoLoaded[drone][weapon])
	{
		case 0: Format(buffer, size, "Reloading...");
		case -1: Format(buffer, size, "");
		default: Format(buffer, size, "Ammo: %i", AmmoLoaded[drone][weapon]);
	}
}
*/

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

		if (attacker != DroneOwner[drone])
		{
			//PrintToChatAll("Attacker is not owner");
			DroneTakeDamage(drone, attacker, inflictor, damage, crit);
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

stock void DroneTakeDamage(int drone, int &attacker, int &inflictor, float &damage, bool crit, int weapon = 0)
{
	bool sendEvent = true;

	if (DroneIsDead[drone]) return;

	if (attacker == DroneOwner[drone]) //significantly reduce damage if the drone damages itself
	{
		damage *= 0.25; //Should probably be a convar
		sendEvent = false;
	}

	if (sendEvent)
		SendDamageEvent(drone, attacker, damage, crit);

	DroneHealth[drone] -= damage;
	if (DroneHealth[drone] <= 0.0)
	{
		KillDrone(drone, attacker, damage, weapon);
	}
}

stock void KillDrone(int drone, int attacker, float damage, int weapon)
{
	DroneHealth[drone] = 0.0;
	DroneIsDead[drone] = true;
	flDroneExplodeDelay[drone] = GetEngineTime() + 3.0;
	//SendKillEvent(drone, attacker, weapon);
	CreateParticle(drone, "burningplayer_flyingbits", true);
	Call_StartForward(g_DroneDestroy);

	Call_PushCell(drone);
	Call_PushCell(DroneOwner[drone]);
	Call_PushCell(attacker);
	Call_PushFloat(damage);
	Call_PushString(sPluginName[drone]);

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

public void SendDamageEvent(int victim, int attacker, float damage, bool crit)
{
	if (IsValidClient(attacker) && IsValidDrone(victim))
	{
		int damageamount = RoundFloat(damage);
		int health = RoundFloat(DroneHealth[victim]);
		Event PropHurt = CreateEvent("npc_hurt", true);

		//setup components for event
		PropHurt.SetInt("entindex", victim);
		PropHurt.SetInt("attacker_player", GetClientUserId(attacker));
		PropHurt.SetInt("damageamount", damageamount);
		PropHurt.SetInt("health", health - damageamount);
		PropHurt.SetBool("crit", crit);

		PropHurt.Fire(false);
	}
}

void RemoveSpecCamera(client)
{
	int camera = EntRefToEntIndex(PlayerSpecCamera[client]);
	if (IsValidEntity(camera) && camera > MaxClients)
	{
		AcceptEntityInput(camera, "Kill");
	}
	int anchor = EntRefToEntIndex(PlayerSpecCameraAnchor[client]);
	if (IsValidEntity(anchor) && anchor > MaxClients)
	{
		AcceptEntityInput(anchor, "Kill");
	}
	SetClientViewEntity(client, client);
	SpecDrone[client] = false;
}

///
/// Drone tick functions
///

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client))
	{
		//Check if we are spectating a player with an active drone
		if (!IsPlayerAlive(client) || GetClientTeam(client) == 1 || GetClientTeam(client) == 0) //player is dead or in spectate
		{
			int observerTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			if (IsValidClient(observerTarget) && IsValidDrone(DroneEnt[observerTarget]) && observerTarget != client && !SpecDrone[client])
			{
				CreateSpecCamera(client, DroneEnt[observerTarget]);
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
		if (IsValidDrone(DroneEnt[client]))
		{
			int iDroneHP;
			int hDrone = DroneEnt[client];
			int activeWeapon = WeaponNumber[hDrone];
			iDroneHP = RoundFloat(DroneHealth[hDrone]);
			float vPos[3], vAngles[3], cAngles[3], vVel[7][3], vAbsVel[3];
			char weaponname[MAX_WEAPON_LENGHT], ammo[32];
			float flMaxSpeed = SpeedOverride[hDrone] > 0.0 ? SpeedOverride[hDrone] : DroneMaxSpeed[hDrone];
			if (!DroneIsDead[hDrone])
			{
				float droneAngles[3];
				GetClientEyeAngles(client, cAngles);
				WeaponProps[hDrone][activeWeapon].GetName(weaponname, sizeof weaponname);
				//GetWeaponName(hDrone, activeWeapon, weaponname, sizeof weaponname);
				FormatAmmoString(WeaponProps[hDrone][activeWeapon], ammo, sizeof ammo); //should probably only update on attack and reload
				//GetAmmoCount(hDrone, activeWeapon, ammo, sizeof ammo);

				SetHudTextParams(0.6, -1.0, 0.01, 255, 255, 255, 150);
				char sDroneHp[64];
				Format(sDroneHp, sizeof sDroneHp, "Health: %i\nWeapon: %s\n%s", iDroneHP, sAmmoType, ammo);
				ShowHudText(client, -1, "%s", sDroneHp);

				DroneYaw[hDrone][1] = DroneYaw[hDrone][0];
				GetEntPropVector(hDrone, Prop_Data, "m_vecOrigin", vPos);
				GetEntPropVector(hDrone, Prop_Send, "m_angRotation", droneAngles);
				vAngles = droneAngles;
				DroneYaw[hDrone][0] = droneAngles[1];
				float hpRatio = float(iDroneHP) / DroneMaxHealth[hDrone];
				
				UpdateWeaponAngles(WeaponProps[hDrone][activeWeapon], cAngles, drone);

				if (hpRatio <= 0.3) //30% or less hp
				{
					static float sparkDelay[MAXPLAYERS+1];
					if (sparkDelay[client] <= GetGameTime())
					{
						float sparkPos[3], direction[3], sparkAngle[3];
						for (int i = 0; i < 3; i++)
						{
							sparkPos[i] = vPos[i] + GetRandomFloat(-20.0, 20.0);
							sparkAngle[i] = GetRandomFloat(-89.0, 89.0);

						}
						GetAngleVectors(sparkAngle, direction, NULL_VECTOR, NULL_VECTOR);
						TE_SetupMetalSparks(sparkPos, direction);
						TE_SendToAll();
						sparkDelay[client] = GetGameTime() + ClampFloat(hpRatio, 1.0, 0.3);
					}
				}

				switch (dMoveType[hDrone])
				{
					case DroneMove_Hover:
					{
						if (ViewLocked[hDrone])
							GetAngleFromTurnRate(cAngles, vPos, droneAngles, TurnRate[hDrone], hDrone, vAngles);

						GetAngleVectors(vAngles, vVel[1], NULL_VECTOR, NULL_VECTOR); //forward movement
						if (buttons & IN_FORWARD)
							DroneSpeed[client][0] += DroneAcceleration[hDrone];
						else
							DroneSpeed[client][0] -= DroneAcceleration[hDrone];
						ScaleVector(vVel[1], DroneSpeed[client][0]);

						GetAngleVectors(vAngles, vVel[3], NULL_VECTOR, NULL_VECTOR); //back movement
						if (buttons & IN_BACK)
							DroneSpeed[client][2] += DroneAcceleration[hDrone];
						else
							DroneSpeed[client][2] -= DroneAcceleration[hDrone];
						ScaleVector(vVel[3], -DroneSpeed[client][2]);

						GetAngleVectors(vAngles, NULL_VECTOR, vVel[2], NULL_VECTOR); //right movement
						if (buttons & IN_MOVERIGHT)
						{
							DroneSpeed[client][1] += DroneAcceleration[hDrone];
							flRoll[client] += flRollRate;
						}
						else
							DroneSpeed[client][1] -= DroneAcceleration[hDrone];
						ScaleVector(vVel[2], DroneSpeed[client][1]);

						GetAngleVectors(vAngles, NULL_VECTOR, vVel[4], NULL_VECTOR); //left movement
						if (buttons & IN_MOVELEFT)
						{
							DroneSpeed[client][3] += DroneAcceleration[hDrone];
							flRoll[client] -= flRollRate;
						}
						else
							DroneSpeed[client][3] -= DroneAcceleration[hDrone];
						ScaleVector(vVel[4], -DroneSpeed[client][3]);

						GetAngleVectors(vAngles, NULL_VECTOR, NULL_VECTOR, vVel[5]); //up movement
						if (buttons & IN_JUMP)
							DroneSpeed[client][4] += DroneAcceleration[hDrone];
						else
							DroneSpeed[client][4] -= DroneAcceleration[hDrone];
						ScaleVector(vVel[5], DroneSpeed[client][4]);

						GetAngleVectors(vAngles, NULL_VECTOR, NULL_VECTOR, vVel[6]); //down movement
						if (buttons & IN_DUCK)
							DroneSpeed[client][5] += DroneAcceleration[hDrone];
						else
							DroneSpeed[client][5] -= DroneAcceleration[hDrone];
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
						if (ViewLocked[hDrone]) //only adjust angles if our view is locked to our client view angles
							GetAngleFromTurnRate(cAngles, vPos, droneAngles, TurnRate[hDrone], hDrone, vAngles);

						//specific variables for flying drones
						float forwardVec[3];

						GetAngleVectors(vAngles, forwardVec, NULL_VECTOR, NULL_VECTOR);

						if (buttons & IN_FORWARD)
						{
							DroneSpeed[client][0] += DroneAcceleration[hDrone];
						}
						else
						{
							DroneSpeed[client][0] -= DroneAcceleration[hDrone];
						}

						DroneSpeed[client][0] = ClampFloat(DroneSpeed[client][0], flMaxSpeed, FlyMinSpeed);
						ScaleVector(forwardVec, DroneSpeed[client][0]);
						vAbsVel = forwardVec;

						float turnRate = AngleDifference(vAngles, cAngles, turnRate);
						float diff = DroneYaw[hDrone][1] - DroneYaw[hDrone][0];
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
							DroneSpeed[client][0] += DroneAcceleration[hDrone];
						if (buttons & IN_BACK)
							DroneSpeed[client][0] -= DroneAcceleration[hDrone];

						DroneSpeed[client][0] = ClampFloat(DroneSpeed[client][0], flMaxSpeed);
						ScaleVector(vVel[1], DroneSpeed[client][0]);

						if (FloatAbs(DroneSpeed[client][0]) >= 50.0) //only steer if we have enough speed
						{
							if (buttons & IN_MOVERIGHT)
								vAngles[1] += TurnRate[hDrone];
							if (buttons & IN_MOVELEFT)
								vAngles[2] -= TurnRate[hDrone];
						}
					}
				}

				//manual reload
				if (buttons & IN_RELOAD && WeaponProps[hDrone][activeWeapon] > 0)
				{
					WeaponProps[hDrone][activeWeapon].SimulateReload();
					//StartWeaponReload(hDrone, activeWeapon, ReloadTime[hDrone][activeWeapon]);
				}

				//Swap weapons on alt-fire
				if (buttons & IN_ATTACK2 && AmmoChangeCooldown[hDrone] <= GetEngineTime())
				{
					int oldweapon = WeaponNumber[hDrone];
					if (WeaponNumber[hDrone] >= DroneWeapons[hDrone])
						WeaponNumber[hDrone] = 1;
					else
						WeaponNumber[hDrone]++;

					Action result;
					Call_StartForward(g_DroneChangeWeapon);

					Call_PushCell(hDrone);
					Call_PushCell(client);
					Call_PushArray(WeaponProps[hDrone][WeaponNumber[hDrone]], sizeof DroneWeapon);
					Call_PushCell(WeaponNumber[hDrone]);
					Call_PushString(sPluginName[hDrone]);

					Call_Finish(result);
					
					ResetWeaponRotation(WeaponProps[hDrone][oldweapon], droneAngles[1]);

					DroneActiveWeapon[hDrone] = WeaponNumber[hDrone];
					AmmoChangeCooldown[hDrone] = GetEngineTime() + 0.5;
				}

				//Use active weapon on drone
				if (buttons & IN_ATTACK && WeaponProps[hDrone][activeWeapon].CanFire(false))
				{
					FireWeapon(client, hDrone, activeWeapon, WeaponProps[hDrone][activeWeapon]);
				}

				buttons &= ~IN_ATTACK;
				WeaponProps[hDrone][activeWeapon].Simulate();
				/*
				if (ReloadDelay[hDrone][activeWeapon] <= GetEngineTime())
				{
					AmmoLoaded[hDrone][activeWeapon] = MaxAmmo[hDrone][activeWeapon];
					ReloadDelay[hDrone][activeWeapon] = FAR_FUTURE;
				}
				*/

				//update drone speed and angles
				TeleportEntity(hDrone, NULL_VECTOR, vAngles, vAbsVel);
			}
			else if (flDroneExplodeDelay[hDrone] <= GetEngineTime())
			{
				flDroneExplodeDelay[hDrone] = FAR_FUTURE;
				ResetClientView(DroneOwner[hDrone]);
				ExplodeDrone(hDrone);
				TryRemoveDrone(DroneOwner[hDrone]);
			}
		}
	}
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
		int model = weapon.GetWeapon();
		if (!IsValidEntity(model)) return;
		
		float pos[3], rot[3], aimangle[3], aimpos[3], cameraPos[3], aimvec[3];
		
		GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(drone, Prop_Send, "m_angRotation", rot);
		GetForwardPos(pos, rot, 0.0, 0.0, CameraHeight[drone], cameraPos); //Get our camera height relative to our drone's forward vector
		
		CD_GetDroneAimPosition(drone, cameraPos, angles, aimpos);	//find where the client is aiming at in relation to the drone

		MakeVectorFromPoints(pos, aimpos, aimvec); //draw vector from offset position to our aim position
		GetVectorAngles(aimvec, aimangle);
		//Need to clamp this angle based on weapon's max rotation parameters
		//Ignoring for now
		
		TeleportEntity(model, NULL_VECTOR, aimangle, NULL_VECTOR);
	}
}

void ResetWeaponRotation(DroneWeapon weapon, int drone, float yaw)
{
	if (!weapon.fixed)
	{
		int model = weapon.GetWeapon();
		if (IsValidEntity(weapon))
		{
			float angle[3] = {0.0, 0.0, 0.0};
			angle[1] = yaw;
			SetEntProp(model, NULL_VECTOR, angle, NULL_VECTOR);
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

void FireWeapon(int owner, int drone, int slot, DroneWeapon weapon)
{
	//AttackDelay[drone][weapon] = GetGameTime() + FireRate[drone][weapon];
	Action result = Plugin_Continue;

	Call_StartForward(g_DroneAttack);

	Call_PushCell(drone);
	Call_PushCell(owner);
	Call_PushArray(WeaponProps[drone][slot], sizeof DroneWeapon);
	Call_PushCell(slot);
	Call_PushString(sPluginName[drone]);

	Call_Finish(result);

	weapon.SimulateFire(result);
}

void StartWeaponReload(int drone, int weapon, float time)
{
	AmmoLoaded[drone][weapon] = 0;
	ReloadDelay[drone][weapon] = GetEngineTime() + time;
}

float AngleDifference(float droneAngle[3], float aimAngle[3], float turnRate)
{
	float forwardVec[3], aimVec[3];
	float droneAngle2[3]; droneAngle2 = droneAngle;
	float aimAngle2[3]; aimAngle2 = aimAngle;

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
		roll -= flRollRate;

	if (roll < 0.0)
		roll += flRollRate;

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
	Call_PushCell(DroneOwner[drone]);
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
	PrintToChatAll("Drone spawned");
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
	DroneEnt[client] = CreateEntityByName("prop_physics_override");
	int hDrone = DroneEnt[client];

	//Establish drone attributes
	kv.GetString("name", sName[hDrone], PLATFORM_MAX_PATH);
	kv.GetString("model", sModelName[hDrone], PLATFORM_MAX_PATH);
	kv.GetString("destroyed_model", sModelDestroyed[hDrone], PLATFORM_MAX_PATH, sModelName[hDrone]);
	DroneMaxHealth[hDrone] = kv.GetFloat("health", 100.0);
	DroneMaxSpeed[hDrone] = kv.GetFloat("speed", 300.0);
	DroneAcceleration[hDrone] = kv.GetFloat("acceleration", 5.0);
	SpeedOverride[hDrone] = 0.0;
	TurnRate[hDrone] = kv.GetFloat("turn_rate", 80.0);
	kv.GetString("movetype", sMoveType[hDrone], PLATFORM_MAX_PATH, "drone_hover");
	kv.GetString("plugin", sPluginName[hDrone], PLATFORM_MAX_PATH, "INVALID_PLUGIN");
	float height = kv.GetFloat("camera_height", 30.0);

	dMoveType[hDrone] = GetMoveType(sMoveType[hDrone]);

	switch (dMoveType[hDrone])
	{
		case DroneMove_Ground:
		{
			ViewLocked[hDrone] = false;
			SetEntityGravity(hDrone, 1.0);
		}
		default:
		{
			ViewLocked[hDrone] = true;
			SetEntityGravity(hDrone, 0.01);
		}
	}

	//Find total number of weapons for this drone
	DroneWeapons[hDrone] = 0;
	if (kv.JumpToKey("weapons"))
	{
		//char sWeapon[MAXWEAPONS][PLATFORM_MAX_PATH], sNumber[8], modelname[PLATFORM_MAX_PATH], wepname[MAX_WEAPON_LENGTH];
		char sNumber[8];
		//float offset[3], attackOffset[3];
		for (int i = 1; i <= MAXWEAPONS; i++)
		{
			FormatEx(sNumber, sizeof sNumber, "weapon%i", i);
			if (kv.JumpToKey(sNumber))
			{
				SetupWeapon(kv, WeaponProps[hDrone][i], hDrone);
				/*
				MaxAmmo[hDrone][i] = kv.GetNum("ammo_loaded", 1);
				ReloadTime[hDrone][i] = kv.GetFloat("reload_time", 1.0);
				FireRate[hDrone][i] = kv.GetFloat("attack_time", 0.5);
				if (MaxAmmo[hDrone][i] == 0) MaxAmmo[hDrone][i] = -1;
				AmmoLoaded[hDrone][i] = MaxAmmo[hDrone][i];
				*/
				kv.GoBack();
			}
			else
			{
				LogMessage("Found %i weapons for %s", DroneWeapons[hDrone], drone_name);
				break;
			}
			//SetDroneWeaponName(hDrone, sWeapon[i], i);
			DroneWeapons[hDrone]++;
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
	DroneHealth[hDrone] = DroneMaxHealth[hDrone];
	DroneIsDead[hDrone] = false;

	DispatchSpawn(hDrone);
	ActivateEntity(hDrone);
	TeleportEntity(hDrone, vPos, vAngles, vVel);

	DroneOwner[hDrone] = client;
	SetEntityMoveType(client, MOVETYPE_NONE);
	IsDrone[hDrone] = true;
	SetupViewPosition(client, hDrone, vPos, vAngles, height);
	SDKHook(hDrone, SDKHook_OnTakeDamage, OnDroneDamaged);

	WeaponNumber[hDrone] = 1;
	DroneActiveWeapon[hDrone] = WeaponNumber[hDrone];

	//PrintToChat(client, "Successfully created drone (%s) with owner: %i", drone_name, DroneOwner[hDrone]);

	IsInDrone[client] = true;

	SetVariantInt(1);
	AcceptEntityInput(client, "SetForcedTauntCam");
	
	if(kv.GetNum("vehicle"))
	{
		SetPlayerSeatPosition(client, hDrone, kv);
	}
	delete kv;

	Call_StartForward(g_DroneCreated);

	Call_PushCell(hDrone);
	Call_PushCell(client);
	Call_PushString(sPluginName[hDrone]);
	Call_PushString(drone_name);

	Call_Finish();
}

void SetupWeapon(KeyValues kv, DroneWeapon weapon, int drone)
{
	char weaponname[MAX_WEAPON_LENGTH], modelname[PLATFORM_MAX_PATH];
	float offset[3], projoffset[3];
	kv.GetString("name", weaponname, sizeof weaponname, "INVALID_WEAPON");
	kv.GetString("model", modelname, sizeof modelname);
	if (strlen(modelname) > 3)
		weapon.SetModel(modelname);
		
	weapon.drone = EntIndexToEntRef(drone);
	kv.GetVector("offset", offset);
	weapon.SetOffset(offset, false);
	kv.GetVector("proj_offset", projoffset);
	weapon.SetOffset(projoffset, true);
	weapon.SetName(weaponname);
	weapon.maxammo = kv.GetNum("ammo_loaded", 1);
	weapon.reloadtime = kv.GetFloat("reload_time", 1.0);
	weapon.firerate = kv.GetFloat("attack_time", 0.5);
	weapon.fixed = view_as<bool>(kv.GetNum("fixed", 1));
	if (!weapon.fixed)
	{
		weapon.pitch = kv.GetFloat("max_angle_y", 0.0);
		weapon.yaw = kv.GetFloat("max_angle_x", 0.0);
	}
	weapon.Spawn();
}

void SetupViewPosition(int client, int drone, const float pos[3], const float angle[3], float height)
{
	char sTargetName[64];
	float rPos[3];
	Format(sTargetName, sizeof sTargetName, "camerapos%d", drone);
	DispatchKeyValue(drone, "targetname", sTargetName);

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
	DroneCamera[drone] = camera;
}

void SetPlayerSeatPosition(int client, int drone, KeyValues kv, const char[] seatname)
{
	float offset[3], seat[3], pos[3], angle[3];
	if (kv.JumpToKey(seatname))
	{
		kv.GetVector("offset", offset);
		GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(drone, Prop_Send, "m_angRotation", angle);
		GetOffsetPosition(pos, angle, offset, seat);

		TeleportEntity(client, seat, NULL_VECTOR, NULL_VECTOR);
		if (!kv.GetNum("visible"))
		{
			SetEntityRenderFX(client, RENDERFX_FADE_FAST);
			RemoveWearables(client);
		}
		SetVariantString("!activator");
		AcceptEntityInput(client, "SetParent", drone, client, 0);
		//TODO - Set player animation to kart animation
	}
}

void RemoveWearables(int client)
{
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "tf_wearable")) != -1)
	{
		if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))
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
		if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))
		{
			TF2_RemoveWearable(client, entity);
		}
	}
}

void PlayerExitVehicle(int client)
{
	AcceptEntityInput(client, "ClearParent");
	SetEntityRenderFX(client, RENDERFX_NONE);
	TF2_RegeneratePlayer(client);
}

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

/*
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
*/

stock bool TryRemoveDrone(int client)
{
	if (IsValidDrone(DroneEnt[client]))
	{
		ExplodeDrone(DroneEnt[client]);
		DroneOwner[DroneEnt[client]] = -1;
		IsDrone[DroneEnt[client]] = false;
		AcceptEntityInput(DroneEnt[client], "Kill");
		DroneEnt[client] = -1;
		return true;
	}
	return false;
}

int GetDroneCamera(int drone)
{
	if (IsValidDrone(drone))
	{
		return DroneCamera[drone];
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

stock bool IsValidDrone(int drone)
{
	if (IsValidEntity(drone) && drone > MaxClients)
	{
		if (IsDrone[drone])
			return true;
	}

	return false;
}
