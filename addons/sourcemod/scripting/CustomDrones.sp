#pragma semicolon 1
#include <customdrones>

int ExplosionSprite;

#include "DroneProperties.sp"

#include "DroneController.sp"
#include "DroneWeapons.sp"

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

	//Forwards
	DroneCreated = CreateGlobalForward("CD_OnDroneCreated", ET_Ignore, Param_Any, Param_String, Param_String); //drone struct, plugin, config
	DroneCreatedWeapon = CreateGlobalForward("CD_OnWeaponCreated", ET_Ignore, Param_Any, Param_Any, Param_String, Param_String); //drone, weapon, weapon plugin, config
	DroneWeaponDestroyed = CreateGlobalForward("CD_OnWeaponDestroyed", ET_Ignore, Param_Any, Param_Any, Param_String, Param_String); //drone, weapon, weapon plugin, config
	DroneEntered = CreateGlobalForward("CD_OnPlayerEnterDrone", ET_Ignore, Param_Any, Param_Cell, Param_Cell, Param_String, Param_String); //drone struct, client, seat, plugin, config
	DroneExited = CreateGlobalForward("CD_OnPlayerExitDrone", ET_Ignore, Param_Any, Param_Cell, Param_Cell, Param_String, Param_String); //drone struct, client, seat, plugin, config
	DroneRemoved = CreateGlobalForward("CD_OnDroneRemoved", ET_Ignore, Param_Cell, Param_String); //drone, plugin
	DroneChangeWeapon = CreateGlobalForward("CD_OnWeaponChanged", ET_Hook, Param_Cell, Param_Cell, Param_Any, Param_Cell, Param_String); //drone, owner, weapon, slot, plugin
	DroneDestroyed = CreateGlobalForward("CD_OnDroneDestroyed", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_String); //drone, owner, attacker, damage, plugin
	DroneAttack = CreateGlobalForward("CD_OnDroneAttack", ET_Hook, Param_Any, Param_Any, Param_Any, Param_Cell, Param_CellByRef, Param_String, Param_String); //drone, gunner, weapon, slot, weapon plugin, drone plugin
}

public void OnMapStart()
{
	ExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");
}

public void OnConfigsExecuted()
{
	LoadConfigs();
}

void LoadConfigs()
{
	char DroneDir[PLATFORM_MAX_PATH];
	char FileName[PLATFORM_MAX_PATH];
	char PathName[PLATFORM_MAX_PATH];
	int droneCount, pluginCount;
	FileType type;
	BuildPath(Path_SM, DroneDir, sizeof DroneDir, "configs/drones");

	if (!DirExists(DroneDir))
		SetFailState("Drones directory (%s) does not exist!", DroneDir);

	Handle dir = OpenDirectory(DroneDir);
	while (ReadDirEntry(dir, FileName, sizeof FileName, type))
	{
		if (type != FileType_File) continue;
		Format(PathName, sizeof PathName, "%s/%s", DroneDir, FileName);

		KeyValues kv = new KeyValues("Drone");
		if (!kv.ImportFromFile(PathName))
		{
			LogMessage("Unable to open %s. It will be excluded from drone list.", PathName);
			CloseHandle(dir);
			delete kv;
			continue;
		}
		if (!kv.JumpToKey("plugin"))
		{
			LogMessage("Drone config %s does not have a specified plugin, please specify a plugin for this drone!", PathName);
			CloseHandle(dir);
			delete kv;
			continue;
		}
		LogMessage("Found Drone Config: %s", FileName);
		droneCount++;
		kv.Rewind();
		delete kv;
	}

	CloseHandle(dir);

	char directory[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, directory, sizeof directory, "plugins/drones");
	if (!DirExists(directory))
		SetFailState("Plugin directory (%s) does not exist!", directory);

	dir = OpenDirectory(directory);

	while (ReadDirEntry(dir, FileName, sizeof FileName, type))
	{
		if (type != FileType_File) continue;
		if (StrContains(FileName, ".smx") == -1) continue;
		Format(FileName, sizeof FileName, "drones/%s", FileName);
		//ServerCommand("sm plugins load %s", FileName);
		pluginCount++;
	}
	CloseHandle(dir);

	LogMessage("Custom Drones loaded successfully with %i drones and %i plugins.", droneCount, pluginCount);
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
		if (IsClientInGame(i))
			ResetClientView(client);
	}

	return Plugin_Continue;
}

