#if defined _customdrones_types_included
 #endinput
#endif
#define _customdrones_types_included

/*
 * Enumerations for drone definitions
 */

// Projectile types to use for drone weapons. Using a type on the wrong native will use the default settings for that native
enum EProjType
{	
	DroneProj_Rocket, // Default rocket

	DroneProj_Energy, // Cow mangler rocket

	DroneProj_Sentry, // Sentry rocket salvo

	DroneProj_Impact, // Rocket which deals impact damage with no explosion



	DroneProj_Bomb, // Default bomb projectile - detonates on a fuse timer that is activated upon being spawned

	DroneProj_BombDelayed, // Fuse timer starts after touching a surface

	DroneProj_BombImpact, // Bomb detonates upon impact rather than a fuse timer

	
	
	DroneProj_Custom // Projectile type with no logic tied to it - use with custom sub plugins to define logic instead
};

// Drone move types
enum EMoveType
{
	MoveType_Helo, // Helicopter movement: hovers in the air with directional movement. Defined in configs as "drone_helo"

	MoveType_Fly, // Plane/Jet like movement: always moves forward. Defined in configs as "drone_fly"

	MoveType_Hover, // WIP - Hovercraft like movement: Hovers just above the ground and uses 8 directional movement

	MoveType_Custom // Custom movetype if defining logic in a sub plugin. Defined in configs as "drone_custom"
};


// Damage types for weapons
enum EDamageType
{
	DamageType_Generic, // Standard TF2 damage falloff settings

	DamageType_Rangeless, // No damage falloff or rampup

	DamageType_Custom // Custom Damage type - define logic within sub plugins (currently not supported with hitscan attacks)
};

// Enumeration for weapon states
enum EWeaponState
{
	WeaponState_Ready, // Reloaded and ready to fire

	WeaponState_Reloading, // Currently reloading and cannot be fired

	WeaponState_Destroyed, // Destroyed, cannot be used

	WeaponState_Custom // Custom state
};

// What type of weapon this is - Only used for hitscan attacks to determine what kind of tracer to use
enum EWeaponType
{
	WeaponType_Gun, // regular bullet tracer

	WeaponType_Laser, // Laser tracer

	WeaponType_Custom // Custom - define logic in sub plugin
};

// Enumeration for seat types
enum ESeatType
{
	Seat_Pilot, // Pilot's seat, this seat controls the vehicle's movement.

	Seat_Gunner, // Gunner seat, this seat controls the associated weapon.

	Seat_Passenger, // Passenger seat, this seat has no special function.
}