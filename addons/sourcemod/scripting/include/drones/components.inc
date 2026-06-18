#if defined _customdrones_components_included
 #endinput
#endif
#define _customdrones_components_included

#include <sdktools>
#include <tf2_stocks>
#include "dronetypes.inc"
#include "droneplayer.inc"
#include <objectmanager>

const int MaxWeapons = 4;
const int MaxSeats = 6;

methodmap AComponent < ABaseEntity
{
	property bool IsComponent
	{
		public get() { return this.GetObjectProp("Entity_IsDroneComponent"); }
		public set(bool value) { this.SetObjectProp("Entity_IsDroneComponent", value); }
	}
	property float Modifier // Extra damage this drone takes when this component is hit
	{
		public get() { return this.GetObjectProp("DroneComp.DamageModTaken"); }
		public set(float mod)	{ this.SetObjectProp("DroneComp.DamageModTaken", mod); }
	}

	property ADrone Drone // Drone this component is attached to
	{
		public get() { return view_as<ADrone>(this.GetObjectProp("DroneComp.ParentDrone")); }
		public set(ADrone value) { this.SetObjectProp("DroneComp.ParentDrone", value); }
	}

	property EComponentState ComponentState
	{
		public get() { return view_as<EComponentState>(this.GetObjectProp("DroneComp.State")); }
		public set(EComponentState state) { this.SetObjectProp("DroneComp.State", state); }
	}
}

methodmap FComponentArray < ArrayList
{
	public FComponentArray()
	{
		ArrayList array = new ArrayList(64);
		return view_as<FComponentArray>(array);
	}
	
	public void ClearComponents()
	{
		int length = this.Length;
		if (length > 0)
		{
			for (int i = 0; i < length; i++)
			{
				AComponent component = this.Get(i);
				FEntityStatics.DestroyEntity(component);
			}
		}
	}
}

enum struct FDroneWeaponExtras
{
	AComponent Mount; 		// Optional physical mount to use for the weapon. This will rotate with the player's yaw
	AComponent Parent;
	
	// Attachments
	FVector ProjOffset; 		// Fallback offset to use if this weapon has no muzzle attachment defined
	char AttachmentPoint[256]; 	// Attachment point on parent to attach this weapon to
	char MuzzleAttachment[64]; // Name of muzzle attachment for attack origination

	FObject GetMountObject()
	{
		FObject mount;
		if (this.Mount)
		{
			mount = this.Mount.GetObject();
		}

		return mount;
	}
}

