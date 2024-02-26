#pragma semicolon 1
#include <customdrones>

int ExplosionSprite;

GlobalForward DroneCreated;
GlobalForward DroneEntered;
GlobalForward DroneExited;
//GlobalForward DroneRemoved;
//GlobalForward DroneDestroyed;
//GlobalForward DroneChangeWeapon;
GlobalForward DroneAttack;
GlobalForward DroneCreatedWeapon;
//GlobalForward DroneWeaponDestroyed;

#include "DroneProperties.sp"
#include "DroneNatives.sp"

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
	DroneCreated = CreateGlobalForward("CD2_OnDroneCreated", ET_Ignore, Param_Any, Param_String, Param_Any); //drone, plugin, config
	DroneCreatedWeapon = CreateGlobalForward("CD2_OnWeaponCreated", ET_Ignore, Param_Any, Param_Any, Param_String, Param_Any); //drone, weapon, weapon plugin, config
	//DroneWeaponDestroyed = CreateGlobalForward("CD2_OnWeaponDestroyed", ET_Ignore, Param_Any, Param_Any, Param_String, Param_String); //drone, weapon, weapon plugin, config
	DroneEntered = CreateGlobalForward("CD2_OnPlayerEnterDrone", ET_Ignore, Param_Any, Param_Any, Param_Any, Param_String, Param_Any); //drone, client, seat, plugin, config
	DroneExited = CreateGlobalForward("CD2_OnPlayerExitDrone", ET_Ignore, Param_Any, Param_Any, Param_Any, Param_String, Param_Any); //drone struct, client, seat, plugin, config
	//DroneRemoved = CreateGlobalForward("CD2_OnDroneRemoved", ET_Ignore, Param_Cell, Param_String); //drone, plugin
	//DroneChangeWeapon = CreateGlobalForward("CD2_OnWeaponChanged", ET_Hook, Param_Cell, Param_Cell, Param_Any, Param_Cell, Param_String); //drone, owner, weapon, slot, plugin
	//DroneDestroyed = CreateGlobalForward("CD2_OnDroneDestroyed", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_String); //drone, owner, attacker, damage, plugin
	DroneAttack = CreateGlobalForward("CD2_OnWeaponFire", ET_Hook, Param_Any, Param_Any, Param_Any, Param_CellByRef, Param_String); //drone, gunner, weapon, ammo used, weapon name
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
			//CloseHandle(dir);
			delete kv;
			continue;
		}
		if (!kv.JumpToKey("plugin"))
		{
			LogMessage("Drone config %s does not have a specified plugin, please specify a plugin for this drone!", PathName);
			//CloseHandle(dir);
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
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ResetClientView(ConstructClient(i));
		}
	}

	return Plugin_Continue;
}

// Prevent resupplying from causing issues with players piloting drones
Action OnPlayerResupply(Event event, const char[] name, bool dBroad)
{
	ADronePlayer client = view_as<ADronePlayer>(FEntityStatics.GetClient(ConstructClient(event.GetInt("userid"), true)));

	if (client && client.InDrone)
	{
		CreateTimer(0.5, DroneResupplied, client, TIMER_FLAG_NO_MAPCHANGE); // Need a longer delay than RequestFrame
	}

	return Plugin_Continue;
}

Action OnPlayerDeath(Event event, const char[] name, bool dBroad)
{
	ADronePlayer client = view_as<ADronePlayer>(FEntityStatics.GetClient(ConstructClient(event.GetInt("userid"), true)));
	//AClient attacker = FEntityStatics.GetClient(ConstructClient(event.GetInt("attacker"), true));

	if (client && client.InDrone)
	{
		ADrone drone = client.GetDrone();

		if (drone && drone.Valid())
		{
			PlayerExitVehicle(client, GetPlayerSeat(client, drone), drone);
			//KillDrone(drone, drone.GetObject(), attacker, 0.0, drone.GetObject());
			//ResetClientView(client);
		}
	}
	return Plugin_Continue;
}

Action DroneResupplied(Handle timer, ADronePlayer client)
{
	if (client.Valid())
	{
		RemoveWearables(client);
	}

	return Plugin_Stop;
}

/****************
* Client Functions
****************/

// Reset player variables
public void OnClientPostAdminCheck(int client)
{
	//
}

public void EntManager_OnClientRemoved(AClient client)
{
	ADronePlayer player = view_as<ADronePlayer>(client);

	if (player && player.InDrone)
	{
		ADrone drone = player.GetDrone();
		PlayerExitVehicle(player, GetPlayerSeat(player, drone), drone);
	}
}

void ResetClientView(FClient client)
{
	if (client.Valid())
	{
		int clientId = client.Get();

		SetClientViewEntity(clientId, clientId);
		SetEntityMoveType(clientId, MOVETYPE_WALK);
	}
}

