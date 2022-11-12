#pragma semicolon 1
#include <customdrones>

GlobalForward DroneCreated;
GlobalForward DroneCreatedWeapon;
GlobalForward DroneEntered;
GlobalForward DroneExited;
GlobalForward DroneRemoved;
GlobalForward DroneDestroyed;
GlobalForward DroneChangeWeapon;
GlobalForward DroneAttack;

// Player drone reference
FObject DroneRef[MAXPLAYERS+1];

// Drone information for the given entity
FDrone Drone[2049];

// Weapons tied to drones
FDroneWeapon DroneWeapons[2049][MAXWEAPONS];

// Seats tied to drones
FDroneSeat DroneSeats[2049][MAXSEATS];

int ExplosionSprite;

#include "CustomDroneMovement.sp"
//#include "CustomDroneWeapons.sp"

public Plugin MyInfo = {
	name 			= 	"[TF2] Custom Drones 2",
	author 			=	"Ivory",
	description		= 	"Customizable drones for Team Fortress 2",
	version 		= 	"2.0.0"
};


public void OnPluginStart()
{
	RegAdminCmd("sm_drone", CmdDrone, ADMFLAG_ROOT); // Admin command for spawning drones
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("post_inventory_application", OnPlayerResupply);

	ExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");

	//Forwards
	DroneCreated = CreateGlobalForward("CD_OnDroneCreated", ET_Ignore, Param_Any, Param_String, Param_String); //drone struct, plugin, config
	DroneCreatedWeapon = CreateGlobalForward("CD_OnWeaponCreated", ET_Ignore, Param_Any, Param_Any, Param_String, Param_String); //drone, weapon, weapon plugin, config
	DroneEntered = CreateGlobalForward("CD_OnPlayerEnterDrone", ET_Ignore, Param_Any, Param_Cell, Param_Cell, Param_String, Param_String); //drone struct, client, seat, plugin, config
	DroneExited = CreateGlobalForward("CD_OnPlayerExitDrone", ET_Ignore, Param_Any, Param_Cell, Param_Cell, Param_String, Param_String); //drone struct, client, seat, plugin, config
	DroneRemoved = CreateGlobalForward("CD_OnDroneRemoved", ET_Ignore, Param_Cell, Param_String); //drone, plugin
	DroneChangeWeapon = CreateGlobalForward("CD_OnWeaponChanged", ET_Hook, Param_Cell, Param_Cell, Param_Any, Param_Cell, Param_String); //drone, owner, weapon, slot, plugin
	DroneDestroyed = CreateGlobalForward("CD_OnDroneDestroyed", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_String); //drone, owner, attacker, damage, plugin
	DroneAttack = CreateGlobalForward("CD_OnDroneAttack", ET_Hook, Param_Cell, Param_Cell, Param_Any, Param_Cell, Param_String); //drone, gunner, weapon, slot, plugin
}

/***************
 * Event Hooks

****************/

Action OnRoundStart(Event event, const char[] name, bool dBroad)
{
	FClient client;
	for (int i = 1; i <= MaxClients; i++)
	{
		client.Set(i);
		if (client.Valid())
			ResetClientView(i);
	}

	return Plugin_Continue;
}

// Prevent resupplying from causing issues with players piloting drones
Action OnPlayerResupply(Event event, const char[] name, bool dBroad)
{
	int clientId = GetClientOfUserId(event.GetInt("userid"));

	if (Player[clientId].inDrone)
	{
		CreateTimer(0.5, DroneResupplied, clientId, TIMER_FLAG_NO_MAPCHANGE); // Need a longer delay than RequestFrame
	}
}

Action OnPlayerDeath(Event event, const char[] name, bool dBroad)
{
	FClient client, attacker;

	client = ConstructClient(event.GetInt("userid"), true);
	attacker = ConstructClient(event.GetInt("attacker"), true);

	if (client.Valid() && PlayerInDrone(client))
	{
		FDrone drone = GetClientDrone(client);
		if (drone.Valid())
		{
			KillDrone(drone, drone.GetHull(), attacker, 0.0, 0);
			ResetClientView(client);
		}
	}
	return Plugin_Continue;
}

