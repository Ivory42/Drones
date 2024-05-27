#if defined _customdrones_ai_included
 #endinput
#endif
#define _customdrones_ai_included

enum EBehaviorType
{
	// Drone will actively pursue enemies
	Behavior_Aggressive,

	// Drone will stand its ground and defend its position
	Behavior_Passive,

	// Drone will actively find teammates to remain around
	Behavior_Support
};

enum EControllerState
{
	// Currently idle, nothing of interest
	Controller_Idle,

	// We have a target and are attacking
	Controller_Attacking,

	// Seeking our current target but cannot see it
	Controller_Seeking,

	// Retreating if possible
	Controller_Fleeing,

	// We were fired at or took damage, look in direction of alert source
	Controller_Alerted
};

enum struct FDroneAIParams
{
	bool Pilot;
	bool Gunner;

	// How often we process think requests
	float ThinkRate;
	// How long we wait to issue idle requests
	float IdleTime;
	// How often we check if we can switch to a new target while in combat
	float CombatTime;
	// How long we will seek for a lost target before giving up
	float SeekTime;
	// How long we hold our trigger down when firing. 0 = continuously held down
	float BurstTime;
	// How long we wait between firing bursts
	float BurstDelay;

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

	property bool IsPilot
	{
		public set(bool value) { this.SetBool("DroneAI_IsPilot", value); }
		public get() { return this.GetBool("DroneAI_IsPilot"); }
	}

	property bool IsGunner
	{
		public set(bool value) { this.SetBool("DroneAI_IsGunner", value); }
		public get() { return this.GetBool("DroneAI_IsGunner"); }
	}

	property AClient Owner
	{
		public set(AClient client) { this.SetValue("ADroneAI_OwningPlayer", client); }
		public get() { return view_as<AClient>(this.GetObject("ADroneAI_OwningPlayer")); }
	}

	property EBehaviorType Behavior
	{
		public set(EBehaviorType value) { this.SetValue("DroneAI_Behavior", value); }
		public get() { return view_as<EBehaviorType>(this.GetObject("DroneAI_Behavior")); }
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
		public set(APersistentObject value) { this.SetValue("DroneAI_CurrentTargetEntity", value); }
		public get() { return view_as<APersistentObject>(this.GetObject("DroneAI_CurrentTargetEntity")); }
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
}

stock FDroneAI CreateDroneAIController(FDroneAIParams params)
{
	FDroneAI ai = view_as<FDroneAI>(new StringMap());
	if (ai)
	{
		ai.SetValue("SMap_IsDroneAI", true);
		
		ai.IsGunner = params.Gunner;
		ai.IsPilot = params.Pilot;
		ai.Behavior = params.Behavior;

		ai.IdleTime = params.IdleTime;
		ai.ThinkRate = params.ThinkRate;

		ai.SetControllerParams(params);
	}

	return ai;
}

stock FDroneAIParams CreateDefaultParamSet()
{
	FDroneAIParams params;
	params.ThinkRate = 0.1;
	params.IdleTime = 2.0;
	params.CombatTime = 4.0;
	params.SeekTime = 6.0;
	params.BurstTime = 1.0;
	params.BurstDelay = 2.0;

	return params;
}

stock FDroneAI GetSeatController(FDroneSeat seat)
{
	FDroneAI ai = null;

	if (seat.AIControlled)
	{
		ai = seat.AIOccupier;
	}

	return ai;
}
