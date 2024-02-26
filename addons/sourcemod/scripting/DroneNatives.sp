
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("FDroneStatics.FireBullets", Native_FireBullets);

	return APLRes_Success;
}

int Native_FireBullets(Handle plugin, int args)
{
    ADronePlayer gunner = view_as<ADronePlayer>(GetNativeCell(1));
    ADrone drone = view_as<ADrone>(GetNativeCell(2));
    ADroneWeapon weapon = view_as<ADroneWeapon>(GetNativeCell(3));

    DroneFireGun(drone, weapon, gunner);
    return 0;
}