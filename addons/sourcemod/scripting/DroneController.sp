#pragma semicolon 1

void OnDroneAttack(ADronePlayer client, ADroneWeapon weapon, ADrone drone)
{
	if (weapon.CanFire())
	{
		if (weapon.FireRate > 0.0)
			weapon.NextPrimaryAttack = GetGameTime() + (1.0 / weapon.FireRate);

		int ammoReduce = 1;

		switch (weapon.Type)
		{
			case WeaponType_Gun: DroneFireGun(drone, weapon, client);
			case WeaponType_Projectile: DroneFireRocket(drone, view_as<ADroneProjectileWeapon>(weapon), client);
			case WeaponType_Custom:
			{
				int newAmmo = 1;
				Action action = Plugin_Continue;

				char weaponName[64];
				weapon.GetInternalName(weaponName, sizeof weaponName);
				Call_StartForward(DroneAttack);

				Call_PushCell(drone);
				Call_PushCell(client);
				Call_PushCell(weapon);
				Call_PushCellRef(newAmmo);
				Call_PushString(weaponName);

				Call_Finish(action);

				if (action == Plugin_Changed)
				{
					ammoReduce = newAmmo;
				}
				else if (action == Plugin_Handled || action == Plugin_Stop)
					return;
			}
		}
		char fireSound[64];
		weapon.GetFireSound(fireSound, sizeof fireSound);
		if (strlen(fireSound) > 3)
		{
			PrecacheSound(fireSound);
			EmitSoundToAll(fireSound, weapon.Get(), SNDCHAN_AUTO, 90);
		}

		if (weapon.BottomlessAmmo)
			return;

		weapon.Ammo -= ammoReduce;
		if (weapon.Ammo <= 0)
			weapon.SimulateReload();
	}
}

void OnDroneMoveForward(ADrone drone, float axisValue, FVector speeds, FVector velocity, float maxSpeed, bool stall)
{
	FRotator direction;
	bool ignorePitch = false;

	FRotator movementRot;
	movementRot = drone.GetInputRotation();

	// Need to make this a variable within the drone possibly
	static const float MaxPitchAngle = 25.0;

	direction = drone.GetAngles();

	switch (drone.MoveType)
	{
		case MoveType_Helo:
		{
			ignorePitch = true;
			float pitch = MaxPitchAngle * axisValue;

			movementRot.Pitch = pitch;
			//movementRot = FMath.InterpRotatorTo(movementRot, desiredRot, GetGameFrameTime(), 8.0);

			drone.SetInputRotation(movementRot);
		}
	}

	//int droneId = drone.Get();

	if (stall)
	{
		// Slow to a stop
		if (speeds.X > 0.0)
		{
			speeds.X -= drone.Acceleration;
		}
		else if (speeds.X < 0.0)
		{
			speeds.X += drone.Acceleration;
		}
	}
	else
	{
		switch (drone.MoveType)
		{
			case MoveType_Helo, MoveType_Hover:
			{
				speeds.X += drone.Acceleration * axisValue;

				speeds.X = FMath.ClampFloat(speeds.X, maxSpeed * -1.0, maxSpeed);
			}
			case MoveType_Fly:
			{
				speeds.X += drone.Acceleration * axisValue;
				speeds.X = FMath.ClampFloat(speeds.X, 200.0, maxSpeed); // TODO - setup minimum speed for flying drones
			}
			case MoveType_Custom:
			{
				// Setup forwards to manually update input speeds
			}
		}
	}

	// Now update our velocity
	FVector inputVel;

	if (ignorePitch)
	{
		direction.Pitch = 0.0; // null pitch value for helo drones
	}
	inputVel = direction.GetForwardVector();

	inputVel.Scale(speeds.X);
	velocity.Add(inputVel);
}

