#if defined _customdrones_ai_included
 #endinput
#endif
#define _customdrones_ai_included

enum EBehaviorType
{
	Behavior_Aggressive, 	// Drone will actively pursue enemies

	Behavior_Support		// Drone will actively find teammates to remain around
};

enum EControllerState
{
	Controller_Idle, 		// Currently idle, nothing of interest

	Controller_Attacking, 	// We have a target and are attacking

	Controller_Seeking, 	// Seeking our current target but cannot see it

	Controller_Fleeing, 	// Retreating if possible

	Controller_Alerted, 	// We were fired at or took damage, look in direction of alert source

	Controller_Disengaged,	// We have a target but are not actively pursuing - used for flying drones to break off and get distance

	Controller_Disabled		// Controller is currently disabled and will not function
};

enum struct FDroneMoveParams
{
	float MaxDist;
	float MinDist;
	float Ceiling;
	float MinHeight;
}

enum struct FDroneAIParams
{
	float MinAttackDistance;	// Closest distance we will maintain when attacking
	float MaxAttackDistance;	// Farthest distance we will maintain when attacking
	float DetectionRange;		// How far we can detect targets from our current position
	float DisengageRange;		// How far flying drones will travel to disengage

	float IdleMoveRange;		// Max distance we will check for a new move position, while idle
	float IdleMoveRangeMin;		// Minimum distance we will check for a new move position, while idle

	bool LevelCombat;			// Do we try to maintain similar height to our target
	bool PursueTarget;			// For aggressive, do we pursue targets after losing line of sight

	float HoverHeight;			// Minimum height we try to keep above the ground, if applicable.
	float IdleCeiling;			// If applicable, when moving to a new position, we will be predisposed to fly no higher than this height from our current position	
	float CombatCeiling;		// If applicable, when in combat, we will be predisposed to fly no higher than this height from our current position
	
	float ThinkRate;			// How often we process think requests
	float IdleTime; 			// How long we wait to issue idle requests
	float CombatTime;			// How often we check if we can switch to a new target while in combat
	float CombatMoveTime;		// How long between move requests while we are in combat

	float SeekTime;				// How long we will seek for a lost target before giving up
	float BurstTime;			// How long we hold our trigger down when firing. 0 = continuously held down
	float BurstDelay;			// How long we wait between firing bursts

	float AimSpeed;				// How quickly we take to aim at our target, higher speeds is more accurate

	float Braking;
	float PathFindRadius;

	float SupportRange;
	float MinSupportRange;

	int MaxQueries;

	bool Stationary;
	bool IgnoreWalls; 			// Controller can detect targets behind walls
	bool FactorGrav;

	bool OnlyFollowOwner;		// Support drone will only follow the owner
	bool PrioritizeOwner;		// Support drone will prioritize following the owner but can still follow other players
	
	float DetectionFOV;			// FOV for this drone to target enemies
	float AimFOV;				// FOV for firing weapons

	float AvoidanceCheckDelay;
	bool AimTowardsMovement;
	EBehaviorType Behavior;
}

