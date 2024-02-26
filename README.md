# Custom Drones for TF2

# This branch is currently a WIP and NOT stable. Functionality exists and there is an exmaple plugin for a HL2 Hunter Chopper which works. However, this branch is still highly experimental and updates will frequently break things.

## Version 2.0 of Custom Drones. Some of the information in this readme is outdated, but most of it is up to date.

This rewrite completely changes everything about the codebase with several QoL changes. Setting up basic drones can now be done without any other plugins; weapons now have native functionality and do not need to be handled in sub-plugins anymore. A new `WeaponType_Custom` specification has been added to have weapons function as they did before.

Spawnable drones that can be piloted by players. There is an example drone under `configs/drones/example_drone.txt`. Drone plugins are placed under `plugins/drones/` and a template can be found under `scripting/drones/example_drone.sp`.

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
    - Helo
    - Hover
    - Ground


### Flying Drones
  - Flying drones move in the direction the camera is facing
  - Cannot fly below specific speeds
  - Use this movement for jet-like drones

### Helo Drones
  - Hovering drones that can fly and move in any direction
  - Movement input controls drone movement
  - Use this movement for helicopters

### Hover Drones
  - Hovering drones that stay at ground level
  - Movement input controls drone movement
  - USe this movement for hovercraft

### Ground Drones (WIP)
  - Drones limited to ground movement
  - Not functioning at this time

## Developers
This plugin comes with several forwards and natives to use with other plugins. Refer to `scripting/include/customdrones.inc` for more detailed explanations.

### Natives
  - `FDroneStatics` static class for general drone natives
    ### Weapon Natives
    - Weapons using `WeaponType_Custom` can utilize these natives to provide custom functionality
    - `FireBullets` Fires bullets from the given weapon
    - `FireRockets` Fires rockets from the given weapon
    - `FireGrenades` Fires grenades from the given weapon
    - `FireActiveWeapon` Fires the current active weapon controlled by the given seat

### Forwards
  - `CD2_OnDroneCreated` - Called when a drone initially spawns
  - `CD2_OnDroneDestroyed` - Called when a drone is destroyed
  - `CD2_OnDroneRemoved` - Called when a drone is removed from the world after being destroyed
  - `CD2_OnWeaponChanged` - Called when a player cycles weapons on a drone
  - `CD2_OnWeaponFire` - Called when a weapon on a drone is fired
  - `CD2_OnPlayerEnterDrone` - Called when a player enters a drone
  - `CD2_OnPlayerExitDrone` - Called when a player exits a drone


## Known Issues
  - Drones can phase through geometry at certain speeds
  - Ground based drones are not properly tested/functioning at this time


## Planned Featurs
  - Native support abilities (healing, ammo regeneration, etc)
  - Multiple seats on drones for passengers and additional weapons
