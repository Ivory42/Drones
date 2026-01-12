# Custom Drones for TF2

## Version 2.0 of Custom Drones. Some of the information in this readme is outdated, I will be updating the information as I re-implement them into version 2.0. This version is now stable.

This rewrite completely changes everything about the codebase with several QoL changes. Setting up basic drones can now be done without any other plugins; weapons now have native functionality and do not need to be handled in sub-plugins anymore. A new `WeaponType_Custom` specification has been added to have weapons function as they did before.

### This plugin requires another library/plugin of mine (objectmanager) which is not entirely finished. I have included the compiled plugin with the release, and I plan to have a separate repository for it once it's in a better state.

## Video demonstration

[![[TF2] Drone/Vehicle Showcase](https://img.youtube.com/vi/171LxhfiWN8/0.jpg)](https://www.youtube.com/watch?v=171LxhfiWN8 "[TF2] Drone/Vehicle Showcase")

Spawnable drones that can be piloted by players. Example HL2 Hunter Chopper config/plugin provided. Drone plugins are placed under `plugins/drones/`.

## Commands

  - `sm_drone`- Opens a menu with all available drones

## Features
  - Configuration files so you can make your own custom drones
  - Create your own logic for drones through other plugins (example included)
  - Define a model and destroyed model for each drone
  - Set health, speed, and acceleration for each drone
  - Set up to 4 weapons with individual parameters
  - Support for AI controlled drones
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
  - Use this movement for hovercraft

### Physics Based (WIP)
  - Drones utilize a `phys_thruster` for movement

## Developers (The following is outdated; updated info can be found in the referenced include)
This plugin comes with several forwards and natives to use with other plugins. Refer to `scripting/include/customdrones.inc` for more detailed explanations.

### Natives (Outdated)
  - `FDroneStatics` static class for general drone natives
    ### Weapon Natives
    - Weapons using `WeaponType_Custom` can utilize these natives to provide custom functionality
    - `FireBullets` Fires bullets from the given weapon
    - `FireRockets` Fires rockets from the given weapon
    - `FireGrenades` Fires grenades from the given weapon
    - `FireActiveWeapon` Fires the current active weapon controlled by the given seat

### Forwards (Outdated)
  - `CD2_OnDroneCreated` - Called when a drone initially spawns
  - `CD2_OnDroneDestroyed` - Called when a drone is destroyed
  - `CD2_OnDroneRemoved` - Called when a drone is removed from the world after being destroyed
  - `CD2_OnWeaponChanged` - Called when a player cycles weapons on a drone
  - `CD2_OnWeaponFire` - Called when a weapon on a drone is fired
  - `CD2_OnPlayerEnterDrone` - Called when a player enters a drone
  - `CD2_OnPlayerExitDrone` - Called when a player exits a drone


## Known Issues
  - Players may not properly die when the piloted drone is destroyed, and will resupply with no items
  - Using a kill bind while in a drone forces you to respawn


## Planned Features
  - Native support abilities (healing, ammo regeneration, etc)
  - Multiple seats on drones for passengers and additional weapons