methodmap FDroneAI < StringMap
{
	// Whether or not this is a valid DroneAI
	public bool ValidDroneAI() { return this.GetBool("SMap_IsDroneAI"); }

	public void SetControllerParams(FDroneAIParams params)
	{
		this.SetArray("DroneAI_ContrParams", params, sizeof FDroneAIParams);
	}
	public FDroneAIParams GetControllerParams()
	{
		FDroneAIParams params;
		this.GetArray("DroneAI_ContrParams", params, sizeof FDroneAIParams);

		return params;
	}

	public void SetInt(const char[] property, int value) { this.SetValue(property, value); }
	public int GetInt(const char[] property)
	{
		int value;
		this.GetValue(property, value);

		return value;
	}

	public void SetFloat(const char[] property, float value) { this.SetValue(property, value); }
	public float GetFloat(const char[] property)
	{
		float value;
		this.GetValue(property, value);

		return value;
	}

	public void SetBool(const char[] property, bool value) { this.SetValue(property, value); }
	public bool GetBool(const char[] property)
	{
		bool value;
		this.GetValue(property, value);

		return value;
	}

	public any GetObject(const char[] property)
	{
		any value;
		this.GetValue(property, value);

		return value;
	}

	property bool OverrideMovement // Prevents native movement for this drone, if applicable
	{
		public set(bool value) { this.SetBool("DroneAI_OverrideMovement", value); }
		public get() { return this.GetBool("DroneAI_OverrideMovement"); }
	}

	property bool Stationary // This controller is stationary and will not move on its own
	{
		public set(bool value) { this.SetBool("DroneAI_Stationary", value); }
		public get() { return this.GetBool("DroneAI_Stationary"); }
	}

	property bool Moving
	{
		public set(bool value) { this.SetBool("DroneAI_IsMovingToPosition", value); }
		public get() { return this.GetBool("DroneAI_IsMovingToPosition"); }
	}

	property bool Stalling
	{
		public set(bool value) { this.SetBool("DroneAI_IsStalling", value); }
		public get() { return this.GetBool("DroneAI_IsStalling"); }
	}

	// We are currently looking for our lost target
	property bool Seeking
	{
		public set(bool value) { this.SetBool("DroneAI_IsSeekingTarget", value); }
		public get() { return this.GetBool("DroneAI_IsSeekingTarget"); }
	}

	property bool IgnoreWalls
	{
		public set(bool value) { this.SetBool("DroneAI_CanSeeThroughWalls", value); }
		public get() { return this.GetBool("DroneAI_CanSeeThroughWalls"); }
	}

	property bool FactorGravity
	{
		public set(bool value) { this.SetBool("DroneAI_TossesProjectiles", value); }
		public get() { return this.GetBool("DroneAI_TossesProjectiles"); }
	}

	property AClient Owner
	{
		public set(AClient client) { this.SetValue("ADroneAI_OwningPlayer", client); }
		public get() { return view_as<AClient>(this.GetObject("ADroneAI_OwningPlayer")); }
	}

	property ADrone Drone
	{
		public set(ADrone drone) { this.SetValue("ADroneAI_ControlledDrone", drone); }
		public get() { return view_as<ADrone>(this.GetObject("ADroneAI_ControlledDrone")); }
	}

	property FDroneSeat ControlledSeat
	{
		public set(FDroneSeat seat) { this.SetValue("ADroneAI_ControlledSeat", seat); }
		public get() { return view_as<FDroneSeat>(this.GetObject("ADroneAI_ControlledSeat")); }
	}

	property EBehaviorType Behavior
	{
		public set(EBehaviorType value) { this.SetValue("DroneAI_Behavior", value); }
		public get() { return view_as<EBehaviorType>(this.GetObject("DroneAI_Behavior")); }
	}

	// How far we will try to move when moving to a new location
	property float MoveRange
	{
		public set(float value) { this.SetFloat("DroneAI_TravelDistance", value); }
		public get() { return this.GetFloat("DroneAI_TravelDistance"); }
	}

	// Minimum distance we try to move to when moving to a new location
	property float MinMoveRange
	{
		public set(float value) { this.SetFloat("DroneAI_MinTravelDistance", value); }
		public get() { return this.GetFloat("DroneAI_MinTravelDistance"); }
	}

	// Our minimum distance where we feel comfortable engaging from. We will back away from targets that are this close
	property float MinAttackRange
	{
		public set(float value) { this.SetFloat("DroneAI_MinEngageDistance", value); }
		public get() { return this.GetFloat("DroneAI_MinEngageDistance"); }
	}

	// How close we try to stay to a target when engaging. If they leave this range, we will pursue if allowed.
	property float DesiredAttackRange
	{
		public set(float value) { this.SetFloat("DroneAI_MaxEngageRange", value); }
		public get() { return this.GetFloat("DroneAI_MaxEngageRange"); }
	}

	// Distance at which we detect targets
	property float DetectionRange
	{
		public set(float value) { this.SetFloat("DroneAI_DetectionDistance", value); }
		public get() { return this.GetFloat("DroneAI_DetectionDistance"); }
	}

	// If we are flying, when moving to a new position, we will try not to go above this extra height
	property float MaxMoveHeight
	{
		public set(float value) { this.SetFloat("DroneAI_MaxMovementCeiling", value); }
		public get() { return this.GetFloat("DroneAI_MaxMovementCeiling"); }
	}

	// If we are flying, when in combat, we will try not to go above this extra height
	property float MaxCombatHeight
	{
		public set(float value) { this.SetFloat("DroneAI_MaxCombatCeiling", value); }
		public get() { return this.GetFloat("DroneAI_MaxCombatCeiling"); }
	}

	// If we are flying, this is the closest we will try to be to the ground at all times
	property float HoverHeight
	{
		public set(float value) { this.SetFloat("DroneAI_HoverHeight", value); }
		public get() { return this.GetFloat("DroneAI_HoverHeight"); }
	}

	// If true and we are flying, we will refrain from going below our current target's height level
	property bool LevelCombat
	{
		public set(bool value) { this.SetBool("DroneAI_KeepLevelWithTarget", value); }
		public get() { return this.GetBool("DroneAI_KeepLevelWithTarget"); }
	}

	// Our current state of mind
	property EControllerState CurrentState
	{
		public set(EControllerState value) { this.SetValue("DroneAI_CurrentState", value); }
		public get() { return view_as<EControllerState>(this.GetObject("DroneAI_CurrentState")); }
	}

	// How many seconds must pass before we may process think requests
	property float ThinkRate
	{
		public set(float value) { this.SetFloat("DroneAI_ThinkRate", value); }
		public get() { return this.GetFloat("DroneAI_ThinkRate"); }
	}

	// Next game frame that we may process a think request. This determines how often we may process commands
	property float NextThinkTime
	{
		public set(float value) { this.SetFloat("DroneAI_NextThinkTick", value); }
		public get() { return this.GetFloat("DroneAI_NextThinkTick"); }
	}

	// How long we must remain idle for before attempting a new movement command
	property float IdleTime
	{
		public set(float value) { this.SetFloat("DroneAI_IdleTime", value); }
		public get() { return this.GetFloat("DroneAI_IdleTime"); }
	}

	// Game time that we may process a new movement command
	property float NextMovementTime
	{
		public set(float value) { this.SetFloat("DroneAI_NextIdleTick", value); }
		public get() { return this.GetFloat("DroneAI_NextIdleTick"); }
	}

	// Our current target. Can be friend or foe depending on our behavior
	property APersistentObject CurrentTarget
	{
		public set(APersistentObject value)
		{
			FObject entity;
			if (value)
			{
				entity = value.GetObject();
			}
			else
			{
				entity = GetWorld();
			}

			this.SetArray("DroneAI_CurrentTargetEntity", entity, sizeof FObject);
		}
		public get()
		{
			APersistentObject value = null;
			FObject entity;
			this.GetArray("DroneAI_CurrentTargetEntity", entity, sizeof FObject);
			
			if (entity.Valid())
			{
				if (entity.Get() > 0 && entity.Get() <= MaxClients)
				{
					value = view_as<APersistentObject>(FEntityStatics.GetClient(CastToClient(entity)));
				}
				else
				{
					value = view_as<APersistentObject>(FEntityStatics.GetEntity(entity));
				}
			}

			return value;
		}
	}

	// Next game time that we can check for new targets while in combat
	property float NextCombatCheckTime
	{
		public set(float value) { this.SetFloat("DroneAI_NextCombatTick", value); }
		public get() { return this.GetFloat("DroneAI_NextCombatTick"); }
	}

	// At what time we will give up our search for our lost target
	property float EndPursuitTime
	{
		public set(float value) { this.SetFloat("DroneAI_EndSeekAt", value); }
		public get() { return this.GetFloat("DroneAI_EndSeekAt"); }
	}

	// After firing our weapon, the game time at which we will stop firing
	property float EndFireTime
	{
		public set(float value) { this.SetFloat("DroneAI_EndFireAt", value); }
		public get() { return this.GetFloat("DroneAI_EndFireAt"); }
	}

	// When we can decide to fire our weapon again
	property float NextFireTime
	{
		public set(float value) { this.SetFloat("DroneAI_NextFireTime", value); }
		public get() { return this.GetFloat("DroneAI_NextFireTime"); }
	}

	// Are we currently attacking
	property bool InAttack
	{
		public set(bool value) { this.SetBool("DroneAI_Attacking", value); }
		public get() { return this.GetBool("DroneAI_Attacking"); }
	}

	property int TargetQueryIndex
	{
		public set(int value) { this.SetInt("DroneAI_TargetQueryIndex", value); }
		public get() { return this.GetInt("DroneAI_TargetQueryIndex"); }
	}

	property int MaxQueriedPositions
	{
		public set(int value) { this.SetInt("DroneAI_MaxQueryIndex", value); }
		public get() { return this.GetInt("DroneAI_MaxQueryIndex"); }
	}

	// We track these positions for when we seek our current target to retrace steps
	property ArrayList TargetQueryPositions
	{
		public set(ArrayList value) { this.SetValue("DroneAI_PositionsInMemory", value); }
		public get() { return view_as<ArrayList>(this.GetObject("DroneAI_PositionsInMemory")); }
	}

	// Next game frame that we track our own and our target's position
	property float QueryRate
	{
		public set(float value) { this.SetFloat("DroneAI_PositionQueryRate", value); }
		public get() { return this.GetFloat("DroneAI_PositionQueryRate"); }
	}

	// Next game frame that we track our own and our target's position
	property float NextQueryTime
	{
		public set(float value) { this.SetFloat("DroneAI_NextPositionQueryTick", value); }
		public get() { return this.GetFloat("DroneAI_NextPositionQueryTick"); }
	}

	// If losing our target from our own doing, retrace our own last few positions
	property ArrayList OwnQueryPositions
	{
		public set(ArrayList value) { this.SetValue("DroneAI_PositionsInMemory", value); }
		public get() { return view_as<ArrayList>(this.GetObject("DroneAI_PositionsInMemory")); }
	}

	public FRotator GetViewAngle()
	{
		FRotator angle;
		this.GetArray("DroneAI_ViewAngle", angle, sizeof FRotator);

		return angle;
	}
	public void SetViewAngle(FRotator angle) { this.SetArray("DroneAI_ViewAngle", angle, sizeof FRotator); }

	public FRotator GetTargetAngle()
	{
		FRotator angle;
		this.GetArray("DroneAI_TargetAngle", angle, sizeof FRotator);

		return angle;
	}
	public void SetTargetAngle(FRotator angle) { this.SetArray("DroneAI_TargetAngle", angle, sizeof FRotator); }

	public FVector GetMovePosition()
	{
		FVector pos;
		this.GetArray("DroneAI_NextMoveLocation", pos, sizeof FVector);

		return pos;
	}
	public void SetMovePosition(FVector pos) { this.SetArray("DroneAI_NextMoveLocation", pos, sizeof FVector); }

	public void SetLastSeenVelocity(FVector velocity) { this.SetArray("DroneAI_LastVel", velocity, sizeof FVector); }
	public FVector GetLastSeenVelocity()
	{
		FVector result;
		this.GetArray("DroneAI_LastVel", result, sizeof FVector);

		return result;
	}

	property bool PursuitEnding // We reached the end of our pursuit and are now moving in the last direction we saw the target
	{
		public set(bool value) { this.SetBool("DroneAI_TrackingLastVelocity", value); }
		public get() { return this.GetBool("DroneAI_TrackingLastVelocity"); }
	}

	public void ClearAIParams()
	{
		if (this.TargetQueryPositions)
		{
			delete this.TargetQueryPositions;
		}

		if (this.OwnQueryPositions)
		{
			delete this.OwnQueryPositions;
		}
	}

	property float AvoidanceCheckTime
	{
		public set(float value) { this.SetFloat("DroneAI_LastCheckForAvoidance", value); }
		public get() { return this.GetFloat("DroneAI_LastCheckForAvoidance"); }
	}
}