methodmap ADroneWeapon < AComponent
{
	// Returns the physical prop used as the mount of this weapon.
	public FDroneWeaponExtras GetObjects()
	{
		FDroneWeaponExtras objects;
		this.GetArray("DroneWeapon.ObjProps", objects, sizeof objects);

		return objects;
	}
	public void SetObjects(FDroneWeaponExtras objects) { this.SetArray("DroneWeapon.ObjProps", objects, sizeof objects); }

	// Weapon name used in the drone UI
	public void GetDisplayName(char[] name, int size) { this.GetObjectPropString("DroneWeapon.DisplayName", name, size); }
	public void SetDisplayName(const char[] name) { this.SetObjectPropString("DroneWeapon.DisplayName", name); }

	// Weapon name used by other plugins
	public void GetInternalName(char[] name, int size) { this.GetObjectPropString("DroneWeapon.InternalName", name, size); }
	public void SetInternalName(const char[] name) { this.SetObjectPropString("DroneWeapon.InternalName", name); }

	// Weapon fire sound
	public void GetFireSound(char[] sound, int size) { this.GetObjectPropString("DroneWeapon.FireSound", sound, size); }
	public void SetFireSound(const char[] sound) { this.SetObjectPropString("DroneWeapon.FireSound", sound); }

	property ArrayList MuzzlePositions
	{
		public get() { return this.GetObjectProp("DroneWeapon.MuzzlePositions"); }
		public set(ArrayList list) { this.SetObjectProp("DroneWeapon.MuzzlePositions", list); }
	}

	property bool IsDroneWeapon
	{
		public get() { return this.GetObjectProp("Entity_IsDroneWeapon"); }
		public set(bool value) { this.SetObjectProp("Entity_IsDroneWeapon", value); }
	}

	property FDroneSeat Seat // Seat controlling this weapon
	{
		public get() { return view_as<FDroneSeat>(this.GetObjectProp("DroneWeapon.ControllingSeat")); }
		public set(FDroneSeat seat) { this.SetObjectProp("DroneWeapon.ControllingSeat", seat); }
	}

	property int Ammo // Ammo currently loaded
	{
		public get() { return this.GetObjectProp("DroneWeapon.CurrentAmmo"); }
		public set(int ammo) { this.SetObjectProp("DroneWeapon.CurrentAmmo", ammo); }
	}

	property int MaxAmmo // Max ammo loaded at once
	{
		public get() { return this.GetObjectProp("DroneWeapon.MaxAmmo"); }
		public set(int ammo) { this.SetObjectProp("DroneWeapon.MaxAmmo", ammo); }
	}

	property bool BottomlessAmmo // If true, this weapon never needs to reload
	{
		public get() { return this.GetObjectProp("DroneWeapon.NoReload"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.NoReload", value); }
	}

	property bool AILeadTargets // If true, AI controllers will attempt to lead shots with targets, if applicable
	{
		public get() { return this.GetObjectProp("DroneWeapon.AITargetPrediction"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.AITargetPrediction", value); }
	}

	property float FireRate // Weapon's firerate in rounds per second
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.RateOfFire"); }
		public set(float rof) { this.SetObjectPropFloat("DroneWeapon.RateOfFire", rof); }
	}

	property float Damage // Damage dealt by this weapon
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.Damage"); }
		public set(float damage) { this.SetObjectPropFloat("DroneWeapon.Damage", damage); }
	}

	property float BaseDamage // Base damage of this drone weapon, use this for modifiers
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.BaseDamage"); }
		public set(float damage) { this.SetObjectPropFloat("DroneWeapon.BaseDamage", damage); }
	}

	property float NextPrimaryAttack // Next gametime value when this weapon can fire again
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.NextPrimaryAttackTime"); }
		public set(float time) { this.SetObjectPropFloat("DroneWeapon.NextPrimaryAttackTime", time); }
	}

	property float Inaccuracy // Error in angle for this weapon upon consecutive attacks
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.SpreadError"); }
		public set(float error) { this.SetObjectPropFloat("DroneWeapon.SpreadError", error); }
	}

	property float ReloadDelay // How long this weapon takes to reload
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.ReloadTime"); }
		public set(float time) { this.SetObjectPropFloat("DroneWeapon.ReloadTime", time); }
	}

	property STimer ReloadTimer // Timer used for reloading
	{
		public get() { return view_as<STimer>(this.GetObjectProp("DroneWeapon.ReloadTimer")); }
		public set(STimer timer) { this.SetObjectProp("DroneWeapon.ReloadTimer", timer); }
	}

	property EWeaponState State // Current state of this weapon
	{
		public get() { return view_as<EWeaponState>(this.GetObjectProp("DroneWeapon.State")); }
		public set(EWeaponState state) { this.SetObjectProp("DroneWeapon.State", state); }
	}

	property EWeaponType Type // Weapon type. Determines the type of projectile (if applicable) fired by this weapon
	{
		public get() { return view_as<EWeaponType>(this.GetObjectProp("DroneWeapon.Type")); }
		public set(EWeaponType type) { this.SetObjectProp("DroneWeapon.Type", type); }
	}

	property float TurnRate // How quickly this weapon rotates towards the player's view if using a model
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.TurnRate"); }
		public set(float rate) { this.SetObjectPropFloat("DroneWeapon.TurnRate", rate); }
	}

	property int MuzzleIndex // Current muzzle index to use for next attack
	{
		public get() { return this.GetObjectProp("DroneWeapon.MuzzleID"); }
		public set(int value) { this.SetObjectProp("DroneWeapon.MuzzleID", value); }
	}

	property bool Disabled
	{
		public get() { return this.GetObjectProp("DroneWeapon.Disabled"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.Disabled", value); }
	}

	property float MaxPitch // Max pitch this weapon can aim at (relative to drone)
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.MaxPitchAngle"); }
		public set(float pitch) { this.SetObjectPropFloat("DroneWeapon.MaxPitchAngle", pitch); }
	}
	property float MinPitch // Min pitch this weapon can aim at (relative to drone)
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.MinPitchAngle"); }
		public set(float pitch) { this.SetObjectPropFloat("DroneWeapon.MinPitchAngle", pitch); }
	}

	property float MaxFirePitch // Max pitch this weapon can fire at (relative to weapon)
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.MaxPitchFireAngle"); }
		public set(float pitch) { this.SetObjectPropFloat("DroneWeapon.MaxPitchFireAngle", pitch); }
	}
	property float MinFirePitch // Min pitch this weapon can fire at (relative to weapon)
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.MinPitchFireAngle"); }
		public set(float pitch) { this.SetObjectPropFloat("DroneWeapon.MinPitchFireAngle", pitch); }
	}

	property float MaxYaw // Max yaw value this weapon can aim at (relative to drone)
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.MaxYawAngle"); }
		public set(float yaw) { this.SetObjectPropFloat("DroneWeapon.MaxYawAngle", yaw); }
	}
	property float MinYaw // Min yaw value this weapon can aim at (relative to drone)
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.MinYawAngle"); }
		public set(float yaw) { this.SetObjectPropFloat("DroneWeapon.MinYawAngle", yaw); }
	}

	property float MaxFireYaw // Max yaw value this weapon can fire at (relative to weapon)
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.MaxYawFireAngle"); }
		public set(float yaw) { this.SetObjectPropFloat("DroneWeapon.MaxYawFireAngle", yaw); }
	}
	property float MinFireYaw // Min yaw value this weapon can fire at (relative to weapon)
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.MinYawFireAngle"); }
		public set(float yaw) { this.SetObjectPropFloat("DroneWeapon.MinYawFireAngle", yaw); }
	}

	property bool Fixed // If true, this weapon will not rotate with the player's view angles
	{
		public get() { return this.GetObjectProp("DroneWeapon.FixedAngles"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.FixedAngles", value); }
	}

	property bool FixedTrajectory // If true, projectiles fired from this weapon will use the weapon's angles
	{
		public get() { return this.GetObjectProp("DroneWeapon.FixedTrajectoryAngles"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.FixedTrajectoryAngles", value); }
	}

	// Whether or not this weapon looks for attachments on the parent instead of the weapon's model.
	property bool UsesParent
	{
		public get() { return this.GetObjectProp("DroneWeapon.HasNoModel"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.HasNoModel", value); }
	}

	property bool ComplexAngles // If true, this weapon's angles will be properly distributed between the mount and the weapon model
	{
		public get() { return this.GetObjectProp("DroneWeapon.ComplexAngles"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.ComplexAngles", value); }
	}

	property int ProjPerShot // How many projectiles (or bullets) this weapon fires per attack
	{
		public get() { return this.GetObjectProp("DroneWeapon.PerShot"); }
		public set(int value) { this.SetObjectProp("DroneWeapon.PerShot", value); }
	}

	property bool HidesReticle // If true, hide the reticle while this weapon is active
	{
		public get() { return this.GetObjectProp("DroneWeapon.HideSeatReticle"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.HideSeatReticle", value); }
	}

	property ELockOnType LockOnType // Weapon lock on type
	{
		public get() { return view_as<ELockOnType>(this.GetObjectProp("DroneWeapon.LockOnType")); }
		public set(ELockOnType type) { this.SetObjectProp("DroneWeapon.LockOnType", type); }
	}

	public FRotator GetDefaultAngle()
	{
		return this.GetObjectPropRotator("DroneWeapon.DefaultAngles");
	}
	public void SetDefaultAngle(FRotator angle)
	{
		this.SetObjectPropRotator("DroneWeapon.DefaultAngles", angle);
	}

	// Returns the receiver object for this weapon
	public FObject GetReceiver()
	{
		return this.GetObject();
	}

	// Returns the mount of the receiver of this weapon
	public FObject GetMount()
	{
		return this.GetObjects().GetMountObject();
	}

	// Returns the parent object of this weapon
	public AComponent GetParent()
	{
		return this.GetObjects().Parent;
	}

	/*
	 * Called whenever a weapon is fired from a sub plugin.
	 * Handles ammo and initiating reloads on drone weapons
	 * 
	 * @param action     Action to handle ammo management (See OnDroneAttack forward)
	 * @param decrease   Ammo to decrease by if Plugin_Changed is passed
	 */
	public void SimulateFire(Action action, int decrease)
	{
		this.NextPrimaryAttack = GetGameTime() + this.FireRate; // Reset firerate

		bool skip = false; // Skip reload check

		// Never reload if we don't have a clip size
		if (this.Ammo == -1)
			return;

		// Determine how we handle ammo counts - Plugin_Continue decrements ammo by one. Plugin_Changed reduces ammo by the given amount
		switch (action)
		{
			case Plugin_Continue: this.Ammo--;
			case Plugin_Changed: this.Ammo -= decrease;
			default: skip = true;
		}

		if (!skip && this.Ammo == 0)
			this.SimulateReload();

		char firesound[64];
		this.GetFireSound(firesound, sizeof firesound);

		if (strlen(firesound) > 3)
		{
			PrecacheSound(firesound);
			if (this.Valid()) // Need to change this check
				EmitSoundToAll(firesound, this.Get(), SNDCHAN_AUTO, 90); //emit from weapon if physical entity exists
			else
				EmitSoundToAll(firesound, this.GetParent().Get(), SNDCHAN_AUTO, 90); //otherwise just emit from the drone
		}
	}

	public void DisableWeapon()
	{
		this.Disabled = true;
	}

	public void EnableWeapon()
	{
		this.Disabled = false;
	}
	
	// Weapon tick event. Only used in core weapons plugin, do not call manually.
	public void Simulate()
	{
		if (this.ReloadTimer.Expired() && this.Ammo == 0 && this.State == WeaponState_Reloading)
		{
			this.Ammo = this.MaxAmmo;
			this.State = WeaponState_Ready;
		}
	}

	// Reloads this weapon.
	public void SimulateReload()
	{
		if (this.Ammo < this.MaxAmmo)
		{
			this.Ammo = 0;
			this.ReloadTimer.Loop();
			this.State = WeaponState_Reloading;
		}
	}

	/* 
	 * Returns whether or not this weapon can be fired
	 *
	 * @param force     If true, force this weapon to fire as long as it's active and has ammo
	 */
	public bool CanFire(bool force = false)
	{
		if (this.Drone.Stunned || this.Disabled)
		{
			return false;
		}
		
		if (force) //ignore attack delay
			return (this.Ammo != 0 && this.State == WeaponState_Ready);

		else if (this.Ammo != 0 && this.NextPrimaryAttack <= GetGameTime() && this.State == WeaponState_Ready)
			return true;

		return false;
	}

	// Retrieves the relative position of this weapon
	public FVector GetRelativePosition()
	{
		FVector position;

		position = this.GetReceiver().GetRelativePosition();

		return position;
	}

	// Returns the world position of this weapon
	public FVector GetWorldPosition()
	{
		FVector position;

		position = this.GetReceiver().GetPosition();

		return position;
	}

	public FObject GetMuzzle(int index)
	{
		FObject muzzle;
		if (this.MuzzlePositions && this.MuzzlePositions.Length > index)
		{
			this.MuzzlePositions.GetArray(index, muzzle, sizeof FObject);
		}

		return muzzle;
	}

	public int GetMuzzleCount()
	{
		char muzzles[16][64];
		int muzzleCount = ExplodeString(this.GetObjects().MuzzleAttachment, ";", muzzles, sizeof muzzles, sizeof muzzles[]);

		return muzzleCount;
	}

	public int GetMuzzleCountEx(char[][] muzzles, int size, int length)
	{
		int muzzleCount = ExplodeString(this.GetObjects().MuzzleAttachment, ";", muzzles, size, length);

		return muzzleCount;
	}

	// returns the physical attachment point from the weapon/drone model
	public bool GetMuzzleAttachment(char[] attachment, int size)
	{
		char muzzles[16][64];
		int muzzleCount = this.GetMuzzleCountEx(muzzles, sizeof muzzles, sizeof muzzles[]);
		if (muzzleCount > 1)
		{
			int index = this.MuzzleIndex;
			FormatEx(attachment, size, muzzles[index])
			this.MuzzleIndex++;
			if (this.MuzzleIndex >= muzzleCount)
				this.MuzzleIndex = 0;

			return true;
		}
		else if (strlen(this.GetObjects().MuzzleAttachment) > 1)
		{
			// Only one attachment
			FormatEx(attachment, size, this.GetObjects().MuzzleAttachment);

			return true;
		}
		
		return false;
	}

	// Gets the physical location of the next muzzle in sequence
	public bool GetMuzzleTransform(FTransform muzzle)
	{
		// Retrieve the muzzle attachment according to the attachment point. If we have multiple attachments, alternate between all of them
		char attachment[64];
		this.GetMuzzleAttachment(attachment, sizeof attachment);

		if (this.UsesParent)
		{
			return GetAttachmentTransform(this.GetParent().GetObject(), attachment, muzzle);
		}

		return GetAttachmentTransform(this.GetReceiver(), attachment, muzzle);
	}

	// Returns the spawn location for the next muzzle in sequence
	public bool GetNextMuzzleTransform(FTransform spawn)
	{
		if (this.MuzzlePositions)
		{
			FObject muzzle;
			int length = this.MuzzlePositions.Length;
			if (length > 0)
			{
				if (this.MuzzleIndex >= length)
					this.MuzzleIndex = 0;

				int index = this.MuzzleIndex;
				muzzle.Reference = this.MuzzlePositions.Get(index);
				spawn.Position = muzzle.GetPosition();

				this.MuzzleIndex++;

				return true;
			}
			else
			{
				char name[64];
				this.GetDisplayName(name, sizeof name);
				LogMessage("No muzzle positions found for weapon %s!", name);
			}
		}

		return false;
	}

	public void Destroy()
	{
		// Clear our muzzle attachments
		if (this.MuzzlePositions)
		{
			int length = this.MuzzlePositions.Length;
			for (int i = 0; i < length; i++)
			{
				FObject muzzle;
				muzzle.Reference = this.MuzzlePositions.Get(i);

				if (muzzle.Valid())
				{
					muzzle.Kill();
				}
			}
			delete this.MuzzlePositions;
		}

		// If this drone has a mount, destroy it
		//AComponent mount = this.GetObjects.Mount;
		//if (mount)
		//{
		//	FEntityStatics.DestroyEntity(mount);
		//}

		// Remove this weapon from the given seat
		/*
		ADrone parent = view_as<ADrone>(this.GetParent())
		if (parent.IsDrone)
		{
			FDroneSeat seat = GetPilotSeat(parent);
			if (seat && seat.Valid())
			{
				int weapons = seat.Weapons.Length;
				for (int i = 0; i < weapons; i++)
				{
					if (seat.Weapons.Get(i) == this)
						seat.Weapons.Erase(i);
				}
			}
		}
		*/
	}
}

methodmap ADroneProjectileWeapon < ADroneWeapon
{
	property float ProjectileSpeed // How fast a projectile from this weapon should be fired, if used
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.ProjectileSpeed"); }
		public set(float speed) { this.SetObjectPropFloat("DroneWeapon.ProjectileSpeed", speed); }
	}
	property EProjType ProjType // What type of projectile this weapon fires
	{
		public get() { return view_as<EProjType>(this.GetObjectPropFloat("DroneWeapon.ProjectileType")); }
		public set(EProjType type) { this.SetObjectProp("DroneWeapon.ProjectileType", type); }
	}

	property bool LocksOn // If true, this weapon can lock on to other drones
	{
		public get() { return this.GetObjectProp("DroneWeapon.CanLockOn"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.CanLockOn", value); }
	}

	property bool RequiresLockOn // If true, this weapon must lock on to fire
	{
		public get() { return this.GetObjectProp("DroneWeapon.RequiresLockOn"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.RequiresLockOn", value); }
	}

	property bool IsLockedOn // Whether or not this weapon is locked on
	{
		public get() { return this.GetObjectProp("DroneWeapon.IsLockedOn"); }
		public set(bool value) { this.SetObjectProp("DroneWeapon.IsLockedOn", value); }
	}

	property float LockOnProgress
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.LockOnProgress"); }
		public set(float value) { this.SetObjectPropFloat("DroneWeapon.LockOnProgress", value); }
	}

	property float LockOnTime // Time it takes for this weapon to confirm a lock on target
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.LockOnTime"); }
		public set(float value) { this.SetObjectPropFloat("DroneWeapon.LockOnTime", value); }
	}

	property float HomingVelocity // Speed at which fired projectile home in on targets
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.HomingVelocity"); }
		public set(float value) { this.SetObjectPropFloat("DroneWeapon.HomingVelocity", value); }
	}

	property float HomingDelay // Delay before the fired projectile will begin homing
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.HomingDelay"); }
		public set(float value) { this.SetObjectPropFloat("DroneWeapon.HomingDelay", value); }
	}

	property float HomingMaxAngle // Max homing angle of fired projectiles
	{
		public get() { return this.GetObjectPropFloat("DroneWeapon.HomingMaxAngle"); }
		public set(float value) { this.SetObjectPropFloat("DroneWeapon.HomingMaxAngle", value); }
	}

	public FRotator GetTrajectoryOffset()
	{
		return this.GetObjectPropRotator("DroneWeapon.TrajectoryOffset");
	}
	public void SetTrajectoryOffset(FRotator angle)
	{
		this.SetObjectPropRotator("DroneWeapon.TrajectoryOffset", angle);
	}

	public void SetLockReticle(FObject reticle)
	{
		this.SetObjectPropEnt("DroneWeapon.LockOnReticle", reticle);
	}
	public FObject GetLockReticle()
	{
		return this.GetObjectPropEnt("DroneWeapon.LockOnReticle");
	}

	public void SetLockTickSound(const char[] sound)
	{
		this.SetString("DroneWeapon.LockOnTickSound", sound);
	}
	public void GetLockTickSound(char[] sound, int size)
	{
		this.GetString("DroneWeapon.LockOnTickSound", sound, size);
	}

	public void SetLockSuccessSound(const char[] sound)
	{
		this.SetString("DroneWeapon.LockOnSuccessSound", sound);
	}
	public void GetLockSuccessSound(char[] sound, int size)
	{
		this.GetString("DroneWeapon.LockOnSuccessSound", sound, size);
	}

	public void SetLockFailureSound(const char[] sound)
	{
		this.SetString("DroneWeapon.LockOnFailureSound", sound);
	}
	public void GetLockFailureSound(char[] sound, int size)
	{
		this.GetString("DroneWeapon.LockOnFailureSound", sound, size);
	}
}


/*
* Map holding information on a drone seat
* Seats do not have models and are not true components, they only hold position information,
* what the occupier of this seat can do, and whether or not the occupier can be seen.
*
* Drones may have up to 6 seats max.
*/
methodmap FDroneSeat < StringMap
{
	public FDroneSeat()
	{
		StringMap seat = new StringMap();
		seat.SetValue("IsDroneSeat", true);

		return view_as<FDroneSeat>(seat);
	}

	public bool Valid()
	{
		bool valid = false;
		this.GetValue("IsDroneSeat", valid);

		return valid;
	}

	property bool AIControlled // Is this seat currently controlled by an AI actor
	{
		public get()
		{
			bool result = false;
			this.GetValue("SeatControlledByAI", result);

			return result;
		}
		public set(bool value) { this.SetValue("SeatControlledByAI", value); }
	}

	property FDroneAI AIOccupier
	{
		public get()
		{
			FDroneAI ai;
			this.GetValue("AIControllerObject", ai);

			return ai;
		}
		public set(FDroneAI ai) { this.SetValue("AIControllerObject", ai); }
	}

	property ADronePlayer Occupier // Client occupying this seat
	{
		public get()
		{
			ADronePlayer client;
			this.GetValue("ClientInSeat", client);

			return client;
		}
		public set(ADronePlayer client) { this.SetValue("ClientInSeat", client); }
	}

	property bool Occupied // Whether or not this seat already has a client occupying it
	{
		public get()
		{
			bool value = false;
			this.GetValue("SeatTaken", value);

			return value;
		}
		public set(bool value) { this.SetValue("SeatTaken", value); }
	}

	property ADrone Drone // Drone this seat is attached to
	{
		public get()
		{
			ADrone drone;
			this.GetValue("SeatConnectedDrone", drone);

			return drone;
		}
		public set(ADrone drone) { this.SetValue("SeatConnectedDrone", drone); }
	}

	property ESeatType Type // What type of seat this is, defines what the client occupying this seat can do.
	{
		public get()
		{
			ESeatType type;
			this.GetValue("SeatType", type);

			return type;
		}
		public set(ESeatType type) { this.SetValue("SeatType", type); }
	}

	property FComponentArray Weapons // Array of weapons this seat has access to use
	{
		public get()
		{
			FComponentArray weapons;
			this.GetValue("ValidWeaponGroup", weapons);

			return weapons;
		}
		public set(FComponentArray weapons) { this.SetValue("ValidWeaponGroup", weapons); }
	}

	property ADroneWeapon ActiveWeapon // Current weapon this seat is using
	{
		public get()
		{
			ADroneWeapon weapon;
			this.GetValue("ActiveWeapon", weapon);

			return weapon;
		}
		public set(ADroneWeapon weapon) { this.SetValue("ActiveWeapon", weapon); }
	}

	property int ActiveWeaponIndex // Current index in the array of weapons being used
	{
		public get()
		{
			int index = -1;
			this.GetValue("WeaponIndex", index);

			return index;
		}
		public set(int index) { this.SetValue("WeaponIndex", index); }
	}

	property float NextSwitchTime // Time when this seat can change weapons again
	{
		public get()
		{
			float time = 0.0;
			this.GetValue("NextSwitchTime", time);

			return time;
		}
		public set(float time) { this.SetValue("NextSwitchTime", time); }
	}

	property bool UsePlayerModel
	{
		public get()
		{
			bool value = false;
			this.GetValue("UsePlayerModel", value);

			return value;
		}
		public set(bool value) { this.SetValue("UsePlayerModel", value); }
	}

	property bool FirstPerson
	{
		public get()
		{
			bool value = false;
			this.GetValue("UseFirstPersonView", value);

			return value;
		}
		public set(bool value) { this.SetValue("UseFirstPersonView", value); }
	}

	property AComponent AttachedComponent
	{
		public get()
		{
			FObject comp;
			this.GetArray("ComponentAttachedTo", comp, sizeof FObject);

			return view_as<AComponent>(FEntityStatics.GetEntity(comp));
		}
		public set(AComponent comp)
		{
			this.SetArray("ComponentAttachedTo", comp.GetObject(), sizeof FObject);
		}
	}

	public void SetReticle(FObject reticle)
	{
		this.SetArray("WeaponReticle", reticle, sizeof FObject);
	}
	public FObject GetReticle()
	{
		FObject reticle;
		this.GetArray("WeaponReticle", reticle, sizeof FObject);

		return reticle;
	}

	public void SetPlayerAnim(const char[] sequence)
	{
		this.SetString("PlayerAnimation", sequence);
	}
	public void GetPlayerAnim(char[] sequence, int size)
	{
		this.GetString("PlayerAnimation", sequence, size);
	}

	public void SetAttachPoint(const char[] attach)
	{
		this.SetString("SeatAttachPointName", attach);
	}
	public void GetAttachPoint(char[] attach, int size)
	{
		this.GetString("SeatAttachPointName", attach, size);
	}

	public void SetPlayerModel(FObject model)
	{
		this.SetArray("SeatPlayerModel", model, sizeof FObject);
	}
	public FObject GetPlayerModel()
	{
		FObject model;
		this.GetArray("SeatPlayerModel", model, sizeof FObject);
		
		return model;
	}

	public FObject GetCamera()
	{
		FObject camera;
		this.GetArray("SeatCamera", camera, sizeof FObject);

		return camera;
	}
	public void SetCamera(FObject camera)
	{
		this.SetArray("SeatCamera", camera, sizeof FObject);
	}

	// Returns the relative position of this seat on the drone
	public FVector GetSeatPosition()
	{
		FVector result;
		this.GetArray("SeatAttachPoint", result, sizeof FVector);

		return result;
	}
	public void SetSeatPosition(FVector position) { this.SetArray("SeatAttachPoint", position, sizeof FVector); }

	public FRotator GetSeatRotation()
	{
		FRotator rotation;
		this.GetArray("SeatRotationOffset", rotation, sizeof FRotator);

		return rotation;
	}
	public void SetSeatRotation(FRotator rotation) { this.SetArray("SeatRotationOffset", rotation, sizeof FRotator); }

	public FVector GetCameraOffset()
	{
		FVector offset;
		this.GetArray("CameraOffset", offset, sizeof FVector);

		return offset;
	}
	public void SetCameraOffset(FVector offset)
	{
		this.SetArray("CameraOffset", offset, sizeof FVector);
	}

	// Returns true if this seat has an active weapon
	public bool HasWeapon()
	{
		if (this.Type == Seat_Passenger) // Passenger seats have no weapons
			return false;
		
		if (this.ActiveWeapon)
		{
			//PrintToConsoleAll("%x has weapon %x", this, this.ActiveWeapon);
		}
		else
		{
			//PrintToConsoleAll("%x has no weapons!", this);
		}
		return (this.ActiveWeapon != null);
	}

	public void ClearComponents()
	{
		if (this.AIControlled && this.AIOccupier)
		{
			delete this.AIOccupier;
		}
		if (this.GetCamera().Valid())
		{
			this.GetCamera().Kill();
		}
	}
}


/*****************************************
		STOCKS

******************************************/

stock AComponent CreateComponent(const char[] classname)
{
	AComponent component = view_as<AComponent>(FEntityStatics.CreateEntity(classname));
	component.IsComponent = true;

	return component;
}

stock AComponent CastToComponent(ABaseEntity entity)
{
	AComponent component = null;
	if (entity && entity.GetObjectProp("Entity_IsDroneComponent"))
	{
		component = view_as<AComponent>(entity);
	}

	return component;
}

/*
* Quickly creates a new component for usage by a drone. If you need to set parameters before the component is spawned, use CreateDeferredComponent() instead
*
* @param classname		Classname of the entity this component should be created as
* 
* @return				Component struct containing the entity
*
stock FComponent CreateNewComponent(const char[] classname)
{
	FComponent component;
	component.Reference.Create(classname);

	component.Reference.Spawn();
	return component;
}*/

/*
* Creates a new component but does not spawn it. Call FinishComponent() when ready to use.
*
* @param classname		Classname of the entity this component should be created as
* 
* @return				Component struct containing the entity
*
stock FComponent CreateDeferredComponent(const char[] classname)
{
	FComponent component;
	component.Reference.Create(classname);

	return component;
}

// Finishes setup of a deferred component and spawns it
stock void FinishComponent(FComponent component)
{
	FObject reference;
	reference = component.GetObject();

	reference.Spawn();
	reference.Activate();
}*/

/**
 * Returns an FComponent object reference from the given entity index
 * 
 * @param entityId     Entity index to use as this component's FObject reference
 * @return             FComponent containing a reference to the given entity
 *
stock FComponent GetComponentFromEntity(int entityId)
{
	FComponent component;
	component.Reference = ConstructObject(entityId);

	return component;
}*/