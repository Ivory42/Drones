#if defined _customdrones_drone_included
 #endinput
#endif
#define _customdrones_drone_included

#include "drones/components.inc"
//#include <drones/rocket>
//#include <drones/bomb>
#include <sdkhooks>

enum struct FDroneComponents
{
	FObject Camera; // Entity reference of the camera for this drone
	FObject Model; // Visual model to use for this drone. Spawns as a dynamic prop attached to the drone's collision.

	char DestroyedModel[256]; 		// Optional model to use when drone is destroyed
}

methodmap ADrone < AComponent
{
	public FDroneComponents GetComponents()
	{
		FDroneComponents components;
		this.GetArray("Drone_Components", components, sizeof components);

		return components;
	}
	public void SetComponents(FDroneComponents components) { this.SetArray("Drone_Components", components, sizeof components); }

	public void GetDisplayName(char[] name, int size) { this.GetObjectPropString("Drone_DisplayName", name, size); }
	public void SetDisplayName(const char[] name) { this.SetObjectPropString("Drone_DisplayName", name); }

	public void GetInternalName(char[] name, int size) { this.GetObjectPropString("Drone_InternalName", name, size); }
	public void SetInternalName(const char[] name)	{ this.SetObjectPropString("Drone_InternalName", name); }

	// Name of the config file used for creating this drone. This is the filename inside the global config directory
	public void GetConfig(char[] name, int size) { this.GetObjectPropString("Drone_ConfigurationFile", name, size); }
	public void SetConfig(const char[] name) { this.SetObjectPropString("Drone_ConfigurationFile", name); }

	public FVector GetInputVelocity() { return this.GetObjectPropVector("Drone_InputVel"); }
	public void SetInputVelocity(FVector vel) { this.SetObjectPropVector("Drone_InputVel", vel); }

	public FObject GetCamera() { return this.GetComponents().Camera; }

	property bool IsDrone
	{
		public get() { return this.GetObjectProp("Entity_IsDrone"); }
		public set(bool value) { this.SetObjectProp("Entity_IsDrone", value); }
	}

	property ADronePlayer Pilot // Client currently piloting this drone
	{
		public get() { return view_as<ADronePlayer>(this.GetObjectProp("Drone_Pilot")); }
		public set(ADronePlayer client) { this.SetObjectProp("Drone_Pilot", client); }
	}

	property float CameraHeight // Camera height for this drone. Controls where traces will begin for drone attacks/functions
	{
		public get() { return this.GetObjectPropFloat("Drone_CameraHeight"); }
		public set(float height) { this.SetObjectPropFloat("Drone_CameraHeight", height); }
	}

	/*
	*	Drone Stats
	*/

	property bool Alive // Is this drone still functioning and able to move about
	{
		public get() { return this.GetObjectProp("Drone_IsAlive"); }
		public set(bool alive) { this.SetObjectProp("Drone_IsAlive", alive); }
	}

	property float MaxSpeed // Max speed this drone can move at
	{
		public get() { return this.GetObjectPropFloat("Drone_MaxMoveSpeed"); }
		public set(float speed) { this.SetObjectPropFloat("Drone_MaxMoveSpeed", speed); }
	}

	property float Acceleration // Rate at which this drone can accelerate when moving. This also affects deceleration
	{
		public get() { return this.GetObjectPropFloat("Drone_Acceleration"); }
		public set(float accel) { this.SetObjectPropFloat("Drone_Acceleration", accel); }
	}

	property float TurnRate // How fast this drone rotates towards the player's view angles
	{
		public get() { return this.GetObjectPropFloat("Drone_MaxTurnRate"); }
		public set(float rate) { this.SetObjectPropFloat("Drone_MaxTurnRate", rate); }
	}

	/*
	* 	Drone Function
	*/

	property FComponentArray Weapons
	{
		public get() { return view_as<FComponentArray>(this.GetObjectProp("Drone_Weapons")); }
		public set(FComponentArray weapons) { this.SetObjectProp("Drone_Weapons", weapons); }
	}

	property ArrayList Seats
	{
		public get() { return view_as<ArrayList>(this.GetObjectProp("Drone_Seats")); }
		public set(ArrayList seats) { this.SetObjectProp("Drone_Seats", seats); }
	}

	public bool Occupied() // Likely wont be used, will be checked on a per seat basis instead
	{
		if (this.Seats.Length > 0)
		{
			FDroneSeat seat = GetPilotSeat(this);
			if (!seat)
				return true;
			
			return seat.Occupied;
		}

		return false;
	}

	property bool UsePlayerAngles // If true, this drone will rotate towards the pilot's view angles
	{
		public get() { return this.GetObjectProp("Drone_LockAngles"); }
		public set(bool lock) { this.SetObjectProp("Drone_LockAngles", lock); }
	}

	property EMoveType MoveType // Movement type of this drone. Determines how the drone will behave when piloted.
	{
		public get() { return view_as<EMoveType>(this.GetObjectProp("Drone_MovementMode")); }
		public set(EMoveType type) { this.SetObjectProp("Drone_MovementMode", type); }
	}

	property float LastFrameYaw
	{
		public get() { return this.GetObjectPropFloat("Drone_LastYaw"); }
		public set(float val) { this.SetObjectPropFloat("Drone_LastYaw", val); }
	}

	property float CurrentFrameYaw
	{
		public get() { return this.GetObjectPropFloat("Drone_YawValue"); }
		public set(float val) { this.SetObjectPropFloat("Drone_YawValue", val); }
	}

	property float RollValue
	{
		public get() { return this.GetObjectPropFloat("Drone_RollValue"); }
		public set(float val) { this.SetObjectPropFloat("Drone_RollValue", val); }
	}

	// Clears this drone's reference
	public void Destroy()
	{
		FDroneComponents components;
		components = this.GetComponents();

		if (components.Camera.Valid())
			components.Camera.Kill();

		if (components.Model.Valid())
			components.Model.Kill();

		if (this.Seats)
		{
			//ClearSeats(this.Seats);
			delete this.Seats;
		}

		if (this.Weapons)
		{
			this.Weapons.ClearArray();
			delete this.Weapons;
		}
	}

}