// Prevent resupplying from causing issues with players piloting drones
Action OnPlayerResupply(Event event, const char[] name, bool dBroad)
{
	int clientId = GetClientOfUserId(event.GetInt("userid"));

	if (Player[clientId].InDrone)
	{
		CreateTimer(0.5, DroneResupplied, clientId, TIMER_FLAG_NO_MAPCHANGE); // Need a longer delay than RequestFrame
	}

	return Plugin_Continue;
}

Action OnPlayerDeath(Event event, const char[] name, bool dBroad)
{
	FClient client, attacker;

	client = ConstructClient(event.GetInt("userid"), true);
	attacker = ConstructClient(event.GetInt("attacker"), true);

	if (client.Valid() && PlayerInDrone(client))
	{
		FDrone drone;
		drone = GetClientDrone(client);

		if (drone.Valid())
		{
			KillDrone(drone, drone.GetObject(), attacker, 0.0, drone.GetObject());
			ResetClientView(client);
		}
	}
	return Plugin_Continue;
}

Action DroneResupplied(Handle timer, int clientId)
{
	RemoveWearables(ConstructClient(clientId));
	//TF2_RemoveAllWeapons(client);

	return Plugin_Stop;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Deprecated Natives, will still work but use CD_GetClientDrone to retrieve properties easier
	CreateNative("CD_GetDroneHealth", Native_GetDroneHealth);
	CreateNative("CD_GetDroneMaxHealth", Native_GetDroneMaxHealth);
	//CreateNative("CD_GetDroneActiveWeapon", Native_GetDroneActiveWeapon);
	//CreateNative("CD_GetWeaponAttackSound", Native_AttackSound);
	
	CreateNative("CD_SpawnDroneByName", Native_SpawnDroneName);
	CreateNative("CD_GetDroneWeapon", Native_GetDroneWeapon);
	//CreateNative("CD_SetDroneActiveWeapon", Native_SetDroneWeapon);
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

void ResetClientView(FClient client)
{
	if (client.Valid())
	{
		int clientId = client.Get();

		SetClientViewEntity(clientId, clientId);
		Player[clientId].InDrone = false;
		SetEntityMoveType(clientId, MOVETYPE_WALK);
	}
}

void RemoveWearables(FClient client)
{
	if (client.Valid())
	{
		int entity = MaxClients + 1;
		while((entity = FindEntityByClassname(entity, "tf_wearable")) != -1)
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == client.Get())
			{
				switch(GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex"))
				{
					default:
					{
						TF2_RemoveWearable(client.Get(), entity);
					}
				}
			}
		}
		entity = MaxClients + 1;
		while((entity = FindEntityByClassname(entity, "tf_powerup_bottle")) != -1) //mvm canteens
		{
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == client.Get())
			{
				TF2_RemoveWearable(client.Get(), entity);
			}
		}
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

			client.Set(target);

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
			
			CreateDroneByName(ConstructClient(client), info, ConstructVector());
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

/**
 * Spawn a drone by name
 * 
 * @param owner     Client owning this drone. Use GetWorld() if spawning with no owner
 * @param name      Name of the drone to spawn
 * @param spawnPos	Spawn position if not spawning for a client
 * @return          Object containing the drone information
 */
FDrone CreateDroneByName(FClient owner, const char[] name, const FVector spawnPos)
{
	char Directory[PLATFORM_MAX_PATH];
	char FileName[PLATFORM_MAX_PATH];
	FileType type;

	BuildPath(Path_SM, Directory, sizeof Directory, "configs/drones");
	Handle dir = OpenDirectory(Directory);

	FDrone drone;

	while (ReadDirEntry(dir, FileName, sizeof FileName, type))
	{
		if (type != FileType_File) continue;
		ReplaceString(FileName, sizeof FileName, ".txt", "", false);
		if (StrEqual(name, FileName))
		{
			//PrintToChatAll("Found drone %s", drone_name);
			drone = SpawnDrone(owner, name, spawnPos);
		}
		LogMessage("Found Config %s", FileName);
	}

	//PrintToChatAll("Unable to find drone %s", name);
	CloseHandle(dir);
	return drone;
}

// Prepare our drone to be spawned
FDrone SpawnDrone(FClient owner, const char[] name, const FVector spawnPos)
{
	//PrintToChatAll("Drone spawned");
	KeyValues kv = new KeyValues("Drone");
	char path[64];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", name);

	if (!FileExists(path))
	{
		Handle file = OpenFile(path, "w");
		CloseHandle(file);
	}
	kv.ImportFromFile(path);

	FTransform spawn;
	FObject clientRef;

	if (IsWorld(owner))
	{
		spawn.position = spawnPos;
	}
	else
	{
		spawn.rotation = owner.GetEyeAngles();
		spawn.rotation.yaw += 180.0;
		spawn.rotation.pitch = 0.0;

		FVector start, end;
		start = owner.GetEyePosition();
		end = start;
		end += start.Scale(3000.0);

		RayTrace trace = new RayTrace(start, end, MASK_PLAYERSOLID, DroneSpawnTrace, owner.Get());
		spawn.position = trace.GetNormalVector();
		spawn.position += spawn.position.Scale(60.0); // elevate slightly off surface

		clientRef = owner.GetReference();
		clientRef.GetPropVector(Prop_Data, "m_vecVelocity", spawn.velocity);
	}

	FDrone drone;

	drone = SetupDrone(kv, spawn);

	FormatEx(drone.Config, 64, name);

	switch (drone.Movetype)
	{
		case MoveType_Hover:
		{
			drone.Viewlocked = false;
			SetEntityGravity(drone.Get(), 1.0);
		}
		default:
		{
			drone.Viewlocked = true;
			SetEntityGravity(drone.Get(), 0.01);
		}
	}

	int droneId = drone.Get();

	//Find total number of weapons and seats for this drone
	char number[8];
	drone.Weapons = 0;

	if (kv.JumpToKey("weapons"))
	{
		for (int i = 1; i <= MAXWEAPONS; i++)
		{
			FormatEx(number, sizeof number, "weapon%i", i);
			if (kv.JumpToKey(number))
			{
				DroneWeapons[droneId][i] = SetupWeapon(kv, drone);
				kv.GoBack();
			}
			else
			{
				LogMessage("Found %i weapons for drone: %s", drone.Weapons, name);
				break;
			}
			drone.Weapons++;
		}
		kv.Rewind();
	}

	// Now let's setup our seats
	drone.Seats = 0;

	if (kv.JumpToKey("seats"))
	{
		for (int i = 1; i <= MAXSEATS; i++)
		{
			FormatEx(number, sizeof number, "seat%i", i);
			if (kv.JumpToKey(number))
			{
				DroneSeats[droneId][i] = SetupSeat(kv, drone);
				kv.GoBack();
			}
			else
			{
				LogMessage("Found %i seats for drone: %s", drone.Seats, name);
				break;
			}
			drone.Seats++;
		}
	}
	delete kv;

	Call_StartForward(DroneCreated);

	Call_PushArray(drone, sizeof FDrone);
	Call_PushString(drone.Plugin);
	Call_PushString(name);

	Call_Finish();

	int pilotIndex = GetPilotSeatIndex(drone);

	// Check for pilot seat
	if (!pilotIndex)
		LogError("ERROR: No pilot seat found for drone: %s! This drone will not be pilotable!", name);

	return drone;
}

bool DroneSpawnTrace(int entity, int mask, int exclude)
{
	return (entity != exclude);
}

// Physically spawn our drone in the world
FDrone SetupDrone(KeyValues config, FTransform spawn)
{
	FDrone drone;
	FObject hull;

	hull = CreateObjectDeferred("prop_physics_multiplayer");
	drone.Hull = hull;

	char modelname[PLATFORM_MAX_PATH];

	config.GetString("name", drone.Name, MAX_DRONE_LENGTH);
	config.GetString("model", modelname, sizeof modelname);
	config.GetString("destroyed_model", drone.DestroyedModel, PLATFORM_MAX_PATH);

	drone.MaxHealth = config.GetFloat("health", 100.0);
	drone.MaxSpeed = config.GetFloat("speed", 300.0);
	drone.Acceleration = config.GetFloat("acceleration", 5.0);
	drone.SpeedOverride = 0.0;
	drone.TurnRate = config.GetFloat("turn_rate", 80.0);

	char movetype[64];
	config.GetString("mopvetype", movetype, sizeof movetype);
	drone.Movetype = GetMoveType(movetype);

	config.GetString("plugin", drone.Plugin, MAX_DRONE_LENGTH, "INVALID_PLUGIN");
	drone.CameraHeight = config.GetFloat("camera_height", 30.0);

	hull.SetKeyValue("model", modelname);

	if (hull.HasProp(Prop_Data, "m_takedamage"))
		hull.SetProp(Prop_Data, "m_takedamage", 1);

	drone.Health = drone.MaxHealth;
	drone.Alive = true;

	FinishSpawn(hull, spawn);

	return drone;
}

FDroneSeat SetupSeat(KeyValues kv, FDrone drone)
{
	FDroneSeat seat;
	seat.Type = view_as<ESeatType>(kv.GetNum("type")); // 0 = pilot, 1 = gunner, 2 = passenger

	// If this is not a passenger seat, let's find the associated weapons that this seat can use
	if (seat.Type != Seat_Passenger)
	{
		char weapons[32];
		kv.GetString("weapons", weapons, sizeof weapons);

		if (StrEqual(weapons, "ALL")) // Provide access to all weapons
		{
			for (int i = 1; i <= drone.Weapons; i++)
				seat.WeaponIndex[i] = i;
		}
		else // Otherwise let's get the weapons allowed for this seat
		{
			char indices[MAXWEAPONS+1][8];
			ExplodeString(weapons, ";", indices, sizeof indices, sizeof indices[]);

			for (int i = 1; i <= MAXWEAPONS; i++)
				seat.WeaponIndex[i] = StringToInt(indices[i]);
		}

		seat.ActiveWeapon = seat.WeaponIndex[1]; // Set active weapon to first index
	}

	seat.Occupied = false;

	return seat;
}

/******************
* Drone Removal
******************/

/**
 * Kills the given drone
 */
void KillDrone(FDrone drone, FObject hull, FClient attacker, float damage, FObject weapon)
{
	FClient owner;
	owner = CastToClient(drone.GetOwner());

	if (owner.Valid())
	{
		int droneId = hull.Get();
		int seatIndex = GetPlayerSeat(owner, DroneSeats[droneId]);

		PlayerExitVehicle(drone, DroneSeats[droneId][seatIndex], owner);

		// Need to loop through all seats and eject any other players
	}

	if (weapon.Valid())
	{
		// Want to try sending a kill event for the killfeed, just not sure how to handle it yet
	}

	drone.Health = 0.0;
	drone.Alive = false;
	drone.RemoveTimer.Set(3.0);

	hull.AttachParticle("burningplayer_flyingbits", ConstructVector());

	Call_StartForward(DroneDestroyed);

	Call_PushArray(hull, sizeof FObject);
	Call_PushArray(owner, sizeof FClient);
	Call_PushArray(attacker, sizeof FClient);
	Call_PushFloat(damage);
	Call_PushString(drone.Plugin);

	Call_Finish();
}

/******************
* Helper Functions
******************/

// Returns the index of the pilot seat for the given drone
int GetPilotSeatIndex(FDrone drone)
{
	if (drone.Valid())
	{
		int droneId = drone.Get();

		for (int i = 0; i < MAXSEATS; i++)
		{
			if (DroneSeats[droneId][i].GetSeatType() == Seat_Pilot)
				return i;
		}
	}

	// No pilot seat found
	return 0;
}