void RemoveWearables(AClient client)
{
	if (client.Valid())
	{
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, "tf_wearable")) != -1)
		{
			if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == client.Get())
			{
				TF2_RemoveWearable(client.Get(), entity);
			}
		}

		entity = -1;
		while ((entity = FindEntityByClassname(entity, "tf_powerup_bottle")) != -1) //mvm canteens
		{
			if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == client.Get())
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
public void EntManager_OnEntityDestroyed(ABaseEntity entity)
{
	ADrone drone = view_as<ADrone>(entity);

	if (drone.IsDrone)
	{
		drone.Destroy();
	}
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
ADrone CreateDroneByName(FClient owner, const char[] name, const FVector spawnPos)
{
	char Directory[PLATFORM_MAX_PATH];
	char FileName[PLATFORM_MAX_PATH];
	FileType type;

	BuildPath(Path_SM, Directory, sizeof Directory, "configs/drones");
	Handle dir = OpenDirectory(Directory);

	ADrone drone = null;

	while (ReadDirEntry(dir, FileName, sizeof FileName, type))
	{
		if (type != FileType_File)
			continue;

		ReplaceString(FileName, sizeof FileName, ".txt", "", false);
		if (StrEqual(name, FileName))
		{
			//PrintToChatAll("Found drone %s", drone_name);
			SpawnDrone(owner, name, spawnPos, drone);
		}
		LogMessage("Found Config %s", FileName);
	}

	//PrintToChatAll("Unable to find drone %s", name);
	delete dir;
	return drone;
}

// Prepare our drone to be spawned
void SpawnDrone(FClient owner, const char[] name, const FVector spawnPos, ADrone &drone)
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

	if (IsWorld(owner))
	{
		spawn.Position = spawnPos;
	}
	else
	{
		spawn.Rotation = owner.GetEyeAngles(); // Spawn facing towards the player
		spawn.Rotation.Yaw += 180.0;
		spawn.Rotation.Pitch = 0.0;

		FVector start, end;
		start = owner.GetEyePosition();
		end = owner.GetEyeAngles().GetForwardVector();
		end.Scale(3000.0);
		end.Add(start);

		FRayTraceSingle trace = new FRayTraceSingle(start, end, MASK_PLAYERSOLID, DroneSpawnTrace, owner.Get());
		if (trace.DidHit())
		{
			FVector normal;
			end = trace.GetEndPosition();
			normal = trace.GetNormalVector();
			normal.Scale(60.0);
			normal.Add(end);

			spawn.Position = normal;
		}
		else
			spawn.Position = trace.GetEndPosition();
	}

	SetupDrone(kv, spawn, drone);

	drone.SetConfig(name);

	switch (drone.MoveType)
	{
		case MoveType_Custom:
		{
			drone.UsePlayerAngles = false;
			//SetEntityGravity(drone.Get(), 1.0);
		}
		default:
		{
			drone.UsePlayerAngles = true;
			//SetEntityGravity(drone.Get(), 0.01);
		}
	}

	//Find total number of weapons and seats for this drone
	char number[8];
	drone.Weapons = new FComponentArray();

	if (kv.JumpToKey("weapons"))
	{
		ADroneWeapon weapon = null;
		for (int i = 1; i <= MaxWeapons; i++)
		{
			FormatEx(number, sizeof number, "weapon%d", i);
			if (kv.JumpToKey(number))
			{
				weapon = SetupWeapon(kv, drone);
				drone.Weapons.Push(weapon);
				kv.GoBack();
			}
			else
			{
				LogMessage("Found %d weapons for drone: %s", drone.Weapons.Length, name);
				break;
			}
		}
		kv.Rewind();
	}

	// Now let's setup our seats
	drone.Seats = new ArrayList();

	if (kv.JumpToKey("seats"))
	{
		FDroneSeat seat = null;
		for (int i = 1; i <= MaxSeats; i++)
		{
			FormatEx(number, sizeof number, "seat%d", i);
			if (kv.JumpToKey(number))
			{
				seat = SetupSeat(kv, drone);
				drone.Seats.Push(seat);
				kv.GoBack();
			}
			else
			{
				LogMessage("Found %d seats for drone: %s", drone.Seats.Length, name);
				break;
			}
		}
	}

	char pluginName[64];
	drone.GetInternalName(pluginName, sizeof pluginName);

	kv.Rewind();
	KeyValues config = new KeyValues("Drone");
	KvCopySubkeys(kv, config);
	
	Call_StartForward(DroneCreated);

	Call_PushCell(drone);
	Call_PushString(pluginName);
	Call_PushCell(config);

	Call_Finish();

	delete kv;
	delete config;

	FDroneSeat pilotSeat = GetPilotSeat(drone);

	// Check for pilot seat
	if (!pilotSeat)
		LogMessage("WARNING: No pilot seat found for drone: %s! This drone will not be pilotable!", name);
}