Action DroneResupplied(Handle timer, int clientId)
{
	RemoveWearables(clientId);
	//TF2_RemoveAllWeapons(client);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Deprecated Natives, will still work but use CD_GetClientDrone to retrieve properties easier
	CreateNative("CD_GetDroneHealth", Native_GetDroneHealth);
	CreateNative("CD_GetDroneMaxHealth", Native_GetDroneMaxHealth);
	CreateNative("CD_GetDroneActiveWeapon", Native_GetDroneActiveWeapon);
	CreateNative("CD_GetWeaponAttackSound", Native_AttackSound);
	
	CreateNative("CD_SpawnDroneByName", Native_SpawnDroneName);
	CreateNative("CD_GetDroneWeapon", Native_GetDroneWeapon);
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
	CreateNative("CD_GetParamString", Native_GetString);
	CreateNative("CD_SpawnDroneBomb", Native_SpawnBomb);

	return APLRes_Success;
}


/********************************************************************************
	NATIVE FUNCTIONS AND HELPERS

********************************************************************************/

public any Native_ViewLock(Handle plugin, int args)
{
	FObject drone;
	drone = FObject(GetNativeCell(1));
	
	if (drone.Valid())
	{
		if (IsValidDrone(drone.Get()))
		{
			int droneId = drone.Get();
			Drone[droneId].viewlocked = !Drone[droneId].viewlocked;
		}
		else
			ThrowNativeError(017, "Entity index %i is not a valid drone", drone);

		return DroneInfo[droneId].viewlocked;
	}
	else
		ThrowNativeError(017, "Entity index %i is not valid!", drone.Get());

	return false;
}

public int Native_OverrideMaxSpeed(Handle plugin, int args)
{
	FObject drone;
	drone = FObject(GetNativeCell(1));

	float speed = GetNativeCell(2);

	if (drone.Valid())
	{
		int droneId = drone.Get();
		if (IsValidDrone(droneId))
			Drone[droneId].speedoverride = speed;
		else
		   ThrowNativeError(017, "Entity index %i is not a valid drone", drone); 
	}
	else
		ThrowNativeError(017, "Entity index %i is not valid!", drone.Get());

	return 0;
}

public int Native_FireWeapon(Handle plugin, int args)
{
	FClient owner;
	FObject drone;

	owner = FClient(GetNativeCell(1), false);
	drone = FObject(GetNativeCell(2));

	if (owner.Valid() && drone.Valid())
	{
		int droneId = drone.Get();

		if (IsValidDrone(droneId))
		{
			int slot = Drone[droneId].activeWeapon;

			if (DroneWeapons[droneId][slot].CanFire(true))
				FireWeapon(owner, drone, slot, DroneWeapons[droneId][slot]);
		}
	}

	return 0;
}

public int Native_DroneTakeDamage(Handle plugin, int args)
{
	FObject drone, inflictor;
	FClient attacker;

	drone = FObject(GetNativeCell(1));
	attacker = FClient(GetNativeCell(2));
	inflictor = FObject(GetNativeCell(3));

	float damage = GetNativeCell(4);

	bool crit = view_as<bool>(GetNativeCell(5));

	if (IsValidDrone(drone))
	{
		int droneId = drone.Get();

		DroneTakeDamage(Drone[droneId], drone, attacker, inflictor, damage, crit);
	}

	return 0;
}

public int Native_ValidDrone(Handle plugin, int args)
{
	if (IsValidDrone(FObject(GetNativeCell(1))))
		return true;

	return false;
}

public int Native_GetDroneHealth(Handle plugin, int args)
{
	FObject drone;
	drone = FObject(GetNativeCell(1));

	if (IsValidDrone(drone))
	{
		int droneId = drone.Get();
		return RoundFloat(Drone[droneId].health);
	}

	return 0;
}

public int Native_GetDroneMaxHealth(Handle plugin, int args)
{
	FObject drone;
	drone = FObject(GetNativeCell(1));

	if (IsValidDrone(drone))
	{
		int droneId = drone.Get();
		return RoundFloat(Drone[droneId].maxHealth);
	}

	return 0;
}

