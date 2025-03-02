#include <customdrones>
#include <objectmanager/templates/buildings>

methodmap AHowitzerSentry < ASentrygun
{
	property AHowitzerDrone Howitzer
	{
		public get() { return view_as<AHowitzerDrone>(this.GetObjectProp("Sentry.HowitzerTiedToThisSentry")); }
		public set(AHowitzerDrone drone) this.SetObjectProp("Sentry.HowitzerTiedToThisSentry", drone);
	}
}
methodmap AHowitzerDrone < ADrone
{
	property ASentrygun Sentry
	{
		public get() { return view_as<ASentrygun>(this.GetObjectProp("Howitzer.Sentrygun")); }
		public set(ASentrygun sentry) { this.SetObjectProp("Howitzer.Sentrygun", sentry); }
	}

	property bool HasSentry
	{
		public get() { return view_as<bool>(this.GetObjectProp("Howitzer.AppliedAsSentry")); }
		public set(bool value) { this.SetObjectProp("Howitzer.AppliedAsSentry", value); }
	}

	property bool MortarMode
	{
		public get() { return view_as<bool>(this.GetObjectProp("Howitzer.InMortarMode")); }
		public set(bool value) { this.SetObjectProp("Howitzer.InMortarMode", value); }
	}

	property int AmmoPerShot
	{
		public get() { return this.GetObjectProp("Howitzer.AmmoPerShot"); }
		public set(int value) { this.SetObjectProp("Howitzer.AmmoPerShot", value); }
	}
}

methodmap AHowitzerCannon < ADroneProjectileWeapon
{

}

stock AHowitzerDrone CastToHowitzer(ABaseEntity entity)
{
	if (entity && IsEntityOfType(entity, "Drone.HowitzerTurret"))
	{
		return view_as<AHowitzerDrone>(entity);
	}

	return null;
}