void OnDroneMoveRight(ADrone drone, float axisValue, FVector speeds, FVector velocity, float maxSpeed, bool stall)
{
	FRotator direction;
	bool ignoreRoll = false;

	FRotator movementRot;
	movementRot = drone.GetInputRotation();

	// Need to make this a variable within the drone possibly
	static const float MaxRollAngle = 25.0;

	direction = drone.GetAngles();

	switch (drone.MoveType)
	{
		case MoveType_Helo:
		{
			ignoreRoll = true;
			float roll = MaxRollAngle * axisValue;

			movementRot.Roll = roll;
			//movementRot = FMath.InterpRotatorTo(movementRot, desiredRot, GetGameFrameTime(), 8.0);

			drone.SetInputRotation(movementRot);
		}
		case MoveType_Custom:
		{
			// Setup forwards to manually update input speeds
		}
	}

	//int droneId = drone.Get();

	if (stall)
	{
		// Slow to a stop
		if (speeds.Y > 0.0)
		{
			speeds.Y -= drone.Acceleration;
		}
		else if (speeds.Y < 0.0)
		{
			speeds.Y += drone.Acceleration;
		}
	}
	else
	{
		switch (drone.MoveType)
		{
			case MoveType_Helo, MoveType_Hover:
			{
				speeds.Y += drone.Acceleration * axisValue;

				speeds.Y = FMath.ClampFloat(speeds.Y, maxSpeed * -1.0, maxSpeed);
			}
			case MoveType_Custom:
			{
				// Setup forwards to manually update input speeds
			}
		}
	}

	// Now update our velocity
	FVector inputVel;

	if (ignoreRoll)
	{
		direction.Roll = 0.0; // null pitch value for helo drones
	}
	inputVel = direction.GetRightVector();

	inputVel.Scale(speeds.Y);
	velocity.Add(inputVel);
}

void OnDroneMoveUp(ADrone drone, float axisValue, FVector speeds, FVector velocity, float maxSpeed, bool stall)
{
	FRotator direction;

	direction = drone.GetAngles();

	//int droneId = drone.Get();

	if (stall)
	{
		// Slow to a stop
		if (speeds.Z > 0.0)
		{
			speeds.Z -= drone.Acceleration;
		}
		else if (speeds.Z < 0.0)
		{
			speeds.Z += drone.Acceleration;
		}
	}
	else
	{
		switch (drone.MoveType)
		{
			case MoveType_Helo:
			{
				speeds.Z += drone.Acceleration * axisValue;

				speeds.Z = FMath.ClampFloat(speeds.Z, maxSpeed * -1.0, maxSpeed);
			}
			case MoveType_Custom:
			{
				// Setup forwards to manually update input speeds
			}
		}
	}

	// Now update our velocity
	FVector inputVel;
	inputVel = direction.GetUpVector();

	inputVel.Scale(speeds.Z);
	velocity.Add(inputVel);
}


// Test - move to ilib FMath when working - Non-constant interpolation instead of the current constant interpolation
FRotator InterpRotation(FRotator current, FRotator target, float deltaTime, float speed)
{
	// if DeltaTime is 0, do not perform any interpolation (Location was already calculated for that frame)
	if (deltaTime == 0.0 || current.IsEqual(target))
	{
		return current;
	}

	if (speed <= 0.0)
	{
		return target;
	}

	float interpSpeedDelta = speed * deltaTime;
	FRotator delta;
	delta = SubtractRotators(target, current).GetNormalized();

	FRotator deltaMove;
	deltaMove.Pitch = delta.Pitch * FMath.ClampFloat(interpSpeedDelta, 0.0, 1.0);
	deltaMove.Roll = delta.Roll * FMath.ClampFloat(interpSpeedDelta, 0.0, 1.0);
	deltaMove.Yaw = delta.Yaw * FMath.ClampFloat(interpSpeedDelta, 0.0, 1.0);

	FRotator result;
	result = current;
	
	result.Pitch += deltaMove.Pitch;
	result.Yaw += deltaMove.Yaw;
	result.Roll += deltaMove.Roll;

	return result.GetNormalized();
}