public any Native_GetDroneWeapon(Handle plugin, int args)
{
	FObject drone;
	drone = FObject(GetNativeCell(1));

	if (IsValidDrone(drone))
	{
		int droneId = drone.Get();
		int slot = GetNativeCell(2);

		SetNativeArray(3, DroneWeapons[droneId][slot], sizeof FDroneWeapon);
	}
}

public any Native_GetDroneActiveWeapon(Handle plugin, int args)
{
	FObject drone;
	drone = FObject(GetNativeCell(1));

	if (IsValidDrone(drone))
	{
		int droneId = drone.Get();
		SetNativeArray(2, DroneWeapons[droneId][Drone[droneId].activeWeapon], sizeof FDroneWeapon);
	}

	return 0;
}

public int Native_SetDroneWeapon(Handle plugin, int args)
{
	FObject drone;
	drone = FObject(GetNativeCell(1));

	if (IsValidDrone(drone))
	{
		int droneId = drone.Get();

		int slot = GetNativeCell(2);

		Drone[droneId].activeWeapon = slot;
	}

	return 0;
}

public int Native_SpawnDroneName(Handle plugin, int args)
{
	FClient client;
	client = FClient(GetNativeCell(1));

	char name[128];
	GetNativeString(2, name, sizeof(name));

	TryCreateDrone(client, name);
}

public int Native_SetWeaponReload(Handle plugin, int args)
{
	FObject drone;
	drone = FObject(GetNativeCell(1));

	if (IsValidDrone(drone))
	{
		int droneId = drone.Get();
		int slot = GetNativeCell(2);
		float delay = GetNativeCell(3);

		if (!delay)
			delay = DroneWeapons[droneId][slot].reloadTime;

		DroneWeapons[droneId][slot].SimulateReload();
	}
}

public any Native_GetFloatParam(Handle plugin, int args)
{
	float result;

	char config[64], key[64], weapon[64];

	int slot = GetNativeCell(3);

	GetNativeString(1, config, sizeof config);
	GetNativeString(2, key, sizeof key);
	
	// TODO - Store keyvalues in a global array so we don't have to keep creating new ones
	KeyValues drone = new KeyValues("Drone");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", config);
	drone.ImportFromFile(path);

	if (slot)
	{
		drone.JumpToKey("weapons");
		Format(weapon, sizeof weapon, "weapon%i", slot);
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

	int slot = GetNativeCell(3);

	GetNativeString(1, config, sizeof config);
	GetNativeString(2, key, sizeof key);

	KeyValues drone = new KeyValues("Drone");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", config);
	drone.ImportFromFile(path);

	if (slot)
	{
		drone.JumpToKey("weapons");
		Format(weapon, sizeof weapon, "weapon%i", slot);
		drone.JumpToKey(weapon);
	}
	result = drone.GetNum(key);
	delete drone;

	return result;
}

public any Native_GetString(Handle plugin, int args)
{
	char config[64], key[64], weapon[64];

	int slot = GetNativeCell(3);

	GetNativeString(1, config, sizeof config);
	GetNativeString(2, key, sizeof key);

	int size = GetNativeCell(5);
	char[] result = new char[size];

	KeyValues drone = new KeyValues("Drone");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", config);
	drone.ImportFromFile(path);

	if (slot)
	{
		drone.JumpToKey("weapons");
		Format(weapon, sizeof weapon, "weapon%i", slot);
		drone.JumpToKey(weapon);
	}
	drone.GetString(key, result, size);
	delete drone;

	SetNativeString(4, result, size);
}

public any Native_HitscanAttack(Handle plugin, int args)
{
	FClient owner;
	FObject drone;

	owner = FClient(GetNativeCell(1));
	drone = FObject(GetNativeCell(2));

	FDroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof FDroneWeapon);
	
	FTransform spawn;

	spawn = weapon.GetMuzzleTransform(); //get our weapon's muzzle position

	EDamageType dmgType = view_as<EDamageType>(GetNativeCell(4));

	if (owner.Valid() && IsValidDrone(drone))
	{
		int droneId = drone.Get();

		float angle[3], aimPos[3], aimVec[3], aimAngle[3], cameraPos[3], droneAngle[3], dronePos[3];

		FVector aimPos, aimVec, cameraPos, dronePos;
		FRotator angle, aimAngle, droneAngle;
		
		aimAngle = owner.GetEyeAngles();

		droneAngle = drone.GetAngles();
		dronePos = drone.GetPosition();

		FVector offset;
		offset = FVector(0.0, 0.0, Drone[droneId].cameraHeight);

		cameraPos = GetOffsetPos(dronePos, droneAngle, offset); //Get our camera height relative to our drone's forward vector

		aimPos = GetDroneAimPosition(drone, cameraPos, aimAngle);	//find where the client is aiming at in relation to the drone

		Vector_MakeFromPoints(pos, aimPos, aimVec);

		Vector_GetAngles(aimVec, angle);

		//TODO - restrict angles at which attacks can be fired

		if (weapon.inaccuracy)
		{
			angle.pitch += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
			angle.yaw += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
		}



		// Damage our hit entity below and create our tracer effect
		FObject victim;
		bool isDrone = false;

		RayTrace bullet = new RayTrace(pos, aimPos, MASK_SHOT, FilterDroneShoot, drone.Get());
		if (bullet.DidHit())
		{
			victim = bullet.GetHitEntity();
			isDrone = IsValidDrone(victim);
		}
		delete bullet;

		switch (type)
		{
			case WeaponType_Gun:
			{
				CreateTracer(pos, endPos);
			}
			case CDWeapon_Laser:
			{
				//TODO
			}
		}

		if (victim.Valid())
		{
			switch (dmgType)
			{
				case DamageType_Rangeless: //no damage falloff
				{
					if (isDrone)
					{
						int hitDroneId = victim.Get();
						DroneTakeDamage(Drone[hitDroneId], victim, owner, drone, weapon.damage, false);
					}
					else if (victim.Valid())
						SDKHooks_TakeDamage(victim.Get(), owner.Get(), owner.Get(), weapon.damage, DMG_ENERGYBEAM);
				}
				default:
				{
					float damage = Damage_Hitscan(victim, drone, weapon.damage);
					if (isDrone)
					{
						int hitDroneId = victim.Get();
						DroneTakeDamage(Drone[hitDroneId], victim, owner, drone, damage, false);
					}
					else
						SDKHooks_TakeDamage(victim.Get(), owner.Get(), owner.Get(), damage, DMG_ENERGYBEAM);
				}
			}
		}
	}
}