methodmap FSupportAI < FDroneAI
{
	property AClient FollowTarget
	{
		public set(AClient client) { this.SetValue("SupportAI_FollowTarget", client); }
		public get() { return view_as<AClient>(this.GetObject("SupportAI_FollowTarget")); }
	}

	property float SupportRange
	{
		public set(float value) { this.SetFloat("SupportAI_MaxFollowDistance", value); }
		public get() { return this.GetFloat("SupportAI_MaxFollowDistance"); }
	}

	property float MinSupportRange
	{
		public set(float value) { this.SetFloat("SupportAI_MinFollowDistance", value); }
		public get() { return this.GetFloat("SupportAI_MinFollowDistance"); }
	}
}

methodmap FDroneAIStatics
{
	public static FDroneAI CreateDroneAIController(FDroneAIParams params)
	{
		FDroneAI ai = view_as<FDroneAI>(new StringMap());
		if (ai)
		{
			ai.SetValue("SMap_IsDroneAI", true);

			ai.DesiredAttackRange = params.MaxAttackDistance;
			ai.DetectionRange = params.DetectionRange;
			ai.MinAttackRange = params.MinAttackDistance;
			ai.MaxMoveHeight = params.IdleCeiling;
			ai.MaxCombatHeight = params.CombatCeiling;
			ai.HoverHeight = params.HoverHeight;

			ai.MoveRange = params.IdleMoveRange;
			ai.MinMoveRange = params.IdleMoveRangeMin;
			ai.LevelCombat = params.LevelCombat;

			ai.Behavior = params.Behavior;
			ai.Stationary = params.Stationary;
			ai.IgnoreWalls = params.IgnoreWalls;
			ai.FactorGravity = params.FactorGrav;

			ai.IdleTime = params.IdleTime;
			ai.ThinkRate = params.ThinkRate;

			ai.MaxQueriedPositions = params.MaxQueries;

			if (params.Behavior == Behavior_Support)
			{
				FSupportAI support = view_as<FSupportAI>(ai);
				support.SupportRange = params.SupportRange;
				support.MinSupportRange = params.MinSupportRange;
			}

			ai.SetControllerParams(params);
		}

		return ai;
	}

	public static FDroneAIParams CreateDefaultParamSet()
	{
		FDroneAIParams params;
		params.MinAttackDistance = 0.0;
		params.MaxAttackDistance = 1100.0;
		params.DetectionRange = 1100.0;
		params.IdleCeiling = 700.0;
		params.CombatCeiling = 400.0;
		params.HoverHeight = 250.0;
		
		params.IdleMoveRange = 1200.0;
		params.IdleMoveRangeMin = 800.0;
		params.LevelCombat = false;
		params.PursueTarget = false;
		params.Stationary = false;

		params.ThinkRate = 0.1;
		params.IdleTime = 2.0;
		params.CombatTime = 4.0;
		params.SeekTime = 6.0;
		params.BurstTime = 1.0;
		params.BurstDelay = 2.0;
		params.CombatMoveTime = 2.0;
		params.AimSpeed = 360.0;

		params.SupportRange = 200.0;
		params.MinSupportRange = 0.0;

		params.Braking = 0.95;
		params.PathFindRadius = 200.0;
		params.MaxQueries = 5;

		params.OnlyFollowOwner = false;
		params.PrioritizeOwner = false;

		params.DetectionFOV = 180.0;
		params.AimFOV = 180.0;
		params.AvoidanceCheckDelay = 0.0;
		params.AimTowardsMovement = true;

		return params;
	}

	public static FDroneAIParams CreateParamSetFromConfig(const char[] config)
	{
		FDroneAIParams params;

		char path[256];
		BuildPath(Path_SM, path, sizeof path, "configs/drones/ai/%s.cfg", config);

		KeyValues kv = new KeyValues("DroneAI");
		if (kv)
		{
			if (kv.ImportFromFile(path))
			{
				params.MinAttackDistance = kv.GetFloat("min_attack_range", 0.0);
				params.MaxAttackDistance = kv.GetFloat("max_attack_range", 1100.0);
				params.DetectionRange = kv.GetFloat("detection_range", 1100.0);
				params.DisengageRange = kv.GetFloat("disengage_range", 500.0);
				params.IdleCeiling = kv.GetFloat("max_idle_height", 700.0);
				params.CombatCeiling = kv.GetFloat("max_combat_height", 400.0);
				params.HoverHeight = kv.GetFloat("min_height", 250.0);

				params.IdleMoveRange = kv.GetFloat("max_move_range", 1200.0);
				params.IdleMoveRangeMin = kv.GetFloat("min_move_range", 800.0);
				params.LevelCombat = view_as<bool>(kv.GetNum("level_combat_height", 0));
				params.PursueTarget = view_as<bool>(kv.GetNum("pursue_target", 0));
				params.Stationary = view_as<bool>(kv.GetNum("stationary", 0));

				params.ThinkRate = kv.GetFloat("think_rate", 0.1);
				params.IdleTime = kv.GetFloat("idle_timer", 2.0);
				params.CombatTime = kv.GetFloat("combat_timer", 4.0);
				params.SeekTime = kv.GetFloat("pursue_timer", 6.0);
				params.BurstTime = kv.GetFloat("burst_time", 1.0);
				params.BurstDelay = kv.GetFloat("burst_delay", 2.0);
				params.CombatMoveTime = kv.GetFloat("combat_move_time", 2.0);
				params.AimSpeed = kv.GetFloat("aim_speed", 360.0);

				params.SupportRange = kv.GetFloat("max_support_range", 200.0);
				params.MinSupportRange = kv.GetFloat("min_support_range", 0.0);

				params.Braking = kv.GetFloat("braking_speed", 0.95);
				params.PathFindRadius = kv.GetFloat("path_find_radius", 200.0);
				params.MaxQueries = kv.GetNum("query_positions_max", 5);

				params.OnlyFollowOwner = view_as<bool>(kv.GetNum("support_follow_owner", 0));
				params.PrioritizeOwner = view_as<bool>(kv.GetNum("support_prioritize_owner", 0));

				params.AimFOV = kv.GetFloat("aim_fov", 180.0);
				params.DetectionFOV = kv.GetFloat("detection_fov", 180.0);
				params.AvoidanceCheckDelay = kv.GetFloat("avoidance_delay", 0.0);
				params.AimTowardsMovement = view_as<bool>(kv.GetNum("aim_towards_movement", 1));
			}
			else
			{
				PrintToServer("AI config %s not found!", config);
			}
		}
		delete kv;

		return params;
	}

	public static FDroneAI GetSeatController(FDroneSeat seat)
	{
		FDroneAI ai = null;

		if (seat.AIControlled)
		{
			ai = seat.AIOccupier;
		}

		return ai;
	}
}