void OnDroneAimChanged(ADronePlayer client, FDroneSeat seat, ADrone drone)
{
	if (!drone || !drone.Valid() || !drone.IsDrone)
		return;

	FRotator currentAngle, desiredAngle, playerAngles;
	currentAngle = drone.GetAngles();
	desiredAngle = client.GetEyeAngles();

	playerAngles = desiredAngle;

	//int droneId = drone.Get();

	switch (seat.Type)
	{
		case Seat_Pilot: // Look direction will control the drone's angles if the angles are locked to the client view angles
		{
			if (drone.UsePlayerAngles)
			{
				// Smoothly rotate drone in direction the player is aiming
				if (drone.MoveType == MoveType_Helo || drone.MoveType == MoveType_Hover)
				{
					FRotator movementRotTarg, movementRot;
					movementRotTarg = drone.GetInputRotation();
					movementRot = currentAngle;

					movementRotTarg.Yaw = currentAngle.Yaw; // Ignore yaw
					movementRot = InterpRotation(movementRot, movementRotTarg, GetGameFrameTime(), 90.0);

					drone.SetInputRotation(movementRot);

					desiredAngle.Pitch = movementRot.Pitch;
					desiredAngle.Roll = movementRot.Roll;
				}
				
				currentAngle = InterpRotation(currentAngle, desiredAngle, GetGameFrameTime(), 2.0/*drone.TurnRate*/);

				// For flying based drones we want to adjust the roll based on how much we are turning
				if (drone.MoveType == MoveType_Fly)
				{
					drone.LastFrameYaw = drone.CurrentFrameYaw; // Set last yaw frame to previous frame
					drone.CurrentFrameYaw = currentAngle.Yaw; // Update current yaw

					float turnRate = AngleDifference(currentAngle, desiredAngle);
					float diff = drone.LastFrameYaw - drone.CurrentFrameYaw;
					bool positive = (diff > 0);

					if (FloatAbs(turnRate) >= 0.2 && FloatAbs(diff) <= 80.0)
					{
						if (positive)
							drone.RollValue = turnRate / 1.0;
						else
							drone.RollValue = (turnRate / 1.0) * -1.0;
					}

					currentAngle.Roll = drone.RollValue;
				}

				drone.GetObject().SetAngles(currentAngle);
			}
			if (seat.HasWeapon())
			{
				UpdateDroneWeaponAngles(currentAngle, playerAngles, drone.GetAngles(), seat.ActiveWeapon); // Update any controlled weapons
			}
		}
		case Seat_Gunner: // Gunners can only rotate their controller weapons
		{
			if (seat.HasWeapon())
			{
				UpdateDroneWeaponAngles(currentAngle, playerAngles, drone.GetAngles(), seat.ActiveWeapon); // Update any controlled weapons
			}
		}
	}
}

// Gets the dot product between forward vectors of two rotators
float AngleDifference(FRotator currentAngle, FRotator targetAngle)
{
	FVector forwardVec, aimVec;
	FRotator tempCurrent, tempTarget;

	// We only need the yaw
	tempCurrent.Yaw = currentAngle.Yaw;
	tempTarget.Yaw = targetAngle.Yaw;

	forwardVec = tempCurrent.GetForwardVector();
	aimVec = tempTarget.GetForwardVector();

	return RadToDeg(ArcCosine(Vector_DotProduct(forwardVec, aimVec) / forwardVec.Length(true)));
}

void UpdateDroneWeaponAngles(FRotator current, FRotator desired, FRotator droneAngle, ADroneWeapon weapon)
{
	FRotator newAngle;
	desired = SubtractRotators(desired, droneAngle);

	newAngle = FMath.InterpRotatorTo(current, desired, GetGameFrameTime(), weapon.TurnRate);

	// Let's determine how to use this new angle
	if (weapon.ComplexAngles)
	{
		// If we have complex angles and both a mount and receiver, split the pitch and yaw
		if (weapon.GetReceiver().Valid())
		{
			FRotator receiverRot;
			receiverRot.Pitch = newAngle.Pitch; // Angles become relative so we can keep yaw/roll at 0

			weapon.GetReceiver().SetAngles(receiverRot);
		}
		if (weapon.GetMount().Valid())
		{
			FRotator mountRot;
			mountRot.Yaw = newAngle.Yaw;

			weapon.GetMount().SetAngles(mountRot);
		}
	}
	else if (weapon.GetReceiver().Valid()) // Otherswise apply all angles onto the receiver
		weapon.GetReceiver().SetAngles(newAngle);
	
}

void CycleNextWeapon(FDroneSeat seat)
{
	if (seat.HasWeapon())
	{
		if (seat.NextSwitchTime <= GetGameTime())
		{
			seat.NextSwitchTime = GetGameTime() + 0.2;

			int weapons = seat.Weapons.Length;
			if (weapons > 1)
			{
				int index = seat.ActiveWeaponIndex;
				index++;
				if (index >= weapons)
					index = 0;
				
				seat.ActiveWeaponIndex = index;

				seat.ActiveWeapon = view_as<ADroneWeapon>(seat.Weapons.Get(index));
			}
		}
	}
}