bool FilterDroneShoot(int entity, int mask, int drone)
{
	FObject owner, hit;
	owner = Drone[drone].GetOwner();

	hit = FObject(entity);

	FClient player, check;
	
	player = CastToClient(owner);
	check = CastToClient(hit);

	if (player.Valid() && check.Valid())
	{
		if (player.GetTeam() == check.GetTeam()) // ignore teammates
			return false;
	}

	if (entity == drone)
		return false;

	return true;
}

float Damage_Hitscan(FObject victim, FObject drone, float baseDamage)
{
	FVector pos, vicPos;
	float distance;

	//Setup distance between drone and target
	pos = drone.GetPosition();
	vicPos = victim.GetPosition();

	distance = pos.DistanceTo(vicPos);

	float dmgMod = ClampFloat((512.0 / distance), 1.5, 0.528);
	baseDamage *= dmgMod;

	return baseDamage;
}

public any Native_SpawnRocket(Handle Plugin, int args)
{
	FClient owner;
	FObject drone;

	owner = FClient(GetNativeCell(1));
	drone = FObject(GetNativeCell(2));

	FDroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof FDroneWeapon);
	
	FTransform spawn;

	spawn = weapon.GetMuzzleTransform(); //get our weapon's muzzle position

	EProjType projectile = GetNativeCell(4);

	//PrintToConsole(owner, "Damage: %.1f\nSpeed: %.1f\noffset x: %.1f\noffset y: %.1f\noffset z: %.1f", damage, speed, overrideX, overrideY, overrideZ);

	FVector pos, aimPos, aimVec, camearPos;
	FRotator aimAngle, droneAngle;

	char netname[64], classname[64];

	FRocket rocket;

	if (IsValidDrone(drone))
	{
		//Get Spawn Position
		aimAngle = owner.GetEyeAngles();
		droneAngle = drone.GetAngles();
		dronePos = drone.GetPosition();

		FVector offset;
		offset = FVector(0.0, 0.0, Drone[droneId].cameraHeight);

		cameraPos = GetOffsetPos(dronePos, droneAngle, offset); //Get our camera height relative to our drone's forward vector

		aimPos = GetDroneAimPosition(drone, cameraPos, aimAngle);	//find where the client is aiming at in relation to the drone

		Vector_MakeFromPoints(spawn.position, aimPos, aimVec);

		Vector_GetAngles(aimVec, angle);

		if (weapon.inaccuracy)
		{
			aimAngle.pitch += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
			aimAngle.yaw += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
		}
		rocket = CreateDroneRocket(owner, spawn.position, projectile, weapon.projspeed, weapon.damage);

		rocket.Fire(aimAngle);

		if (projectile == DroneProj_Impact)
			SDKHook(rocket.Get(), SDKHook_Touch, OnProjHit);

	}
	
	return rocket.Get();
}

