GlobalForward DroneAIEnter;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("FDroneStatics.FireBullets", Native_FireBullets);
	CreateNative("FDroneStatics.FireRockets", Native_FireRockets);
	CreateNative("FDroneStatics.FireActiveWeapon", Native_FireWeapon);
	CreateNative("FDroneStatics.SpawnDroneByConfig", Native_CreateDrone);
	CreateNative("FDroneStatics.AIControlDroneSeat", Native_ControlDrone);
	CreateNative("FDroneStatics.CreateDroneWithController", Native_SpawnDroneController);
	CreateNative("FDroneStatics.ChangeAIState", Native_ChangeState);
	CreateNative("FDroneStatics.PlayerEnterDrone", Native_PlayerEnterDrone);
	CreateNative("FDroneStatics.PlayerExitDrone", Native_PlayerExitDrone);

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

any Native_FireRockets(Handle plugin, int args)
{
	ADronePlayer gunner = view_as<ADronePlayer>(GetNativeCell(1));
	ADrone drone = view_as<ADrone>(GetNativeCell(2));
	ADroneProjectileWeapon weapon = view_as<ADroneProjectileWeapon>(GetNativeCell(3));
	FDroneSeat seat = view_as<FDroneSeat>(GetNativeCell(4));

	if (seat.AIControlled)
	{
		DroneAIFireRocket(drone, weapon, seat.AIOccupier);
	}
	else
	{
		DroneFireRocket(drone, weapon, gunner);
	}
	return 0;
}

int Native_FireWeapon(Handle plugin, int args)
{
	FDroneSeat seat = view_as<FDroneSeat>(GetNativeCell(1));
	if (seat && seat.Valid())
	{
		ADrone drone = seat.Drone;
		if (drone && drone.IsDrone)
		{
			if (seat.AIControlled && seat.AIOccupier)
			{
				OnDroneAIAttack(FDroneAIStatics.GetSeatController(seat), seat.ActiveWeapon, drone, seat);
			}
			else if (seat.Occupier)
			{
				OnDroneAttack(seat.Occupier, seat.ActiveWeapon, drone, seat);
			}
		}
	}

	return 0;
}

any Native_ChangeState(Handle plugin, int args)
{
	FDroneAI controller = view_as<FDroneAI>(GetNativeCell(1));
	EControllerState state = view_as<EControllerState>(GetNativeCell(2));
	bool doForward = view_as<bool>(GetNativeCell(3));

	ChangeControllerState(controller, state, !doForward);

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
			controller.TargetQueryPositions = new ArrayList(_, controller.MaxQueriedPositions);
			controller.OwnQueryPositions = new ArrayList(_, controller.MaxQueriedPositions);

			controller.ControlledSeat = seat;
			controller.Drone = drone;
		}

		Call_StartForward(DroneAIEnter);

		Call_PushCell(drone);
		Call_PushCell(controller);
		Call_PushCell(seat);

		Call_Finish();
	}
}

int Native_PlayerEnterDrone(Handle plugin, int args)
{
	ADronePlayer client = view_as<ADronePlayer>(GetNativeCell(1));
	FDroneSeat seat = view_as<FDroneSeat>(GetNativeCell(2));
	ADrone drone = view_as<ADrone>(GetNativeCell(3));

	if (!seat.Occupied && !seat.AIControlled)
	{
		PlayerEnterVehicle(client, drone);
	}

	return 0;
}

int Native_PlayerExitDrone(Handle plugin, int args)
{
	ADronePlayer client = view_as<ADronePlayer>(GetNativeCell(1));
	FDroneSeat seat = view_as<FDroneSeat>(GetNativeCell(2));
	ADrone drone = view_as<ADrone>(GetNativeCell(3));

	if (!seat.Occupied && !seat.AIControlled)
	{
		PlayerExitVehicle(client, seat, drone);
	}

	return 0;
}