bool DroneSpawnTrace(int entity, int mask, int exclude)
{
	return (entity != exclude);
}

public void OnDroneTick(APersistentObject entity)
{
	ADrone drone = view_as<ADrone>(entity);
	if (drone && drone.IsDrone && drone.Alive)
	{
		if (drone.Seats)
		{
			int seats = drone.Seats.Length;
			if (seats > 0)
			{
				for (int i = 0; i < seats; i++)
				{
					FDroneSeat seat = drone.Seats.Get(i);
					if (seat && seat.Valid())
					{
						SimulateSeat(seat, drone);
					}
				}
			}
		}
	}
}

// Physically spawn our drone in the world
void SetupDrone(KeyValues config, FTransform spawn, ADrone& drone)
{
	drone = view_as<ADrone>(FEntityStatics.CreateEntity("prop_physics_multiplayer"));

	drone.IsDrone = true;
	char droneName[MAX_DRONE_LENGTH], pluginName[64];
	FDroneComponents components;

	config.GetString("name", droneName, sizeof droneName);
	config.GetString("model", components.ModelName, sizeof FDroneComponents::ModelName);
	config.GetString("destroyed_model", components.DestroyedModel, sizeof FDroneComponents::DestroyedModel);
	config.GetString("plugin", pluginName, sizeof pluginName);

	drone.SetKeyValue("model", components.ModelName);
	FEntityStatics.FinishSpawningEntity(drone, spawn);

	FEntityStatics.EnableEntityTick(drone, OnDroneTick, 0.0);

	drone.SetDisplayName(droneName);
	drone.SetInternalName(pluginName);

	drone.MaxHealth = config.GetNum("health", 100);
	drone.MaxSpeed = config.GetFloat("speed", 300.0);
	drone.Acceleration = config.GetFloat("acceleration", 5.0);
	//drone.SpeedOverride = 0.0;
	drone.TurnRate = config.GetFloat("turn_rate", 80.0);

	char movetype[64];
	config.GetString("movetype", movetype, sizeof movetype);
	drone.MoveType = GetMoveType(movetype);

	//config.GetString("plugin", drone.Plugin, MAX_DRONE_LENGTH, "INVALID_PLUGIN");
	drone.CameraHeight = config.GetFloat("camera_height", 30.0);

	// This will eventually be changed on a per seat basis
	CreateDroneCamera(drone, drone.CameraHeight, components);

	if (drone.GetObject().HasProp(Prop_Data, "m_takedamage"))
		drone.SetProp(Prop_Data, "m_takedamage", 1);

	drone.Health = drone.MaxHealth;
	drone.Alive = true;

	drone.SetComponents(components);
}

void CreateDroneCamera(ADrone drone, float height, FDroneComponents components)
{
	FObject camera;
	camera = FGameplayStatics.CreateObjectDeferred("prop_dynamic_override");

	camera.SetKeyValue("model", "models/empty.mdl");

	FTransform spawn;
	spawn.Position = drone.GetPosition();
	spawn.Rotation = drone.GetAngles();

	spawn.Position = FMath.OffsetVector(spawn.Position, spawn.Rotation, ConstructVector(0.0, 0.0, height));

	FGameplayStatics.FinishSpawn(camera, spawn);

	camera.SetParent(drone.GetObject());

	components.Camera = camera;
}

