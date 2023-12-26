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

	public ADrone GetDrone() { return this.Drone; }
}
