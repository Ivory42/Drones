#pragma semicolon 1
#include <customdrones>

#undef REQUIRE_EXTENSIONS
#tryinclude <vphysics>
#define REQUIRE_EXTENSIONS

GlobalForward DroneCreated;
GlobalForward DroneEntered;
GlobalForward DroneEnteredValid;
GlobalForward DroneExitedValid;
GlobalForward DroneExited;
GlobalForward DroneRemoved;
GlobalForward DroneDestroyed;
GlobalForward DroneDamaged;
//GlobalForward DroneChangeWeapon;
GlobalForward DroneAttack;
GlobalForward DroneCreatedWeapon;
GlobalForward DroneWeaponRemoved;

GlobalForward DroneAIFindTarget;
GlobalForward DroneAITargetValid;
GlobalForward DroneAIFindPosition;
GlobalForward DroneAIStateChanged;
GlobalForward DroneAIAttack;

GlobalForward FindTossAngle;

ConVar DebugAI;

Handle SmoothedVel;

bool UsingVPhysics = false;

#include "DroneProperties.sp"
#include "DroneNatives.sp"

#include "DroneController.sp"
#include "DroneWeapons.sp"

#include "DroneAI.sp"

public Plugin MyInfo = {
	name 			= 	"[TF2] Custom Drones 2",
	author 			=	"Ivory",
	description		= 	"Customizable drones for Team Fortress 2",
	version 		= 	"2.3.6"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_drone", CmdDrone, ADMFLAG_BAN); // Admin command for spawning drones
	RegAdminCmd("sm_killdrones", CmdKillDrones, ADMFLAG_BAN);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("post_inventory_application", OnPlayerResupply);

	//Forwards
	DroneCreated = new GlobalForward("CD2_OnDroneCreated", ET_Ignore, Param_Any, Param_String, Param_Any); //drone, plugin, config
	DroneCreatedWeapon = new GlobalForward("CD2_OnWeaponCreated", ET_Ignore, Param_Any, Param_Any, Param_String, Param_Any); //drone, weapon, weapon plugin, config
	DroneWeaponRemoved = new GlobalForward("CD2_OnWeaponRemoved", ET_Ignore, Param_Any, Param_String); //weapon, weaponname
	DroneEntered = new GlobalForward("CD2_OnPlayerEnterDrone", ET_Ignore, Param_Any, Param_Any, Param_Any); //drone, client, seat, plugin, config
	DroneExitedValid = new GlobalForward("CD2_CanPlayerExitDrone", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	DroneExited = new GlobalForward("CD2_OnPlayerExitDrone", ET_Ignore, Param_Any, Param_Any, Param_Any); //drone struct, client, seat, plugin, config
	DroneRemoved = new GlobalForward("CD2_OnDroneRemoved", ET_Ignore, Param_Cell, Param_String); //drone, plugin
	//DroneChangeWeapon = CreateGlobalForward("CD2_OnWeaponChanged", ET_Hook, Param_Cell, Param_Cell, Param_Any, Param_Cell, Param_String); //drone, owner, weapon, slot, plugin
	DroneDestroyed = new GlobalForward("CD2_OnDroneDestroyed", ET_Ignore, Param_Any, Param_Array, Param_Float, Param_String); //drone, attacker, damage, name
	DroneAttack = new GlobalForward("CD2_OnWeaponFire", ET_Hook, Param_Any, Param_Any, Param_Any, Param_Any, Param_CellByRef, Param_String); //drone, gunner, weapon, ammo used, weapon name
	DroneAIEnter = new GlobalForward("CD2_OnAIControlDrone", ET_Ignore, Param_Any, Param_Any, Param_Any);

	DroneDamaged = new GlobalForward("CD2_OnDroneTakeDamage", ET_Hook, Param_Any, Param_Array, Param_Array, Param_FloatByRef, Param_CellByRef, Param_Cell);

	DroneAIFindTarget = new GlobalForward("CD2_OnAIFindTarget", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
	DroneAITargetValid = new GlobalForward("CD2_OnAIValidateTarget", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
	DroneAIFindPosition = new GlobalForward("CD2_OnAIGetMovePosition", ET_Hook, Param_Cell, Param_Cell, Param_Array);
	//DroneAIThink = CreateGlobalForward("CD2_OnAITick", ET_Ignore, Param_Cell, Param_Cell);
	DroneAIAttack = new GlobalForward("CD2_OnAIAttack", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	DroneAIStateChanged = new GlobalForward("CD2_OnAIStateChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	FindTossAngle = new GlobalForward("CD2_OnAIFindTossAngle", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef);
	DroneEnteredValid = new GlobalForward("CD2_CanPlayerEnterDrone", ET_Hook, Param_Cell, Param_Cell, Param_Cell);

	DebugAI = CreateConVar("CD2_DebugAI", "0", "Enables debugging of AI movement and pathing", _, true, 0.0, true, 1.0);

	GameData data = LoadGameConfigFile("smoothedvelocity");
	if (data)
	{
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(data, SDKConf_Virtual, "GetSmoothedVelocity");
		PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
		SmoothedVel = EndPrepSDKCall();
	}
}

Action CmdKillDrones(int clientId, int args)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_physics_multiplayer")) != -1)
	{
		ADrone drone = view_as<ADrone>(FEntityStatics.GetEntityFromIndex(entity));
		if (drone && drone.IsDrone)
		{
			if (GetPilotSeat(drone).AIControlled)
			{
				FDroneAI controller = GetPilotSeat(drone).AIOccupier;
				if (controller.Owner.Get() == clientId)
				{
					KillDrone(drone, ConstructObject(clientId), ConstructObject(clientId), 0.0, ConstructWeapon(ConstructClient(clientId).GetSlot(TFWeaponSlot_Primary)));
				}
			}
		}
	}

	return Plugin_Handled;
}

public void OnMapStart()
{
	if (GetFeatureStatus(FeatureType_Native, "Phys_SetVelocity") == FeatureStatus_Available)
	{
		UsingVPhysics = true;
	}
	else
	{
		UsingVPhysics = false;
	}
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
			ADronePlayer client = view_as<ADronePlayer>(FEntityStatics.GetClient(ConstructClient(i)));
			if (client)
			{
				client.InDrone = false;
				client.Drone = null;
			}
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
			PlayerExitVehicle(client, GetPlayerSeat(client, drone), drone, false);
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
		while ((entity = FindEntityByClassname(entity, "tf_wearable_campaign_item")) != -1) //contracker
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

/*
public void OnEntityDestroyed(int entity)
{
	
}
*/

ADrone CastToDrone(ABaseEntity entity)
{
	if (!entity)
	{
		return null;
	}

	ADrone drone = null;
	if (entity.GetObjectProp("Entity_IsDrone"))
	{
		//PrintToChatAll("Drone cast success (%d): Value = %d", entity.Get(), view_as<int>(entity.GetObjectProp("Entity_IsDrone")));
		drone = view_as<ADrone>(entity);
	}

	return drone;
}

ADroneWeapon CastToDroneWeapon(ABaseEntity entity)
{
	if (!entity)
	{
		return null;
	}

	ADroneWeapon weapon = null;
	if (entity.GetObjectProp("Entity_IsDroneWeapon"))
	{
		//PrintToChatAll("Weapon cast success (%d): Value = %d", entity.Get(), view_as<int>(entity.GetObjectProp("Entity_IsDroneWeapon")));
		weapon = view_as<ADroneWeapon>(entity);
	}

	return weapon;
}

// When a new entity is created, lets make sure it is not initialized as a drone
public void EntManager_OnEntityDestroyed(ABaseEntity entity)
{
	ADrone drone = CastToDrone(entity);
	if (drone && drone.IsDrone)
	{
		StopEngine(drone);

		//drone.Clear();
		char name[64];
		drone.GetInternalName(name, sizeof name);
		//PrintToChatAll("Drone deleted: %d\nName: %s\nEntity ID: %d", drone.Get(), name, entity);

		//Clear the seats
		int seats = drone.Seats.Length;
		for (int i = 0; i < seats; i++)
		{
			FDroneSeat seat = drone.Seats.Get(i);
			if (seat && seat.Occupier)
			{
				ADronePlayer client = seat.Occupier;
				PlayerExitVehicle(client, seat, drone, false);
			}
		}

		Call_StartForward(DroneRemoved);

		Call_PushCell(drone);
		Call_PushString(name);

		Call_Finish();
		drone.Destroy();
	}

	ADroneWeapon weapon = CastToDroneWeapon(entity);
	if (weapon && weapon.IsDroneWeapon)
	{
		char name[64];
		weapon.GetInternalName(name, sizeof name);

		FObject reticle;
		reticle = weapon.GetObjectPropEnt("DroneWeapon.LockOnReticle");
		if (reticle.Valid())
		{
			ABaseEntity ret = FEntityStatics.GetEntity(reticle);
			ret.SetObjectProp("DroneSprite.Reticle.Weapon", 0);
			SDKUnhook(ret.Get(), SDKHook_SetTransmit, OnReticleReplicate);
			reticle.Kill();
		}

		//PrintToChatAll("Weapon deleted: %d\nName: %s\nEntity ID: %d", weapon.Get(), name, entity);
		Call_StartForward(DroneWeaponRemoved);

		Call_PushCell(weapon);
		Call_PushString(name);

		Call_Finish();
		weapon.Destroy();
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
			ReplaceString(fileName, sizeof fileName, ".cfg", "", false);
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
			
			FTransform spawn;
			CreateDroneByName(ConstructClient(client), info, spawn);
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
ADrone CreateDroneByName(FClient owner, const char[] name, const FTransform spawnPos)
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

		ReplaceString(FileName, sizeof FileName, ".cfg", "", false);
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
void SpawnDrone(FClient owner, const char[] name, const FTransform spawnPos, ADrone &drone)
{
	//PrintToChatAll("Drone spawned");
	KeyValues kv = new KeyValues("Drone");
	char path[64];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.cfg", name);

	if (!FileExists(path))
	{
		Handle file = OpenFile(path, "w");
		CloseHandle(file);
	}
	kv.ImportFromFile(path);

	FTransform spawn;

	if (IsWorld(owner))
	{
		spawn = spawnPos;
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
		case MoveType_None:
		{
			drone.CanMove = false;
			drone.UsePlayerAngles = false;
			SetEntityMoveType(drone.Get(), MOVETYPE_NONE);
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

void OnDroneTick(APersistentObject entity)
{
	ADrone drone = view_as<ADrone>(entity);
	if (drone && drone.IsDrone && drone.Alive)
	{
		CheckDroneInMap(drone);
		if (drone.GetComponents().Attachments)
		{
			FComponentArray attachments = drone.GetComponents().Attachments;
			for (int i = 0; i < attachments.Length; i++)
			{
				AComponent attachment = attachments.Get(i);
				if (attachment)
				{
					DroneAttachmentTick(attachment, drone);
				}
			}
		}
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
						//PrintToConsoleAll("Seat = %x", seat);
						SimulateSeat(seat, drone);
					}
				}
			}
		}
	}
}

void DroneAttachmentTick(AComponent attachment, ADrone drone)
{
	char name[64];
	attachment.GetObjectPropString("DroneComponent.CompType", name, sizeof name);
	if (StrEqual(name, "prop_rotors"))
	{
		float maxspeed = attachment.GetObjectPropFloat("DroneProp.RotorSpinSpeed");
		float factor = attachment.GetObjectPropFloat("DroneProp.RotorSpinSpeedFactor");
		bool shouldRotate = false;
		float increment = 0.008;
		if (drone.EngineOn)
		{
			shouldRotate = true;
			factor = FMath.ClampFloat(factor + increment, 0.0, 1.0);
		}
		else if (factor > 0.01)
		{
			shouldRotate = true;
			factor = FMath.ClampFloat(factor - increment, 0.0, 1.0);
		}

		attachment.SetObjectPropFloat("DroneProp.RotorSpinSpeedFactor", factor);

		if (shouldRotate)
		{
			float speed = maxspeed * factor;

			FRotator rotation, target;
			rotation = attachment.GetPropRotator(Prop_Data, "m_angRotation");
			target = rotation;
			target.Yaw += 180.0;

			rotation = FMath.InterpRotatorTo(rotation, target, GetGameFrameTime(), speed);
			NormalizeAngles(rotation);
			rotation.Roll = 0.0;
			rotation.Pitch = 0.0;

			attachment.GetObject().SetAngles(rotation);
		}
	}
	else if (StrEqual(name, "prop_door"))
	{
		int type = attachment.GetObjectProp("DroneProp.Door.Functionality");
		float speed = attachment.GetObjectPropFloat("DroneProp.Door.Speed");
		bool enabled = false;
		switch (type)
		{
			case 1: // Rotator
			{
				FRotator target;
				FRotator current;
				if (attachment.GetObjectProp("DroneProp.Door.Opening"))
				{
					current = attachment.GetPropRotator(Prop_Data, "m_angRotation");
					enabled = true;
					target = attachment.GetObjectPropRotator("DroneProp.Door.RotationTarget");

					if (FMath.GetAngle(current, target) < 0.00)
					{
						attachment.SetObjectProp("DroneProp.Door.Opening", false);
						enabled = false;
					}
				}
				else if (attachment.GetObjectProp("DroneProp.Door.Closing"))
				{
					current = attachment.GetPropRotator(Prop_Data, "m_angRotation");
					enabled = true;
					target = ConstructRotator(); // Rotate towards relative zero

					if (FMath.GetAngle(current, target) < 0.00)
					{
						attachment.SetObjectProp("DroneProp.Door.Closing", false);
						enabled = false;
					}
				}

				if (enabled)
				{
					current = FMath.InterpRotatorTo(current, target, GetGameFrameTime(), speed);
					TeleportEntity(attachment.Get(), NULL_VECTOR, current.ToFloat());
				}
			}
			case 2: // Vector
			{
				FVector target;
				FVector current;
				if (attachment.GetObjectProp("DroneProp.Door.Opening"))
				{
					current = attachment.GetRelativePosition();
					enabled = true;
					target = attachment.GetObjectPropVector("DroneProp.Door.VectorTarget");

					if (current.DistanceTo(target) < 0.00)
					{
						attachment.SetObjectProp("DroneProp.Door.Opening", false);
						enabled = false;
					}
				}
				else if (attachment.GetObjectProp("DroneProp.Door.Closing"))
				{
					current = attachment.GetRelativePosition();
					enabled = true;
					target = ConstructVector(); // Move towards relative zero

					if (current.DistanceTo(target) < 0.00)
					{
						attachment.SetObjectProp("DroneProp.Door.Closing", false);
						enabled = false;
					}
				}

				if (enabled)
				{
					current = FMath.InterpVectorConstant(current, target, GetGameFrameTime(), speed);
					TeleportEntity(attachment.Get(), current.ToFloat());
				}
			}
		}
	}
	else if (StrEqual(name, "prop_suspension"))
	{
		float distance, height, offset, maxrot;
		distance = attachment.GetObjectPropFloat("DroneProp.Suspension.Distance");
		height = attachment.GetObjectPropFloat("DroneProp.Suspension.Height");
		offset = attachment.GetObjectPropFloat("DroneProp.Suspension.VerticalOffset");
		maxrot = attachment.GetObjectPropFloat("DroneProp.Suspension.MaxRotation");

		FVector origin, start, end;
		origin = attachment.GetPosition();
		start = FMath.OffsetVector(origin, attachment.GetAngles(), ConstructVector(distance));
		end = start;
		end.Z = origin.Z - height;
		start.Z += offset;

		FVector mins, maxs;
		mins = ConstructVector(-10.0, -10.0, 0.0);
		maxs = ConstructVector(10.0, 10.0, 25.0);
		FHullTrace trace = new FHullTrace(start, end, mins, maxs, MASK_SHOT, DroneMovementTrace, drone);
		//trace.DebugTrace(0.1);
		end = trace.GetEndPosition();
		delete trace;

		FVector delta;
		delta = Vector_MakeFromPoints(origin, end);
		FRotator angle;
		angle = Vector_GetAngles(delta);

		float pitch = FMath.ClampFloat(angle.Pitch, -maxrot, maxrot);
		FRotator newRot;
		newRot = ConstructRotator(pitch);//FMath.InterpRotatorTo(attachment.GetAngles(), ConstructRotator(pitch), GetGameFrameTime(), 700.0);
		NormalizeAngles(newRot);
		newRot.Yaw = 0.0;
		newRot.Roll = 0.0;
		int interp = attachment.GetProp(Prop_Send, "m_ubInterpolationFrame");
		TeleportEntity(attachment.Get(), NULL_VECTOR, newRot.ToFloat());
		attachment.SetProp(Prop_Send, "m_ubInterpolationFrame", interp);
	}
}

void CheckDroneInMap(ADrone drone)
{
	if (TR_PointOutsideWorld(drone.GetPosition().ToFloat()))
	{
		CreateTimer(5.0, DroneTerminateTimer, drone, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action DroneTerminateTimer(Handle timer, ADrone drone)
{
	// check again
	if (TR_PointOutsideWorld(drone.GetPosition().ToFloat()))
	{
		// destroy drone and kill any players onboard
		if (drone.Seats)
		{
			int seats = drone.Seats.Length;
			if (seats > 0)
			{
				for (int i = 0; i < seats; i++)
				{
					FDroneSeat seat = drone.Seats.Get(i);
					if (seat && seat.Valid() && seat.Occupier)
					{
						SDKHooks_TakeDamage(seat.Occupier.Get(), 0, 0, 9999.0);
					}
				}
			}
		}

		FWeapon weapon; // empty
		KillDrone(drone, GetWorld(), GetWorld(), 9999.0, weapon);
	}

	return Plugin_Stop;
}

// Physically spawn our drone in the world
void SetupDrone(KeyValues config, FTransform spawn, ADrone& drone)
{
	drone = view_as<ADrone>(CreateComponent("prop_physics_multiplayer"));

	drone.IsDrone = true;
	char droneName[MAX_DRONE_LENGTH], pluginName[64];
	FDroneComponents components;

	float bounds = config.GetFloat("ai_bounds");
	components.MinBounds = ConstructVector(bounds * -1.0, bounds * -1.0, bounds * -1.0);
	components.MaxBounds = ConstructVector(bounds, bounds, bounds);

	FVector boundsOffset;
	boundsOffset = Vector_GetFromKV(config, "bounds_offset");
	components.BoundsOffset = boundsOffset;

	config.GetString("name", droneName, sizeof droneName);
	config.GetString("model", components.ModelName, sizeof FDroneComponents::ModelName);
	config.GetString("destroyed_model", components.DestroyedModel, sizeof FDroneComponents::DestroyedModel);
	config.GetString("plugin", pluginName, sizeof pluginName);
	
	char enginesound[64];
	config.GetString("engine_sound", enginesound, sizeof enginesound);
	if (strlen(enginesound) > 3)
	{
		PrecacheSound(enginesound);
		drone.SetObjectPropString("Drone.EngineSound", enginesound);
	}

	config.GetString("explode_particle", components.ExplodeParticle, sizeof FDroneComponents::ExplodeParticle, "hightower_explosion");
	config.GetString("explode_sound", components.ExplodeSound, sizeof FDroneComponents::ExplodeSound, "weapons/explode1.wav");

	char dronetag[64];
	FormatEx(dronetag, sizeof dronetag, "DroneEnt%d", drone.Get());
	drone.SetKeyValue("targetname", dronetag);

	drone.SetKeyValue("model", components.ModelName);
	FEntityStatics.FinishSpawningEntity(drone, spawn);

	if (GetFeatureStatus(FeatureType_Native, "Phys_SetMass") == FeatureStatus_Available)
	{
		//PrintToChatAll("Set mass");
		Phys_SetMass(drone.Get(), config.GetFloat("mass", 4000.0));
	}

	FEntityStatics.EnableEntityTick(drone, OnDroneTick, 0.0);

	drone.SetDisplayName(droneName);
	drone.SetInternalName(pluginName);

	drone.MaxHealth = config.GetNum("health", 100);
	drone.MaxSpeed = config.GetFloat("speed", 300.0);
	drone.MinSpeed = config.GetFloat("minspeed", 200.0);
	drone.Acceleration = config.GetFloat("acceleration", 1.25);
	drone.Deceleration = config.GetFloat("deceleration", 8.0);
	drone.NoHud = view_as<bool>(config.GetNum("nohud", false));
	//drone.SpeedOverride = 0.0;
	drone.TurnRate = config.GetFloat("turn_rate", 1.0);
	drone.MaxPitch = config.GetFloat("max_pitch", 25.0);
	drone.MaxRoll = config.GetFloat("max_roll", 25.0);

	char movetype[64];
	config.GetString("movetype", movetype, sizeof movetype);
	drone.MoveType = GetMoveType(movetype);

	switch (drone.MoveType)
	{
		case MoveType_Helo:
		{
			drone.HeloChangePitch = view_as<bool>(config.GetNum("helo_changepitch", 0));
			drone.HeloChangeRoll = view_as<bool>(config.GetNum("helo_changeroll", 1));
			drone.HeloVerticalAxis = view_as<bool>(config.GetNum("helo_uservertical", 0));
			drone.FunctionType = LockOn_Air;
		}
		case MoveType_Hover:
		{
			SetupThrusters(drone, config, components, dronetag);
			drone.HoverMaxHeight = config.GetFloat("hover_maxhoverheight", 70.0);
			drone.HoverIntensity = config.GetFloat("hover_hoverforce", 200.0);
			drone.SetObjectPropFloat("Drone.VerticalIKOffset", config.GetFloat("hover_verticalik"));
			drone.HoverForwardIK = config.GetFloat("hover_forwardik");
			drone.HoverBackwardIK = config.GetFloat("hover_backwardik");
			drone.HoverRightIK = config.GetFloat("hover_rightik");
			drone.HoverLeftIK = config.GetFloat("hover_leftik");
			drone.HoverMaxIncline = config.GetFloat("hover_maxincline");
			drone.FunctionType = LockOn_Ground;
		}
		case MoveType_Physics:
		{
			SetupPhysicsTorque(drone, config, components, dronetag);
			drone.FunctionType = LockOn_Ground;
		}
		case MoveType_Fly: drone.FunctionType = LockOn_Air;
		default: drone.FunctionType = LockOn_Ground;
	}

	// Override functionality type
	char functiontype[64];
	config.GetString("function_type", functiontype, sizeof functiontype, "");
	if (strlen(functiontype) > 1)
	{
		drone.FunctionType = GetWeaponLockOnType(functiontype);
	}
	if (drone.FunctionType == LockOn_None) // Default to ground if we somehow get none
	{
		drone.FunctionType = LockOn_Ground;
	}

	CreateAttachments(drone, config, components);
	
	//config.GetString("plugin", drone.Plugin, MAX_DRONE_LENGTH, "INVALID_PLUGIN");
	drone.CameraHeight = config.GetFloat("camera_height", 30.0);
	drone.CameraDistance = config.GetFloat("camera_distance", 0.0) * -1.0;

	drone.CanDealSelfDamage = view_as<bool>(config.GetNum("self_damage_enabled", 1));

	FVector cameraOffset;
	cameraOffset = ConstructVector(drone.CameraDistance, 0.0, drone.CameraHeight);

	// This will eventually be changed on a per seat basis
	CreateDroneCamera(drone, cameraOffset, components, ConstructRotator());

	if (drone.GetObject().HasProp(Prop_Data, "m_takedamage"))
	{
		drone.SetProp(Prop_Data, "m_takedamage", 1);
		SDKHook(drone.Get(), SDKHook_OnTakeDamage, OnDroneDamaged);
		SDKHook(drone.Get(), SDKHook_Touch, OnDroneOverlap);
	}

	// Create teleporter for sentries to target
	//CreateDroneTeleporter(drone);

	drone.Health = drone.MaxHealth;
	drone.Alive = true;

	drone.SetComponents(components);
}

void SetupThrusters(ADrone drone, KeyValues config, FDroneComponents components, const char[] dronetag)
{
	FObject motor, side;
	motor = FGameplayStatics.CreateObjectDeferred("phys_thruster");

	//float speed = drone.MaxSpeed;
	float force = config.GetFloat("engine_force", 5000.0);
	//PrintToChatAll("Spawning physics drone with speed: %.1f and force: %.1f", speed, force);

	// Ignore Position (32) | Apply force (2) | Orient Locally (8)
	int flags = 32 + 2 + 8;
	
	motor.SetKeyValueInt("Flags", flags);
	motor.SetKeyValueVector("origin", drone.GetPosition());
	motor.SetKeyValue("attach1", dronetag);
	motor.SetKeyValueFloat("force", force);
	//torque.SetKeyValueFloat("speed", speed);

	FTransform spawn;
	spawn = ConstructTransform(drone.GetPosition(), drone.GetAngles());
	FGameplayStatics.FinishSpawn(motor, spawn);
	motor.SetParent(drone.GetObject());

	components.Motor = motor;

	// Now side movement
	side = FGameplayStatics.CreateObjectDeferred("phys_thruster");
	
	side.SetKeyValueInt("Flags", flags);
	side.SetKeyValueVector("origin", drone.GetPosition());
	side.SetKeyValue("attach1", dronetag);
	side.SetKeyValueFloat("force", force);

	spawn.Rotation.Yaw += 90.0;
	FGameplayStatics.FinishSpawn(side, spawn);
	side.SetParent(drone.GetObject());

	components.SideMotor = side;
}

void SetupPhysicsTorque(ADrone drone, KeyValues config, FDroneComponents components, const char[] dronetag)
{
	FObject torque;
	torque = FGameplayStatics.CreateObjectDeferred("phys_torque");

	float speed = drone.MaxSpeed;
	float force = config.GetFloat("engine_force", 5000.0);
	//PrintToChatAll("Spawning physics drone with speed: %.1f and force: %.1f", speed, force);
	
	torque.SetKeyValueVector("origin", drone.GetPosition());
	torque.SetKeyValue("attach1", dronetag);
	torque.SetKeyValueFloat("force", force);
	torque.SetKeyValueFloat("speed", speed);

	FGameplayStatics.FinishSpawn(torque, ConstructTransform(drone.GetPosition(), ConstructRotator()));
	torque.SetParent(drone.GetObject());

	components.Motor = torque;
}

void CreateAttachments(ADrone drone, KeyValues config, FDroneComponents components)
{
	if (config.JumpToKey("attachments"))
	{
		components.Attachments = new FComponentArray();

		char component[64], type[64], attachpos[64], parentname[64];

		config.GotoFirstSubKey();
		do
		{
			config.GetSectionName(component, sizeof component);
			//PrintToChatAll("Component = %s", component);

			config.GetString("type", type, sizeof type);
			config.GetString("attachment", attachpos, sizeof attachpos);
			config.GetString("parent", parentname, sizeof parentname);
			AComponent attachment = null;
			if (StrEqual(type, "drone_light"))
			{
				attachment = CreateDroneLight(drone, config);
			}
			else if (StrEqual(type, "drone_trail"))
			{
				attachment = CreateDroneTrail(drone, config);
			}
			else if (StrEqual(type, "drone_damage_smoke"))
			{
				attachment = CreateDroneSmoke(drone, config);
			}
			else if (StrEqual(type, "drone_damage_particle"))
			{
				attachment = CreateDroneParticle(drone, config);
			}
			else if (StrEqual(type, "drone_particle"))
			{
				attachment = CreateDroneParticle(drone, config, false);
			}
			else if (StrEqual(type, "drone_damage_sparks"))
			{
				attachment = CreateDroneSparks(drone, config);
			}
			else if (StrContains(type, "prop") == 0) // starts with prop, these will all be prop_dynamic
			{
				attachment = CreatePropAttachment(drone, config, type);
			}
			else if (StrEqual(type, "drone_critical_point"))
			{
				
			}

			if (attachment)
			{
				ABaseEntity parent = drone;
				if (strlen(parentname) > 0)
				{
					AComponent attachParent = GetAttachmentByName(components.Attachments, parentname);
					if (attachParent)
					{
						parent = attachParent;
						attachment.SetObjectPropEnt("DroneComponent.ParentEntity", parent.GetObject());
					}
				}
				attachment.GetObject().SetParent(parent.GetObject());
				SetVariantString(attachpos);
				attachment.GetObject().Input("SetParentAttachment");
				FVector offset;
				FRotator rotation;
				offset = Vector_GetFromKV(config, "offset");
				rotation = Rotator_GetFromKV(config, "rotation");
				TeleportEntity(attachment.Get(), offset.ToFloat(), rotation.ToFloat());
				components.Attachments.Push(attachment);
				attachment.GetObject().SetTargetName(component);
				attachment.SetObjectPropString("DroneComponent.CompType", type);
			}
		}
		while (config.GotoNextKey());

		config.Rewind();
	}
}

AComponent CreateDroneSmoke(ADrone drone, KeyValues config, bool damage = true)
{
	AComponent component = CreateComponent("env_smokestack");
	if (component)
	{
		char texture[64];
		config.GetString("material", texture, sizeof texture);
		component.SetKeyValue("SmokeMaterial", texture);

		FEntityStatics.SetValidationProperty(component, "DroneComponent.SmokeComponent");

		int state = 0;
		if (!config.GetNum("hidden"))
		{
			state = 1;
		}
		component.SetKeyValueInt("InitialState", state);

		component.SetKeyValueInt("BaseSpread", config.GetNum("spread"));
		component.SetKeyValueInt("SpreadSpeed", config.GetNum("spread_speed"));
		component.SetKeyValueInt("Speed", config.GetNum("speed"));
		component.SetKeyValueInt("StartSize", config.GetNum("start_size"));
		component.SetKeyValueInt("EndSize", config.GetNum("end_size"));
		component.SetKeyValueInt("Rate", config.GetNum("rate"));
		component.SetKeyValueInt("JetLength", config.GetNum("length"));
		component.SetKeyValueInt("Twist", config.GetNum("twist"));
		component.SetKeyValueInt("Roll", config.GetNum("roll"));
		component.SetKeyValueInt("renderamt", config.GetNum("render"));

		char color[64];
		config.GetString("color", color, sizeof color, "255 255 255");
		component.SetKeyValue("rendercolor", color);

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		FEntityStatics.FinishSpawningEntity(component, spawn);

		component.Drone = drone;

		if (damage)
		{
			component.SetObjectPropFloat("DamageComponent.HealthThreshold", config.GetFloat("health_threshold"));
			component.SetObjectProp("DamageComponent.IsActive", state);
			FEntityStatics.SetValidationProperty(component, "DroneComponent.DamageComponent");
		}
	}

	return component;
}

AComponent CreateDroneParticle(ADrone drone, KeyValues config, bool damage = true)
{
	AComponent component = CreateComponent("info_particle_system");
	if (component)
	{
		char particle[64];
		config.GetString("particle", particle, sizeof particle);
		component.SetKeyValue("effect_name", particle);

		FEntityStatics.SetValidationProperty(component, "DroneComponent.ParticleComponent");

		int state = 0;
		if (!config.GetNum("hidden"))
		{
			state = 1;
		}
		component.SetKeyValueInt("start_active", state);

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		FEntityStatics.FinishSpawningEntity(component, spawn);

		component.Drone = drone;

		if (damage)
		{
			component.SetObjectPropFloat("DamageComponent.HealthThreshold", config.GetFloat("health_threshold"));
			component.SetObjectProp("DamageComponent.IsActive", state);
			FEntityStatics.SetValidationProperty(component, "DroneComponent.DamageComponent");
		}
	}

	return component;
}

AComponent CreateDroneSparks(ADrone drone, KeyValues config)
{
	AComponent component = CreateComponent("env_spark");
	if (component)
	{
		FEntityStatics.SetValidationProperty(component, "DroneComponent.SparksComponent");

		bool hidden = view_as<bool>(config.GetNum("hidden"));

		int flags = 0;
		if (!hidden)
		{
			flags += 64;
		}

		// Set glow (128) and directional (512)
		flags += (128 + 512);
		component.SetKeyValueInt("Flags", flags);

		char delay[32];
		config.GetString("delay", delay, sizeof delay);
		component.SetKeyValue("MaxDelay", delay);
		component.SetKeyValueInt("Magnitude", config.GetNum("magnitude"));
		component.SetKeyValueInt("TrailLength", config.GetNum("length"));

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		FEntityStatics.FinishSpawningEntity(component, spawn);

		component.Drone = drone;

		component.SetObjectPropFloat("DamageComponent.HealthThreshold", config.GetFloat("health_threshold"));
		component.SetObjectProp("DamageComponent.IsActive", !hidden);
		FEntityStatics.SetValidationProperty(component, "DroneComponent.DamageComponent");
	}

	return component;
}

AComponent CreateDroneLight(ADrone drone, KeyValues config)
{
	AComponent component = CreateComponent("env_sprite");
	if (component)
	{

		FEntityStatics.SetValidationProperty(component, "DroneComponent.LightComponent");
		//PrintToChatAll("Creating light");
		char texture[64];
		config.GetString("material", texture, sizeof texture);
		PrecacheModel(texture);
		component.SetKeyValue("model", texture);
		component.GetObject().SetModel(texture);

		component.SetKeyValueFloat("scale", config.GetFloat("scale"));
		component.SetKeyValueInt("rendermode", 9); // Glow in world space
		component.SetKeyValueInt("renderamt", config.GetNum("brightness"));

		char color[64];
		config.GetString("color", color, sizeof color, "255 255 255");
		if (StrEqual(color, "team"))
		{
			FormatEx(color, sizeof color, "255 255 255");
			component.SetObjectProp("DroneComponent.UseTeamColors", true);
		}
		component.SetKeyValue("rendercolor", color);

		//PrintToChatAll("{\n   Material = %s\n   scale = %.1f\n   renderamt = %d\n   color = %s\n   attach = %s\n}", texture, config.GetFloat("size"), config.GetNum("brightness"), color, attachpos);

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		FEntityStatics.FinishSpawningEntity(component, spawn);

		component.Drone = drone;

		bool hidden = view_as<bool>(config.GetNum("hidden", 0));
		if (hidden)
		{
			component.SetObjectProp("DroneComponent.ActivateUponEntry", view_as<bool>(config.GetNum("visibility_by_status")));
			component.GetObject().Input("HideSprite");
		}
	}

	return component;
}

AComponent CreateDroneTrail(ADrone drone, KeyValues config)
{
	AComponent component = CreateComponent("env_spritetrail");
	if (component)
	{
		FEntityStatics.SetValidationProperty(component, "DroneComponent.TrailComponent");

		char texture[64], life[32], start[32], end[32];
		config.GetString("material", texture, sizeof texture);
		config.GetString("lifetime", life, sizeof life);
		config.GetString("start_width", start, sizeof start);
		config.GetString("end_width", end, sizeof end);
		PrecacheModel(texture);
		component.SetKeyValue("spritename", texture);
		component.SetKeyValueInt("renderamt", config.GetNum("brightness"));
		component.SetKeyValueInt("rendermode", config.GetNum("rendermode", 1));
		component.SetKeyValue("lifetime", life);
		component.SetKeyValue("startwidth", start);
		component.SetKeyValue("endwidth", end);

		char color[64];
		config.GetString("color", color, sizeof color, "255 255 255");
		if (StrEqual(color, "team"))
		{
			FormatEx(color, sizeof color, "255 255 255");
			component.SetObjectProp("DroneComponent.UseTeamColors", true);
		}
		component.SetKeyValue("rendercolor", color);

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		FEntityStatics.FinishSpawningEntity(component, spawn);

		component.Drone = drone;

		bool hidden = view_as<bool>(config.GetNum("hidden", 0));
		if (hidden)
		{
			component.SetObjectProp("DroneComponent.ActivateUponEntry", view_as<bool>(config.GetNum("visibility_by_status")));
			component.GetObject().Input("HideSprite");
		}
		else
		{
			component.GetObject().Input("ShowSprite");
		}
	}

	return component;
}

AComponent CreatePropAttachment(ADrone drone, KeyValues config, const char[] type)
{
	AComponent component = CreateComponent("prop_dynamic_override");
	if (component)
	{
		FEntityStatics.SetValidationProperty(component, "DroneComponent.DronePropAttachment");
		char model[64];
		config.GetString("model", model, sizeof model);

		if (strlen(model) > 3)
		{
			PrecacheModel(model);
			component.SetModel(model);
		}

		float maxpitch = config.GetFloat("pitch_with_movement", 0.0);
		if (maxpitch > 0.0)
		{
			component.SetObjectProp("DroneProp.PitchWithMovement", true);
			component.SetObjectPropFloat("DroneProp.MaxPitch", maxpitch);
			component.SetObjectProp("DroneProp.PitchTurnInverted", config.GetNum("invert_turn_pitch", 0));
			component.SetObjectPropFloat("DroneProp.TurnSpeed", config.GetFloat("rot_speed", 350.0));
		}

		float maxroll = config.GetFloat("roll_with_movement", 0.0);
		if (maxroll > 0.0)
		{
			component.SetObjectProp("DroneProp.RollWithMovement", true);
			component.SetObjectPropFloat("DroneProp.MaxRoll", maxroll);
			component.SetObjectPropFloat("DroneProp.TurnSpeed", config.GetFloat("rot_speed", 350.0));
		}

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		FEntityStatics.FinishSpawningEntity(component, spawn);

		component.Drone = drone;

		if (StrEqual(type, "prop_rotors"))
		{
			float spin = config.GetFloat("rotation_speed", 100.0);
			component.SetObjectPropFloat("DroneProp.RotorSpinSpeed", spin);
		}

		if (StrEqual(type, "prop_door"))
		{
			char functionality[32];
			config.GetString("function", functionality, sizeof functionality);
			component.SetObjectProp("DroneProp.Door.Opening", true);
			component.SetObjectProp("DroneProp.Door.Closing", false);
			component.SetObjectPropFloat("DroneProp.Door.Speed", config.GetFloat("door_speed", 100.0));
			if (StrEqual(functionality, "rotator"))
			{
				component.SetObjectProp("DroneProp.Door.Functionality", 1);
				FRotator rotator;
				rotator = Rotator_GetFromKV(config, "rotation_target");
				component.SetObjectPropRotator("DroneProp.Door.RotationTarget", rotator);
			}
			else if (StrEqual(functionality, "vector"))
			{
				component.SetObjectProp("DroneProp.Door.Functionality", 2);
				FVector vector;
				vector = Vector_GetFromKV(config, "vector_target");
				component.SetObjectPropVector("DroneProp.Door.VectorTarget", vector);
			}
		}

		if (StrEqual(type, "prop_suspension"))
		{
			float distance, height, offset, maxrot;
			distance = config.GetFloat("ik_distance");
			height = config.GetFloat("ik_height");
			offset = config.GetFloat("ik_offset");
			maxrot = config.GetFloat("ik_max", 35.0);

			component.SetObjectPropFloat("DroneProp.Suspension.Distance", distance);
			component.SetObjectPropFloat("DroneProp.Suspension.Height", height);
			component.SetObjectPropFloat("DroneProp.Suspension.VerticalOffset", offset);
			component.SetObjectPropFloat("DroneProp.Suspension.MaxRotation", maxrot);
		}

		GetPropComponentValues(component, config);
	}

	return component;
}

void GetPropComponentValues(AComponent component, KeyValues config)
{
	component.SetObjectProp("DroneProp.IsDestructible", config.GetNum("destructible"));
	component.MaxHealth = config.GetNum("health");
	component.Health = component.MaxHealth;

	component.SetObjectProp("DroneProp.DestroyOnDeath", config.GetNum("destroy_on_death"));
	component.SetObjectProp("DroneProp.TakeDamage", config.GetNum("take_damage"));
	component.Modifier = config.GetFloat("damage_mod", 1.0);
}

AComponent GetAttachmentByName(FComponentArray attachments, const char[] name)
{
	for (int i = 0; i < attachments.Length; i++)
	{
		AComponent component = attachments.Get(i);
		char compName[64];
		component.GetObject().GetTargetName(compName, sizeof compName);

		if (StrEqual(name, compName))
		{
			return component;
		}
	}

	return null;
}

/*
void CreateDroneTeleporter(ADrone drone)
{
	FObject teleporter;
	teleporter = FGameplayStatics.CreateObjectDeferred("obj_teleporter");

	FTransform spawn;
	spawn.Position = drone.GetPosition();
	spawn.Position.Z += 00.0;

	SetVariantInt(2);
	teleporter.Input("SetTeam");
	teleporter.SetProp(Prop_Send, "m_bPlacing", 0);

	FGameplayStatics.FinishSpawn(teleporter, spawn);
	teleporter.SetParent(drone.GetObject());
}
*/

void CreateDroneCamera(ADrone drone, FVector cameraOffset, FDroneComponents components, FRotator seatRot, AComponent attachment = null)
{
	FObject camera;
	camera = FGameplayStatics.CreateObjectDeferred("prop_dynamic_override");

	camera.SetKeyValue("model", "models/empty.mdl"); // models/empty.mdl
	// PrintToChatAll("CreateDroneCamera::Camera Offset: %.1f, %.1f, %.1f", cameraOffset.X, cameraOffset.Y, cameraOffset.Z);

	FTransform spawn;
	spawn.Position = drone.GetPosition();
	spawn.Rotation = drone.GetAngles();

	spawn.Position = FMath.OffsetVector(spawn.Position, spawn.Rotation, cameraOffset);
	spawn.Rotation = seatRot;

	FGameplayStatics.FinishSpawn(camera, spawn);

	AComponent parent = attachment;
	if (!parent)
	{
		parent = drone;
	}
	camera.SetParent(parent.GetObject());

	components.Camera = camera;
}

FDroneSeat SetupSeat(KeyValues kv, ADrone drone)
{
	FDroneSeat seat = new FDroneSeat();
	seat.Type = view_as<ESeatType>(kv.GetNum("type")); // 0 = pilot, 1 = gunner, 2 = passenger
	seat.FirstPerson = view_as<bool>(kv.GetNum("first_person", 0));
	seat.Drone = drone;

	// If this is not a passenger seat, let's find the associated weapons that this seat can use
	if (seat.Type != Seat_Passenger)
	{
		char weapons[32];
		kv.GetString("weapons", weapons, sizeof weapons);

		if (StrEqual(weapons, "ALL")) // Provide access to all weapons
		{
			seat.Weapons = drone.Weapons;

			if (seat.Weapons.Length > 0)
			{
				for (int i = 0; i < seat.Weapons.Length; i++)
				{
					ADroneWeapon weapon = view_as<ADroneWeapon>(seat.Weapons.Get(i));
					if (weapon && weapon.IsDroneWeapon)
					{
						weapon.Seat = seat;
					}
				}
			}
		}
		else // Otherwise let's get the weapons allowed for this seat
		{
			int totalweapons = drone.Weapons.Length;
			char wepIndex[32][32];
			ExplodeString(weapons, ";", wepIndex, sizeof wepIndex, sizeof wepIndex[]);

			ADroneWeapon weapon = null;
			int index = -1;
			seat.Weapons = new FComponentArray();
			for (int i = 0; i < totalweapons; i++)
			{
				StringToIntEx(wepIndex[i], index);
				if (strlen(wepIndex[i]) > 0 && index > -1)
				{
					weapon = drone.Weapons.Get(index);
					if (weapon)
					{
						//PrintToChatAll("Adding weapon %x to seat %x", weapon, seat);
						seat.Weapons.Push(weapon);
						weapon.Seat = seat;
					}
				}
			}
		}

		if (seat.Weapons && seat.Weapons.Length > 0)
		{
			seat.ActiveWeaponIndex = 0;
			seat.ActiveWeapon = seat.Weapons.Get(0); // Set active weapon to first index
			ABaseEntity reticle = CreateReticle(drone);
			seat.SetReticle(reticle.GetObject());
			reticle.SetObjectProp("DroneSprite.Reticle.Seat", seat);
			reticle.SetObjectProp("DroneSprite.Reticle.SeatReticle", true);
		}
	}

	char attachpoint[64];
	kv.GetString("seat_attach", attachpoint, sizeof attachpoint);
	seat.SetAttachPoint(attachpoint);
	FTransform attach;
	GetAttachmentTransform(drone.GetObject(), attachpoint, attach);
	//PrintToChatAll("Seat (%s) attachment point: %.1f, %.1f, %.1f", attachpoint, attach.Position.X, attach.Position.Y, attach.Position.Z);

	FVector droneOffset;
	if (strlen(attachpoint) > 0)
	{
		droneOffset = drone.GetPosition();
		droneOffset.Negate();
		attach.Position.Add(droneOffset); // Get attach point as a relative position
	}

	// get our attached component
	char attachedName[64];
	kv.GetString("seat_parent", attachedName, sizeof attachedName);
	if (strlen(attachedName) > 0)
	{
		AComponent component = GetAttachmentByName(drone.GetComponents().Attachments, attachedName);
		if (component)
		{
			seat.AttachedComponent = component;
		}
	}

	// Setup seat camera
	FVector cameraOffset;
	if (seat.Type == Seat_Pilot) // Pilot seat uses the main drone camera
	{
		seat.SetCamera(drone.GetCamera());
		cameraOffset = ConstructVector(drone.CameraDistance, 0.0, drone.CameraHeight);
	}
	else
	{
		FDroneComponents seatComps;
		cameraOffset = Vector_GetFromKV(kv, "camera_offset");
		cameraOffset.Add(attach.Position);

		FRotator rotation;
		rotation = Rotator_GetFromKV(kv, "seat_rotation");
		//PrintToChatAll("Camera Offset: %.1f, %.1f, %.1f | Camera = %d", cameraOffset.X, cameraOffset.Y, cameraOffset.Z, seat.GetCamera().Get());
		CreateDroneCamera(drone, cameraOffset, seatComps, rotation, seat.AttachedComponent);

		seat.SetCamera(seatComps.Camera);
	}
	seat.SetCameraOffset(cameraOffset);

	// Player visibility
	char animation[64];
	kv.GetString("seat_animation", animation, sizeof animation);
	if (strlen(animation) > 0)
	{
		seat.UsePlayerModel = true;
		seat.SetPlayerAnim(animation);
	}

	FVector seatpos;
	seatpos = Vector_GetFromKV(kv, "seat_position");
	seatpos.Add(attach.Position);
	seat.SetSeatPosition(seatpos);

	FRotator rot;
	rot = Rotator_GetFromKV(kv, "seat_rotation");
	seat.SetSeatRotation(rot);

	seat.Occupied = false;
	seat.AIControlled = false;

	return seat;
}

/******************
* Drone Removal
******************/

/**
 * Kills the given drone
 */
void KillDrone(ADrone drone, FObject attacker, FObject inflictor, float damage, FWeapon weapon)
{
	if (!drone.Alive)
	{
		return;
	}

	ClearDroneWeaponReticles(drone);

	RemoveDestructibleParts(drone);

	char name[64];
	drone.GetInternalName(name, sizeof name);

	StopEngine(drone);

	for (int i = 0; i < drone.Seats.Length; i++)
	{
		FDroneSeat seat = drone.Seats.Get(i);
		if (seat)
		{
			if (seat.Occupied && seat.Occupier)
			{
				FClient occupier;
				occupier = seat.Occupier.GetClient();
				PlayerExitVehicle(seat.Occupier, seat, drone, false);
				TF2_RegeneratePlayer(occupier.Get());
				SDKHooks_TakeDamage(occupier.Get(), inflictor.Get(), attacker.Get(), 250.0);
				//ForcePlayerSuicide(occupier.Get());

				RequestFrame(RemoveLingeringWeapons); // Weapons seem to get created upon resupplying and not given to the player
			}
		}
	}

	if (weapon.Valid() && attacker.Valid() && inflictor.Valid())
	{
		// Want to try sending a kill event for the killfeed, just not sure how to handle it yet
	}

	drone.Health = 0;
	drone.Alive = false;

	drone.GetObject().AttachParticle("burningplayer_flyingbits", ConstructVector());

	FTransform spawn;
	spawn.Position = drone.GetPosition();
	CreateExplosion(0.0, 0.0, GetWorld(), drone.GetComponents().ExplodeParticle, drone.GetComponents().ExplodeSound, spawn);

	// Forward
	Action action = Plugin_Continue;
	Call_StartForward(DroneDestroyed);

	Call_PushCell(drone);
	Call_PushArray(attacker, sizeof FObject);
	Call_PushFloat(damage);
	Call_PushString(name);
	
	Call_Finish(action);

	if (action == Plugin_Continue)
	{
		CreateTimer(30.0, DroneExplodeTimer, drone, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void RemoveLingeringWeapons()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "tf_weapon*")) != -1)
	{
		FObject wep;
		wep = ConstructObject(entity);
		if (wep.GetOwner().Get() == wep.Get())
		{
			wep.Kill();
		}
	}
}

void RemoveDestructibleParts(ADrone drone)
{
	// ExplosionCore_MidAir
	FComponentArray components;
	components = drone.GetComponents().Attachments;
	
	if (components && components.Length > 0)
	{
		for (int i = components.Length - 1; i >= 0; i--) // reverse order
		{
			AComponent component = components.Get(i);
			if (component.GetObjectProp("DroneProp.DestroyOnDeath"))
			{
				SpawnComponentGib(component);
			}
		}
	}

	// FComponentArray weapons = drone.Weapons;
	// if (weapons && weapons.Length > 0)
	// {
	// 	for (int i = 0; i < weapons.Length; i++)
	// 	{
	// 		AComponent component = weapons.Get(i);
	// 		if (component.GetObjectProp("DroneProp.DestroyOnDeath"))
	// 		{
	// 			SpawnComponentGib(component);
	// 		}
	// 	}
	// }
}

/******************
* Helper Functions
******************/

Action DroneExplodeTimer(Handle timer, ADrone drone)
{
	drone.GetObject().Kill();
	return Plugin_Continue;
}

void SpawnComponentGib(AComponent component)
{
	char modelname[64];
	component.GetPropString(Prop_Data, "m_ModelName", modelname, sizeof modelname);
	FTransform spawn;
	spawn.Position = component.GetPosition();
	spawn.Rotation = component.GetAngles();

	FObject parent;
	parent = component.GetObjectPropEnt("DroneComponent.ParentEntity");
	char targetname[64];
	component.GetObject().GetTargetName(targetname, sizeof targetname);
	if (parent.Valid())
	{
		FVector parentPos;
		parentPos = parent.GetPosition();
		spawn.Position = component.GetRelativePosition();
		// PrintToChatAll("%s Position: %.1f, %.1f, %.1f", targetname, spawn.Position.X, spawn.Position.Y, spawn.Position.Z);
		// PrintToChatAll("%s parent position: %.1f, %.1f, %.1f", targetname, parentPos.X, parentPos.Y, parentPos.Z);
		spawn.Position.Add(parentPos);
	}

	//FEntityStatics.DestroyEntity(component);
	component.ComponentState = ComponentState_Destroyed;
	UpdateComponentState(component);

	FObject debris;
	debris = FGameplayStatics.CreateObjectDeferred("prop_physics_multiplayer");
	debris.SetModel(modelname);

	CreateParticleSystem("ExplosionCore_MidAir", spawn.Position, spawn.Rotation, 5.0);

	FGameplayStatics.FinishSpawn(debris, spawn);

	debris.KillOnDelay(30.0);
}

void UpdateComponentState(AComponent component)
{
	if (component.ComponentState == ComponentState_Destroyed)
	{
		SetEntityCollisionGroup(component.Get(), 0);
		SetEntityRenderMode(component.Get(), RENDER_NONE);
	}
}

void PlayerEnterVehicle(ADronePlayer player, ADrone drone, FDroneSeat seat)
{
	Action action = Plugin_Continue;
	Call_StartForward(DroneEnteredValid);

	Call_PushCell(drone);
	Call_PushCell(player);
	Call_PushCell(seat);

	Call_Finish(action);

	if (action > Plugin_Continue)
	{
		return;
	}

	player.InDrone = true;
	player.Drone = drone;

	if (seat.Type == Seat_Pilot)
	{
		drone.Pilot = player;
		drone.Team = player.Team;
		StartEngine(drone);
	}

	if (seat.UsePlayerModel)
	{
		CreatePlayerModel(drone, seat, player);
	}

	if (seat.GetReticle().Valid())
	{
		SDKHook(seat.GetReticle().Get(), SDKHook_SetTransmit, OnReticleReplicate);
		if (seat.ActiveWeapon && !seat.ActiveWeapon.HidesReticle)
		{
			seat.GetReticle().Input("ShowSprite");
		}
	}

	UpdateDroneComponentColors(drone);

	if (seat.FirstPerson)
	{
		SetVariantInt(0);
	}
	else
	{
		SetVariantInt(1);
	}
	player.GetObject().Input("SetForcedTauntCam");
	
	// Temp
	seat.Occupier = player;
	seat.Occupied = true;
	seat.AIControlled = false;

	SetEntityRenderMode(player.Get(), RENDER_NONE);
	RemoveWearables(player);
	TF2_RemoveAllWeapons(player.Get());

	SetClientViewEntity(player.Get(), seat.GetCamera().Get());

	SDKHook(player.Get(), SDKHook_OnTakeDamageAlive, OnPlayerTakeDamage);

	Call_StartForward(DroneEntered);

	Call_PushCell(drone);
	Call_PushCell(player);
	Call_PushCell(seat);

	Call_Finish();
}

void PlayerExitVehicle(ADronePlayer player, FDroneSeat seat, ADrone drone, bool resupply = true)
{
	player.InDrone = false;
	if (drone)
	{
		seat.Occupier = null;
		seat.Occupied = false;

		if (seat.Type == Seat_Pilot)
		{
			drone.Pilot = null;
			drone.Team = TFTeam_Unassigned;
			StopEngine(drone);
		}
	}
	//seat.Occupied = false;
	//seat.Occupier = null;

	if (seat.GetPlayerModel().Valid())
	{
		seat.GetPlayerModel().Kill();
	}

	if (seat.GetReticle().Valid())
	{
		SDKUnhook(seat.GetReticle().Get(), SDKHook_SetTransmit, OnReticleReplicate);
		seat.GetReticle().Input("HideSprite");
	}

	SetEntityRenderMode(player.Get(), RENDER_NORMAL);
	player.ExitingHealth = player.GetClient().GetHealth();

	SetVariantInt(0);
	player.GetObject().Input("SetForcedTauntCam");

	DisableDroneComponentVisuals(drone);

	if (resupply)
	{
		CreateTimer(0.1, ResetPlayerHealth, player, TIMER_FLAG_NO_MAPCHANGE);
	}

	SDKUnhook(player.Get(), SDKHook_OnTakeDamageAlive, OnPlayerTakeDamage);

	ResetClientView(player.GetClient());

	Call_StartForward(DroneExited);

	Call_PushCell(drone);
	Call_PushCell(player);
	Call_PushCell(seat);

	Call_Finish();
}

void StartEngine(ADrone drone)
{
	drone.EngineOn = true;

	char enginesound[64];
	drone.GetObjectPropString("Drone.EngineSound", enginesound, sizeof enginesound);
	EmitSoundToAll(enginesound, drone.Get(), SNDCHAN_AUTO, 100);

	FComponentArray components = drone.GetComponents().Attachments;
	if (components)
	{
		for (int i = 0; i < components.Length; i++)
		{
			AComponent component = components.Get(i);
			if (component)
			{
				char type[64];
				component.GetObjectPropString("DroneComponent.CompType", type, sizeof type);
				if (StrEqual(type, "prop_door"))
				{
					component.SetObjectProp("DroneProp.Door.Closing", true);
					component.SetObjectProp("DroneProp.Door.Opening", false);
				}
			}
		}
	}
}

void StopEngine(ADrone drone)
{
	drone.EngineOn = false;

	char enginesound[64];
	drone.GetObjectPropString("Drone.EngineSound", enginesound, sizeof enginesound);
	StopSound(drone.Get(), SNDCHAN_AUTO, enginesound);

	FComponentArray components = drone.GetComponents().Attachments;
	if (components)
	{
		for (int i = 0; i < components.Length; i++)
		{
			AComponent component = components.Get(i);
			if (component)
			{
				char type[64];
				component.GetObjectPropString("DroneComponent.CompType", type, sizeof type);
				if (StrEqual(type, "prop_door"))
				{
					component.SetObjectProp("DroneProp.Door.Opening", true);
					component.SetObjectProp("DroneProp.Door.Closing", false);
				}
			}
		}
	}
}

Action ResetPlayerHealth(Handle timer, ADronePlayer player)
{
	//TF2_RegeneratePlayer(player.Get());
	FVector position;
	position = player.GetPosition();

	FRotator rotation;
	rotation = player.GetAngles();
	TF2_RespawnPlayer(player.Get());
	TeleportEntity(player.Get(), position.ToFloat(), rotation.ToFloat(), NULL_VECTOR);

	SetEntityHealth(player.Get(), player.ExitingHealth);

	return Plugin_Continue;
}

// Returns the seat the player is in.
FDroneSeat GetPlayerSeat(ADronePlayer player, ADrone drone)
{
	if (drone.Seats && drone.Seats.Length)
	{
		for (int i = 0; i < drone.Seats.Length; i++)
		{
			FDroneSeat seat = drone.Seats.Get(i);
			if (seat && seat.Occupied && seat.Occupier)
			{
				if (seat.Occupier == player)
				{
					return seat;
				}
			}
		}
	}

	return null;
}

public Action OnClientCommandKeyValues(int clientId, KeyValues kv)
{
	//if (GameRules_GetProp("m_bInWaitingForPlayers") == 1)
	//{
	//	return Plugin_Continue;
	//}
	
	FClient client;
	client = ConstructClient(clientId);

	ADronePlayer player = view_as<ADronePlayer>(FEntityStatics.GetClient(client));

	char command[64];
	kv.GetSectionName(command, sizeof command);

	ADrone drone = null;

	if (StrEqual(command, "+inspect_server", false))
	{
		if(client.Valid() && client.Alive())
		{
			FDroneSeat nearestSeat = null;
			if (!player.InDrone && PlayerAimingAtDrone(player, drone, nearestSeat))
			{
				if (!nearestSeat.Occupied && drone.Alive)
				{
					PlayerEnterVehicle(player, drone, nearestSeat);
				}
				return Plugin_Handled;
			}
			else if (player.InDrone)
			{
				drone = player.GetDrone();
				Action action = Plugin_Continue;
				Call_StartForward(DroneExitedValid);
				Call_PushCell(drone);
				Call_PushCell(player);
				Call_PushCell(GetPlayerSeat(player, drone));

				Call_Finish(action);

				if (action == Plugin_Continue)
				{
					PlayerExitVehicle(player, GetPlayerSeat(player, drone), drone);
				}
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

void UpdateDroneComponentColors(ADrone drone)
{
	char color[32];
	switch (drone.Team)
	{
		case TFTeam_Red: FormatEx(color, sizeof color, "255 0 0");
		case TFTeam_Blue: FormatEx(color, sizeof color, "5 125 255");
		default: FormatEx(color, sizeof color, "255 100 150"); // pink for neutral/no team
	}

	FComponentArray components = drone.GetComponents().Attachments;
	if (components)
	{
		for (int i = 0; i < components.Length; i++)
		{
			AComponent component = components.Get(i);
			if (component)
			{
				if (component.GetObjectProp("DroneComponent.UseTeamColors"))
				{
					SetVariantString(color);
					component.GetObject().Input("Color");
				}

				if (component.GetObjectProp("DroneComponent.ActivateUponEntry"))
				{
					component.GetObject().Input("ShowSprite");
				}
			}
		}
	}
}

void DisableDroneComponentVisuals(ADrone drone)
{
	FComponentArray components = drone.GetComponents().Attachments;
	if (components)
	{
		for (int i = 0; i < components.Length; i++)
		{
			AComponent component = components.Get(i);
			if (component)
			{
				if (component.GetObjectProp("DroneComponent.ActivateUponEntry"))
				{
					component.GetObject().Input("HideSprite");
				}
			}
		}
	}
}

bool PlayerAimingAtDrone(AClient client, ADrone& currentDrone, FDroneSeat& currentSeat)
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
			// Check if we are close enough to a seat
			FRotator droneAngle;
			FVector seatPos, dronePos;
			droneAngle = drone.GetAngles();
			dronePos = drone.GetPosition();
			for (int i = 0; i < drone.Seats.Length; i++)
			{
				FDroneSeat seat = drone.Seats.Get(i);
				if (seat && !seat.Occupied)
				{
					seatPos = seat.GetSeatPosition();
					seatPos = FMath.OffsetVector(dronePos, droneAngle, seatPos);

					if (seatPos.DistanceTo(startPos) <= 150.0)
					{
						currentSeat = seat;
						break;
					}
				}
			}
			if (currentSeat) // we found a nearby seat
			{
				currentDrone = drone;
				return true;
			}
		}
	}
	delete trace;

	return false;
}

Action OnPlayerTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	ADronePlayer player = view_as<ADronePlayer>(FEntityStatics.GetClientFromIndex(client));
	if (player && player.InDrone)
	{
		damage = 0.0;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

bool TraceFilter(int entity, int mask, int exclude)
{
	return entity != exclude;
}

void CreatePlayerModel(ADrone drone, FDroneSeat seat, AClient client)
{
	FObject model;
	model = FGameplayStatics.CreateObjectDeferred("prop_dynamic_override");
	char playermodel[64];

	client.GetPropString(Prop_Data, "m_ModelName", playermodel, sizeof playermodel);
	model.SetKeyValue("model", playermodel);
	AComponent parent = seat.AttachedComponent;
	if (!parent)
	{
		parent = drone;
	}

	FGameplayStatics.FinishSpawn(model, ConstructTransform(drone.GetPosition(), parent.GetAngles()));

	int skin = view_as<int>(client.Team) - 2;
	SetVariantInt(skin);
	model.Input("skin");

	FVector offset;
	offset = seat.GetSeatPosition();
	// FRotator rot;
	// rot = seat.GetSeatRotation();

	offset = FMath.OffsetVector(drone.GetPosition(), drone.GetAngles(), offset);
	TeleportEntity(model.Get(), offset.ToFloat());

	model.SetParent(parent.GetObject());

	char anim[64];
	seat.GetPlayerAnim(anim, sizeof anim);
	SetVariantString(anim);
	model.Input("SetAnimation");

	seat.SetPlayerModel(model);
}

ABaseEntity CreateReticle(ADrone drone, char[] material = "materials/sprites/reticle.vmt")
{
	ABaseEntity reticle = FEntityStatics.CreateEntity("env_sprite", drone.GetObject(), "DroneSprite.Reticle");
	PrecacheModel(material);
	reticle.SetKeyValue("model", material);
	reticle.SetModel(material);

	reticle.SetKeyValueFloat("scale", 0.5);
	reticle.SetKeyValueInt("renderamt", 255);
	reticle.SetKeyValueInt("rendermode", 1);

	FTransform spawn;
	spawn.Position = drone.GetPosition();
	FEntityStatics.FinishSpawningEntity(reticle, spawn);

	reticle.GetObject().Input("HideSprite");

	SetEdictFlags(reticle.Get(), GetEdictFlags(reticle.Get()) & ~FL_EDICT_ALWAYS);

	return reticle;
}

Action OnReticleReplicate(int entityId, int clientId)
{
	ABaseEntity reticle = FEntityStatics.GetEntityFromIndex(entityId);
	if (reticle)
	{
		SetEdictFlags(reticle.Get(), GetEdictFlags(reticle.Get()) & ~FL_EDICT_ALWAYS);
		FDroneSeat seat = null;
		if (reticle.GetObjectProp("DroneSprite.Reticle.SeatReticle"))
		{
			seat = reticle.GetObjectProp("DroneSprite.Reticle.Seat");
		}
		if (reticle.GetObjectProp("DroneSprite.Reticle.LockOnReticle"))
		{
			ADroneWeapon weapon = reticle.GetObjectProp("DroneSprite.Reticle.Weapon");
			if (weapon && weapon.Seat && weapon.Seat.ActiveWeapon == weapon)
			{
				seat = weapon.Seat;
			}
		}
		if (seat && !seat.AIControlled)
		{
			if (seat.Occupied && seat.Occupier)
			{
				if (clientId == seat.Occupier.Get())
				{
					return Plugin_Continue;
				}
			}
		}
	}
	return Plugin_Handled;
}

void HideReticle(FObject reticle)
{
	if (reticle.Valid())
	{
		reticle.Input("HideSprite");
	}
}

void ShowReticle(FObject reticle)
{
	if (reticle.Valid())
	{
		reticle.Input("ShowSprite");
	}
}

ADrone FindBestDroneForLockOn(ADroneProjectileWeapon weapon, ADrone drone, FRotator viewAngles)
{
	ADrone target = null;
	FRotator targetAngle;
	FVector targetVec, forwardVec;
	forwardVec = viewAngles.GetForwardVector();
	float fov = weapon.LockOnFOV;

	FObject curTarget;
	curTarget = weapon.GetObjectPropEnt("DroneWeapon.CurrentHomingTarget");

	if (weapon.IsLockedOn)
	{
		if (!curTarget.Valid())
		{
			weapon.IsLockedOn = false;
			weapon.LockOnProgress = 0.0;
		}

		float lastLockTime = weapon.GetObjectPropFloat("DroneWeapon.LastLockTime");
		targetVec = Vector_Subtract(curTarget.GetPosition(), weapon.GetPosition());
		targetAngle = FMath.CalcRotator(forwardVec, targetVec);
		float angle = FMath.GetAngle(viewAngles, targetAngle);
		if (angle > fov && GetGameTime() - lastLockTime >= 5.0) // 5 second target lock
		{
			return null;
		}

		return view_as<ADrone>(FEntityStatics.GetEntity(curTarget));
	}

	ADrone test = null;
	float distance = 8192.0;
	float bestfov = fov;
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_physics_multiplayer")) != -1)
	{
		test = view_as<ADrone>(FEntityStatics.GetEntityFromIndex(entity));
		if (test && test.IsDrone && test.Team != drone.Team && test.Alive && CanLockOn(weapon.LockOnType, test))
		{
			targetVec = Vector_Subtract(test.GetPosition(), weapon.GetPosition());
			targetAngle = FMath.CalcRotator(forwardVec, targetVec);
			float angle = FMath.GetAngle(viewAngles, targetAngle);
			//PrintCenterTextAll("FOV = %.1f", angle);
			if (angle > fov)
			{
				continue;
			}

			if (angle <= bestfov)
			{
				// Now check distance
				float testdist = FGameplayStatics.GetDistanceBetweenObjects(drone.GetObject(), test.GetObject());
				if (testdist < distance)
				{
					bestfov = angle;
					target = test;
				}
			}
		}
	}

	if (target && target.Get() != curTarget.Get()) // We have a new target, reset progress
	{
		weapon.LockOnProgress = 0.0;
	}

	return target;
}

bool CanLockOn(ELockOnType type, ADrone target)
{
	if (type == LockOn_None)
	{
		return false;
	}

	if (type == LockOn_Both)
	{
		return true;
	}
	
	return type == target.FunctionType;
}

void ClearDroneWeaponReticles(ADrone drone)
{
	if (drone.Weapons)
	{
		if (drone.Weapons.Length > 0)
		{
			for (int i = 0; i < drone.Weapons.Length; i++)
			{
				ADroneWeapon dweapon = drone.Weapons.Get(i);
				if (dweapon)
				{
					FObject reticle;
					reticle = dweapon.GetObjectPropEnt("DroneWeapon.LockOnReticle");
					if (reticle.Valid())
					{
						ABaseEntity ret = FEntityStatics.GetEntity(reticle);
						ret.SetObjectProp("DroneSprite.Reticle.Weapon", 0);
						SDKUnhook(ret.Get(), SDKHook_SetTransmit, OnReticleReplicate);
						reticle.Kill();
					}
				}
			}
		}
	}
}