Action OnProjHit(int entity, int victim)
{
	FObject hit, rocket;
	FClient client, owner;

	hit = FObject(victim);
	rocket = FObject(entity);

	client = CastToClient(hit);
	owner = CastToClient(rocket.GetOwner());

	if (!client.Valid()) // Not a client
	{
		if (IsValidDrone(hit)) // Is a drone
		{
			float damage = GetEntDataFloat(entity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4); //get our damage
			DroneTakeDamage(Drone[victim], FObject(victim), owner, rocket, damage, false);
			
			rocket.Kill();

			return Plugin_Handled;
		}

		char classname[64];
		hit.GetClassname(classname, sizeof classname);

		if (victim == 0 || !StrContains(classname, "prop_", false))
		{
			rocket.Kill();

			return Plugin_Handled;
		}

		else if (StrContains(classname, "obj_", false)) //engineer buildings
		{
			float damage = GetEntDataFloat(entity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4); //get our damage

			SDKHooks_TakeDamage(victim, entity, owner.Get(), damage, DMG_ENERGYBEAM);

			rocket.Kill();

			return Plugin_Handled;
		}
		else return Plugin_Continue;
	}
	else // Entity hit is a client
	{
		if (owner.Valid())
		{
			if (owner.GetTeam() != client.GetTeam())
			{
				FObject drone;
				drone = GetClientDrone(owner);

				FVector pos, vicPos;
				float damage, distance;

				damage = GetEntDataFloat(entity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4);

				//Setup distance between drone and target
				pos = drone.GetPosition();
				
				vicPos = client.GetPosition();
				distance = pos.DistanceTo(vicPos);

				//Standard rampup and falloff for rockets
				float dmgMod = ClampFloat((512.0 / distance), 1.25, 0.528);
				damage *= dmgMod;
				SDKHooks_TakeDamage(victim, entity, owner.Get(), damage, DMG_ENERGYBEAM);

				rocket.Kill();

				return Plugin_Handled;
			}
		}
		else 
			return Plugin_Handled; // Should allow rockets to pass through teammates without exploding
	}
	
	rocket.Kill();
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

Action DetonateBombTimer(Handle timer, int bomb)
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

FVector GetDroneAimPosition(FObject drone, FVector pos, FRotator angle)
{
	// Max range on attacks is 10000 hu
	FVector end;
	end = angle.GetForwardVector();
	end.Scale(10000.0);
	end.Add(pos);

	FVector result;

	RayTrace trace = RayTrace(pos, end, MASK_SHOT, FilterDrone, drone.Get());
	if (trace.DidHit())
		result = trace.GetEndPosition();
	else
		result = end;

	delete trace;

	return result;
}

bool FilterDrone(int entity, int mask, int exclude)
{
	FObject owner = Drone[exclude].GetOwner();
	if (entity == owner.Get())
		return false;
	if (entity == exclude)
		return false;

	return true;
}

/****************
* Client Functions
****************/

// Reset player variables
public void OnClientPostAdminCheck(int client)
{
	Player[client].InDrone = false;
}

public void OnClientDisconnect(int clientId)
{
	FDrone drone;
	FClient owner;

	owner.Set(clientId);
	drone = GetClientDrone(owner);

	if (drone.Valid())
	{
		int droneId = drone.Get();
		int seatIndex = GetPlayerSeat(owner, DroneSeats[droneId]);

		PlayerExitVehicle(drone, DroneSeats[droneId][seatIndex], owner);
	}
}


/****************
* Drone Creation
****************/

// When a new entity is created, lets make sure it is not initialized as a drone
public void OnEntityDestroyed(int entityId)
{
	FObject entity;
	entity.Set(entityId);

	if (IsValidDrone(entity))
		Drone[entityId].Clear();
}

Action CmdDrone(int clientId, int args)
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
			clientId,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		targets = false;
	}

	FClient client;
	if (targets)
	{
		for (int i = 0; i < target_count; i++)
		{
			int target = target_list[i];

			client.Set(i);

			if (client.Alive())
				OpenMenu(client);
		}
	}
	else
	{
		client.Set(clientId);

		if (client.Alive())
			OpenMenu(client);
	}
	return Plugin_Handled;
}