FDroneSeat SetupSeat(KeyValues kv, ADrone drone)
{
	FDroneSeat seat = new FDroneSeat();
	seat.Type = view_as<ESeatType>(kv.GetNum("type")); // 0 = pilot, 1 = gunner, 2 = passenger

	// If this is not a passenger seat, let's find the associated weapons that this seat can use
	if (seat.Type != Seat_Passenger)
	{
		char weapons[32];
		kv.GetString("weapons", weapons, sizeof weapons);

		if (StrEqual(weapons, "ALL")) // Provide access to all weapons
		{
			seat.Weapons = drone.Weapons;
		}
		else // Otherwise let's get the weapons allowed for this seat
		{
			//char indices[MAXWEAPONS+1][8];
			//ExplodeString(weapons, ";", indices, sizeof indices, sizeof indices[]);

			//for (int i = 1; i <= MaxWeapons; i++)
			//	seat.WeaponIndex[i] = StringToInt(indices[i]);
		}

		seat.ActiveWeaponIndex = 0;
		seat.ActiveWeapon = seat.Weapons.Get(0); // Set active weapon to first index
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
void KillDrone(ADrone drone, FObject hull, FClient attacker, float damage, FObject weapon)
{
	ADronePlayer pilot = drone.Pilot;

	if (pilot && pilot.Valid())
	{
		PlayerExitVehicle(pilot, GetPilotSeat(drone), drone);

		// Need to loop through all seats and eject any other players
	}

	if (weapon.Valid())
	{
		// Want to try sending a kill event for the killfeed, just not sure how to handle it yet
	}

	drone.Health = 0;
	drone.Alive = false;
	CreateTimer(3.0, DroneExplodeTimer, drone, TIMER_FLAG_NO_MAPCHANGE);

	drone.GetObject().AttachParticle("burningplayer_flyingbits", ConstructVector());

	//Call_StartForward(DroneDestroyed);

	//Call_PushCell(drone);
	//Call_PushArray(attacker, sizeof FClient);
	//Call_PushFloat(damage);
	//Call_PushString(drone.Plugin);

	//Call_Finish();
}

/******************
* Helper Functions
******************/

Action DroneExplodeTimer(Handle timer, ADrone drone)
{
	FEntityStatics.DestroyEntity(drone);
	return Plugin_Continue;
}

void PlayerExitVehicle(ADronePlayer player, FDroneSeat seat, ADrone drone)
{
	player.InDrone = false;
	if (drone)
	{
		drone.Pilot = null;
		seat = GetPilotSeat(drone);
		seat.Occupier = null;
		seat.Occupied = false;
	}
	//seat.Occupied = false;
	//seat.Occupier = null;

	SetEntityRenderMode(player.Get(), RENDER_NORMAL);
	player.ExitingHealth = player.GetClient().GetHealth();

	CreateTimer(0.1, ResetPlayerHealth, player, TIMER_FLAG_NO_MAPCHANGE);

	ResetClientView(player.GetClient());

	Call_StartForward(DroneExited);

	Call_PushCell(drone);
	Call_PushCell(player);
	Call_PushCell(seat);

	Call_Finish();

	if (seat)
	{
	}
}

Action ResetPlayerHealth(Handle timer, ADronePlayer player)
{
	TF2_RegeneratePlayer(player.Get());

	SetEntityHealth(player.Get(), player.ExitingHealth);

	return Plugin_Stop;
}

// Returns the seat the player is in. Only returns the pilot seat as of now.
FDroneSeat GetPlayerSeat(ADronePlayer player, ADrone drone)
{
	if (drone.Seats && drone.Seats.Length)
	{
		return drone.Seats.Get(0); // Only looking for pilot seat for now
	}

	if (player)
	{
	}

	return null;
}

public Action OnClientCommandKeyValues(int clientId, KeyValues kv)
{
	FClient client;
	client = ConstructClient(clientId);

	ADronePlayer player = view_as<ADronePlayer>(FEntityStatics.GetClient(client));

	char command[64];
	kv.GetSectionName(command, sizeof command);

	ADrone drone = null;

	if (StrEqual(command, "+inspect_server", false))
	{
		if(client.Valid())
		{
			if (!player.InDrone && PlayerAimingAtDrone(player, drone))
			{
				PlayerEnterVehicle(player, drone);
				return Plugin_Handled;
			}
			else if (player.InDrone)
			{
				drone = player.GetDrone();
				PlayerExitVehicle(player, GetPilotSeat(drone), drone);
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

void PlayerEnterVehicle(ADronePlayer player, ADrone drone)
{
	player.InDrone = true;
	player.Drone = drone;
	drone.Pilot = player;
	
	// Temp
	GetPilotSeat(drone).Occupier = player;

	SetEntityRenderMode(player.Get(), RENDER_NONE);
	RemoveWearables(player);
	TF2_RemoveAllWeapons(player.Get());

	SetClientViewEntity(player.Get(), drone.GetCamera().Get());

	Call_StartForward(DroneEntered);

	Call_PushCell(drone);
	Call_PushCell(player);
	Call_PushCell(GetPilotSeat(drone));

	Call_Finish();
}

bool PlayerAimingAtDrone(AClient client, ADrone &currentDrone)
{
	FVector startPos, endPos;
	startPos = client.GetEyePosition();

	FRotator angle;
	angle = client.GetEyeAngles();

	endPos = angle.GetForwardVector();
	endPos.Scale(200.0);
	endPos.Add(startPos);

	FRayTraceSingle trace = new FRayTraceSingle(startPos, endPos, MASK_PLAYERSOLID, TraceFilter, client.Get());
	//trace.DebugTrace();
	if (trace.DidHit())
	{
		ADrone drone = view_as<ADrone>(FEntityStatics.GetEntity(trace.GetHitEntity()));
		if (drone && drone.IsDrone && drone.Seats)
		{
			currentDrone = drone;
			return true;
		}
	}

	return false;
}

bool TraceFilter(int entity, int mask, int exclude)
{
	return entity != exclude;
}
