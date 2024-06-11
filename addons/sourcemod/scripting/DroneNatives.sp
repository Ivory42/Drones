GlobalForward DroneAIEnter;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("FDroneStatics.FireBullets", Native_FireBullets);
	CreateNative("FDroneStatics.SpawnDroneByConfig", Native_CreateDrone);
	CreateNative("FDroneStatics.AIControlDroneSeat", Native_ControlDrone);
	CreateNative("FDroneStatics.CreateDroneWithController", Native_SpawnDroneController);

	return APLRes_Success;
}

int Native_FireBullets(Handle plugin, int args)
{
	ADronePlayer gunner = view_as<ADronePlayer>(GetNativeCell(1));
	ADrone drone = view_as<ADrone>(GetNativeCell(2));
	ADroneWeapon weapon = view_as<ADroneWeapon>(GetNativeCell(3));
	FDroneSeat seat = view_as<FDroneSeat>(GetNativeCell(4));

	if (seat.AIControlled)
	{
		DroneAIFireGun(drone, weapon, seat.AIOccupier);
	}
	else
	{
		DroneFireGun(drone, weapon, gunner);
	}
	return 0;
}

any Native_CreateDrone(Handle plugin, int args)
{
	char configName[64];
	GetNativeString(1, configName, sizeof configName);
	FTransform spawn;
	GetNativeArray(2, spawn, sizeof FTransform);

	ADrone drone = CreateDroneByName(GetWorld(), configName, spawn);

	return drone;
}

any Native_SpawnDroneController(Handle plugin, int args)
{
	char configName[64], controllerConf[64];
	GetNativeString(1, configName, sizeof configName);
	FTransform spawn;
	GetNativeArray(3, spawn, sizeof FTransform);

	ADrone drone = CreateDroneByName(GetWorld(), configName, spawn);

	GetNativeString(2, controllerConf, sizeof controllerConf);
	FDroneAIParams params;
	params = FDroneAIStatics.CreateParamSetFromConfig(controllerConf);

	FDroneAI controller = FDroneAIStatics.CreateDroneAIController(params);

	ControlDrone(drone, GetPilotSeat(drone), controller);

	return drone;
}

int Native_ControlDrone(Handle plugin, int args)
{
	ADrone drone = null;
	FDroneSeat seat = null;
	FDroneAI ai = null;

	drone = view_as<ADrone>(GetNativeCell(1));
	seat = view_as<FDroneSeat>(GetNativeCell(2));
	ai = view_as<FDroneAI>(GetNativeCell(3));
	
	ControlDrone(drone, seat, ai);

	return 0;
}

void ControlDrone(ADrone drone, FDroneSeat seat, FDroneAI controller)
{
	if (drone && seat)
	{
		if (!seat.Occupied && controller && controller.ValidDroneAI())
		{
			seat.Occupied = true;
			seat.AIControlled = true;
			seat.AIOccupier = controller;
			controller.TargetQueryPositions = new ArrayList(_, MaxQueriedPositions);
			controller.OwnQueryPositions = new ArrayList(_, MaxQueriedPositions);
		}

		Call_StartForward(DroneAIEnter);

		Call_PushCell(drone);
		Call_PushCell(controller);
		Call_PushCell(seat);

		Call_Finish();
	}
}