// Open our drone menu so we can select a drone to spawn
void OpenMenu(FClient client)
{
	Menu DroneMenu = new Menu(DroneMenuCallback, MENU_ACTIONS_ALL);
	DroneMenu.SetTitle("Drone Selection");

	char droneDir[PLATFORM_MAX_PATH];
	char fileName[PLATFORM_MAX_PATH];

	FileType type;
	BuildPath(Path_SM, droneDir, sizeof droneDir, "configs/drones");

	Handle dir = OpenDirectory(droneDir);
	while (ReadDirEntry(dir, fileName, sizeof fileName, type))
	{
		char dirName[PLATFORM_MAX_PATH];
		Format(dirName, sizeof dirName, "%s/%s", droneDir, fileName);
		if (FileExists(dirName))
		{
			ReplaceString(fileName, sizeof fileName, ".txt", "", false);
			DroneMenu.AddItem(fileName, fileName);
		}
	}
	CloseHandle(dir);
	SetMenuExitButton(DroneMenu, true);
	DroneMenu.Display(client.Get(), 60);
}

// Callback handler for drone menu
int DroneMenuCallback(Menu menu, MenuAction action, int client, int param1)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param1, info, sizeof(info));
			
			CreateDroneByName(ConstructClient(client), info);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

/**
 * Spawn a drone by name and force enter the given client
 * 
 * @param owner     Client owning this drone. Use GetWorld() if spawning with no owner
 * @param name      Name of the drone to spawn
 * @return          Object containing the drone information
 */
FDrone CreateDroneByName(FClient owner, const char[] name)
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
		if (StrEqual(name, FileName))
		{
			PrintToChatAll("Found drone %s", drone_name);
			FDrone drone;
			drone = SpawnDrone(client, name);
			CloseHandle(hDir);
			return;
		}
		LogMessage("Found Config %s", FileName);
	}

	//PrintToChatAll("Unable to find drone %s", drone_name);
	CloseHandle(hDir);
	return;
}

/**
 * Spawn a drone after creating the info for it
 * 
 * @return     Return description
 */
FDrone SpawnDrone()
{
	
}

/******************
* Drone Removal
******************/



/**
 * Kills the given drone
 * 
 * @param drone        Drone object being killed
 * @param hull         Physical entity object of the drone
 * @param attacker     Client that killed the drone, can be the world
 * @param damage       Damage dealt
 * @param weapon       Weapon used
 */
void KillDrone(FDrone drone, FObject hull, FClient attacker, float damage, int weapon)
{
	FClient owner;
	owner = CastToClient(drone.GetOwner());

	if (owner.Valid())
	{
		int droneId = hull.Get();
		int seatIndex = GetPlayerSeat(owner, DroneSeats[droneId]);

		PlayerExitVehicle(drone, DroneSeats[droneId][seatIndex], owner);
	}

	drone.Health = 0.0;
	drone.Alive = false;
	drone.RemoveTimer.Set(3.0);

	hull.AttachParticle("burningplayer_flyingbits");

	Call_StartForward(DroneDestroyed);

	Call_PushArray(hull, sizeof FObject);
	Call_PushArray(owner, sizeof FClient);
	Call_PushArray(attacker, sizeof FClient);
	Call_PushFloat(damage);
	Call_PushString(drone.Plugin);

	Call_Finish();
}