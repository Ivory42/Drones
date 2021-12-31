# Custom Drones for TF2
Spawnable drones that can be piloted by the player that owns it. There is an example drone under `configs/drones/example_drone.txt`. Drone plugins are placed under `plugins/drones/` and a template can be found under `scripting/drones/example_drone.sp`.

## Commands

  - `sm_drone`- Opens a menu with all available drones (root flag required by default)

## Features
  - Configuration files so you can make your own custom drones
  - Create your own logic for drones through other plugins (example included)
  - Define a model and destroyed model for each drone
  - Set health, speed, and acceleration for each drone
  - Set up to 4 weapons with individual parameters
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
  - `CD_GetDroneHealth` - Returns the current health of the given drone
  - `CD_GetDroneMaxHealth` - Returns the maximum health of the given drone
  - `CD_SpawnDroneByName` - Spawns a drone for a client from the given config name
  - `CD_GetDroneActiveWeapon` - Returns the index of the current weapon for a given drone
  - `CD_SetWeaponReloading` - Initiates a reload sequence on the given weapon for a drone
  - `CD_IsValidDrone` - Checks a given entity to see if it is a drone or not
  - `CD_SpawnRocket` - Spawns and prepares a rocket to be used as a base projectile - highly configurable
  - `CD_GetParamFloat` - Retrieves a float parameter from a drone's config file
  - `CD_GetParamInteger` - Retrieves an integer parameter from a drone's config file
  - `CD_GetCameraHeight` - Retrieves the vertical offset of a drone's view camera
  - `CD_DroneTakeDamage` - Damages a drone and sends a damage event to the attacker

### Forwards
  - `CD_OnDroneCreated` - Called when a drone initially spawns
  - `CD_OnDroneDestroyed` - Called when a drone is destroyed
  - `CD_OnDroneRemoved` - Called when a drone is removed from the world after being destroyed
  - `CD_OnWeaponChanged` - Called when a player cycles weapons on a drone
  - `CD_OnDroneAttack` - Called when a player presses their attack key while piloting a drone


## Known Issues
  - Drones can phase through geometry at certain speeds
  - Ground based drones are not properly tested/functioning at this time
  - Flying drones turn too sharply


## Planned Featurs
  - Native hitscan attack
  - Native support abilities (healing, ammo regeneration, etc)
  - Multiple move type modes for ground based drones
  - Possible custom lag compensation
