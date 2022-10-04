# Custom Drones for TF2

## 10/2022: I plan to completely rewrite this plugin somewhat soon. It's currently stable but the code really needs to be cleaned up.

Spawnable drones that can be piloted by the player that owns it. There is an example drone under `configs/drones/example_drone.txt`. Drone plugins are placed under `plugins/drones/` and a template can be found under `scripting/drones/example_drone.sp`.

## Commands

  - `sm_drone`- Opens a menu with all available drones (root flag required by default)

## Features
  - Configuration files so you can make your own custom drones
  - Create your own logic for drones through other plugins (example included)
  - Define a model and destroyed model for each drone
  - Set health, speed, and acceleration for each drone
  - Set up to 6 weapons with individual parameters
  - Choose how the drone operates:
    - Flying
    - Hover
    - Ground


### Flying Drones
  - Flying drones move in the direction the camera is facing
  - Cannot fly below specific speeds
  - More agile than other drones

### Hover Drones
  - Hover drones can fly and move in any direction
  - Movement input controls drone movement
  - More combat oriented

### Ground Drones (WIP)
  - Drones limited to ground movement
  - Not functioning at this time

## Developers
This plugin comes with several forwards and natives to use with other plugins. Refer to `scripting/include/customdrones.inc` for more detailed explanations.

### Natives
  - `CD_ToggleViewLocked` - Unlock/Lock a drone to the player's view angles
  - `CD_SpawnDroneByName` - Spawns a drone for a client from the given config name
  - `CD_SetWeaponReloading` - Initiates a reload sequence on the given weapon for a drone
  - `CD_GetDroneWeapon` - Retrieves the weapon object from the given slot
  - `CD_GetDroneActiveWeapon` - Retrieves the active weapon object and its slot for the given drone
  - `CD_IsValidDrone` - Checks a given entity to see if it is a drone or not
  - `CD_SpawnRocket` - Spawns and prepares a rocket to be used as a base projectile
  - `CD_SpawnDroneBomb` - Spawns a custom bomb entity to be dropped from drones
  - `CD_FireBullet` - Fires a hitscan attack from the drone
  - `CD_GetParamFloat` - Retrieves a float parameter from a drone's config file
  - `CD_GetParamInteger` - Retrieves an integer parameter from a drone's config file
  - `CD_GetParamString` - Retrieves a string parameter from a drone's config file
  - `CD_GetCameraHeight` - Retrieves the vertical offset of a drone's view camera
  - `CD_DroneTakeDamage` - Damages a drone and sends a damage event to the attacker
  - `CD_OverrideMaxSpeed` - Overrides the max speed for the given drone
  - `CD_GetClientDrone` - Retrieves the given client's drone object if currently piloting one

### Forwards
  - `CD_OnDroneCreated` - Called when a drone initially spawns
  - `CD_OnDroneDestroyed` - Called when a drone is destroyed
  - `CD_OnDroneRemoved` - Called when a drone is removed from the world after being destroyed
  - `CD_OnWeaponChanged` - Called when a player cycles weapons on a drone
  - `CD_OnDroneAttack` - Called when a drone fires its active weapon
  - `CD_OnPlayerEnterDrone` - Called when a player enters a drone
  - `CD_OnPlayerExitDrone` - Called when a player exits a drone


## Known Issues
  - Drones can phase through geometry at certain speeds
  - Ground based drones are not properly tested/functioning at this time


## Planned Featurs
  - Native support abilities (healing, ammo regeneration, etc)
  - Multiple move type modes for ground based drones
