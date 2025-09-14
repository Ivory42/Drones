#include <customdrones>

methodmap AHunterChopper < ADrone
{
	property bool IsChopper // Is this a hunter chopper drone
	{
		public get() { return view_as<bool>(this.GetObjectProp("Drone_IsChopper")); }
		public set(bool value) { this.SetObjectProp("Drone_IsChopper", value); }
	}

	public void SetModelEntity(FObject model) { this.SetArray("Chopper_Model", model, sizeof FObject); }
	public FObject GetModelEntity()
	{
		FObject model;
		this.GetArray("Chopper_Model", model, sizeof FObject);

		return model;
	}

	public void SetEngineSound(const char[] sound) { this.SetObjectPropString("Chopper_Engine", sound); }
	public void GetEngineSound(char[] sound, int size) { this.GetObjectPropString("Chopper_Engine", sound, size); }
}

methodmap APulseCannon < ADroneWeapon
{
	property bool IsPulseCannon // Is this a pulse cannon
	{
		public get() { return view_as<bool>(this.GetObjectProp("Weapon_IsPulseCannon")); }
		public set(bool value) { this.SetObjectProp("Weapon_IsPulseCannon", value); }
	}

	property float WindupTime // Time it takes for the pulse cannon to wind up before firing
	{
		public get() { return this.GetObjectPropFloat("Chopper_WindUp"); }
		public set(float value) { this.SetObjectPropFloat("Chopper_WindUp", value); }
	}

	property float FireDuration // How long a burst lasts on this cannon
	{
		public get() { return this.GetObjectPropFloat("Chopper_BurstTime"); }
		public set(float value) { this.SetObjectPropFloat("Chopper_BurstTime", value); }
	}

	property bool Charging // Pulse cannon is currently charging
	{
		public get() { return view_as<bool>(this.GetObjectProp("Chopper_IsCharging")); }
		public set(bool value) { this.SetObjectProp("Chopper_IsCharging", value); }
	}

	property bool Firing // Pulse cannon is currently firing
	{
		public get() { return view_as<bool>(this.GetObjectProp("Chopper_IsFiring")); }
		public set(bool value) { this.SetObjectProp("Chopper_IsFiring", value); }
	}

	public void SetChargeSound(const char[] sound) { this.SetObjectPropString("Chopper_ChargeSound", sound); }
	public void GetChargeSound(char[] sound, int size) { this.GetObjectPropString("Chopper_ChargeSound", sound, size); }

	public void SetDischargeSound(const char[] sound) { this.SetObjectPropString("Chopper_FireSound", sound); }
	public void GetDischargeSound(char[] sound, int size) { this.GetObjectPropString("Chopper_FireSound", sound, size); }
}
