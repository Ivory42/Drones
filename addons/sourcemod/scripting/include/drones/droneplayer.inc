#if defined _customdrones_player_included
 #endinput
#endif
#define _customdrones_player_included

#include <ilib_objects>
#include "drone.inc"

methodmap ADronePlayer < AClient
{
	property ADrone Drone	// Drone this player is currently occupying
	{
		public get() { return this.GetObjectProp("Player_Drone"); }
		public set(ADrone drone) { this.SetObjectProp("Player_Drone", drone); }
	}

	property bool InDrone 	// Is this client currently in a drone seat
	{
		public get() { return this.GetObjectProp("Player_IsInDroneSeat"); }
		public set(bool value) { this.SetObjectProp("Player_IsInDroneSeat", value); }
	}

	property int ExitingHealth // Amount of health this player had when exiting a vehicle
	{
		public get() { return this.GetObjectProp("Player_ExitingHealth"); }
		public set(int value) { this.SetObjectProp("Player_ExitingHealth", value); }
	}

	property int Inputs // Player's buttons value
	{
		public get() { return this.GetObjectProp("Player_Inputs"); }
		public set(int value) { this.SetObjectProp("Player_Inputs", value); }
	}

	public ADrone GetDrone() { return this.Drone; }
}
