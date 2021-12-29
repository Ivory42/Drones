# Custom Drones for TF2
Spawnable drones that can be piloted by the player that owns it. There is an example drone under `configs/drones/example_drone.txt`. Drone plugins are placed under `plugins/drones/` and a template can be found under `scripting/drones/example_drone.sp`.

## Commands

  - `sm_drone`- Opens a menu with all available drones (root flag required by default)

## Features
  - Configuration files so you can make your own custom drones
  - Create your own logic for drones through other plugins (example included)
  - Define a model and destroyed model for each drone
  - Set health, speed, and acceleration for each drone
  - Choose how the drone operates:
    - Fly
    - Hover
    - Ground


### Flying Drones (WIP)
  - Flying drones can only move forward
  - Requires constant movement to stay in the air
  - More agile than other drones

### Hover Drones
  - Hover drones can fly and move in any direction
  - Will remain airborn even with no movement
  - More combat oriented

### Ground Drones (WIP)
  - Drones limited to ground movement
  - Can only move forward and/or rotate while moving forward

## Developers
This plugin comes with several forwards and natives to use with other plugins. Refer to `scripting/include/customdrones.inc` for more detailed explanations.

### Natives
  - `CD_GetDroneHealth` - Returns the current health of the given drone
  - `CD_GetDroneMaxHealth` - Returns the maximum health of the given drone
  - `CD_SpawnDroneByName` - Spawns a drone for a client from the given config name
  - `CD_GetDroneActiveWeapon` - Returns the index of the current weapon for a given drone
  - `CD_SetWeaponReloading` - Initiates a reload sequence on the given weapon for a drone

### Forwards
  - `CD_OnDroneCreated` - Called when a drone initially spawns
  - `CD_OnDroneDestroyed` - Called when a drone is destroyed
  - `CD_OnDroneRemoved` - Called when a drone is removed from the world after being destroyed
  - `CD_OnWeaponChanged` - Called when a player cycles weapons on a drone


## Known Issues
  - Drones can phase through geometry at certain speeds
  - Player view targets are not properly reset if operating a drone when the round resets
  - Ground based drones are not properly tested/functioning at this time
