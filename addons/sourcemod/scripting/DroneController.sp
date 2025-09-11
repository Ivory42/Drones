#pragma semicolon 1

void OnDroneAttack(ADronePlayer client, ADroneWeapon weapon, ADrone drone, FDroneSeat seat)
{
	if (weapon.CanFire())
	{
		if (weapon.FireRate > 0.0)
			weapon.NextPrimaryAttack = GetGameTime() + (1.0 / weapon.FireRate);

		int ammoReduce = 1;

		switch (weapon.Type)
		{
			case WeaponType_Gun: DroneFireGun(drone, weapon, client);
			case WeaponType_Laser: DroneFireGun(drone, weapon, client);// TODO
			case WeaponType_Projectile:
			{
				ADroneProjectileWeapon projWep = view_as<ADroneProjectileWeapon>(weapon);
				DroneFireProjectile(drone, projWep, projWep.ProjType, client);
			}
		}

		// For custom OnWeaponFire Forward
		int newAmmo = 1;
		Action action = Plugin_Continue;

		char weaponName[64];
		weapon.GetInternalName(weaponName, sizeof weaponName);

		Call_StartForward(DroneAttack);

		Call_PushCell(drone);
		Call_PushCell(client);
		Call_PushCell(weapon);
		Call_PushCell(seat);
		Call_PushCellRef(newAmmo);
		Call_PushString(weaponName);

		Call_Finish(action);

		if (action == Plugin_Changed)
		{
			ammoReduce = newAmmo;
		}
		else if (action == Plugin_Handled || action == Plugin_Stop)
		{
			return;
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

void OnDroneAIAttack(FDroneAI ai, ADroneWeapon weapon, ADrone drone, FDroneSeat seat)
{
	if (weapon.CanFire())
	{
		Action actionCanAttack = Plugin_Continue;
		Call_StartForward(DroneAIAttack);

		Call_PushCell(ai);
		Call_PushCell(drone);
		Call_PushCell(weapon);

		Call_Finish(actionCanAttack);

		if (actionCanAttack != Plugin_Continue)
		{
			if (actionCanAttack == Plugin_Handled) // Set attack cooldown on handled
			{
				if (weapon.FireRate > 0.0)
					weapon.NextPrimaryAttack = GetGameTime() + (1.0 / weapon.FireRate);
			}
			return;
		}

		if (weapon.FireRate > 0.0)
			weapon.NextPrimaryAttack = GetGameTime() + (1.0 / weapon.FireRate);

		int ammoReduce = 1;

		switch (weapon.Type)
		{
			case WeaponType_Gun: DroneAIFireGun(drone, weapon, ai);
			case WeaponType_Laser: DroneAIFireGun(drone, weapon, ai);// TODO
			case WeaponType_Projectile:
			{
				ADroneProjectileWeapon projWep = view_as<ADroneProjectileWeapon>(weapon);
				DroneAIFireProjectile(drone, projWep, projWep.ProjType, ai);
			}
		}

		int newAmmo = 1;
		Action action = Plugin_Continue;

		char weaponName[64];
		weapon.GetInternalName(weaponName, sizeof weaponName);
		Call_StartForward(DroneAttack);

		Call_PushCell(drone);
		Call_PushCell(GetWorldSpawn());
		Call_PushCell(weapon);
		Call_PushCell(seat);
		Call_PushCellRef(newAmmo);
		Call_PushString(weaponName);

		Call_Finish(action);

		if (action == Plugin_Changed)
		{
			ammoReduce = newAmmo;
		}
		else if (action == Plugin_Handled || action == Plugin_Stop)
		{
			return;
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

void OnDroneMoveForward(ADrone drone, float axisValue, FVector input)
{
	FRotator angles;
	angles = drone.GetAngles();
	bool ignorePitch = false;

	FRotator movementRot;
	movementRot = drone.GetInputRotation();

	static const float MaxPitchAngle = 25.0;

	switch (drone.MoveType)
	{
		case MoveType_Helo:
		{
			ignorePitch = true;
			float pitch = MaxPitchAngle * axisValue;

			movementRot.Pitch = pitch;

			drone.SetInputRotation(movementRot);
		}
		case MoveType_Physics:
		{
			ignorePitch = true;
		}
	}

	float acceleration = drone.Acceleration * axisValue;

	FVector direction;
	if (ignorePitch)
	{
		angles.Pitch = 0.0; // null pitch value for helo drones
	}

	direction = angles.GetForwardVector();
	direction.Normalize();
	direction.Scale(acceleration);
	input.Add(direction);
}

void OnDroneMoveRight(ADrone drone, float axisValue, FVector input)
{
	if (drone.MoveType == MoveType_Helo || drone.MoveType == MoveType_Hover) // flying drones cannot move right/left
	{
		FRotator angles;
		angles = drone.GetAngles();
		bool ignoreRoll = false;

		FRotator movementRot;
		movementRot = drone.GetInputRotation();

		static const float MaxRollAngle = 25.0;

		switch (drone.MoveType)
		{
			case MoveType_Helo:
			{
				ignoreRoll = true;
				float roll = MaxRollAngle * axisValue;

				movementRot.Roll = roll;

				drone.SetInputRotation(movementRot);
			}
			case MoveType_Physics:
			{
				ignoreRoll = true;
			}
		}

		float acceleration = drone.Acceleration * axisValue;

		FVector direction;
		if (ignoreRoll)
		{
			angles.Roll = 0.0;
		}

		direction = angles.GetRightVector();
		direction.Normalize();
		direction.Scale(acceleration);
		input.Add(direction);
	}
}

void OnDroneMoveUp(ADrone drone, float axisValue, FVector input)
{
	if (drone.MoveType == MoveType_Helo)
	{
		FVector direction;
		direction = drone.GetAngles().GetUpVector();

		float acceleration = drone.Acceleration * axisValue;

		direction.Normalize();
		direction.Scale(acceleration);
		input.Add(direction);
	}
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

void OnDroneAimChanged(FRotator desiredAngle, FDroneSeat seat, ADrone drone)
{
	if (!drone || !drone.Valid() || !drone.IsDrone || drone.MoveType == MoveType_Physics)
		return;

	if (drone.MoveType == MoveType_Hover)
	{
		float distance = GetDistanceToGround(drone);
		if (distance > drone.HoverMaxHeight * 1.5)
		{
			return;
		}
	}
	FRotator currentAngle, playerAngles;
	currentAngle = drone.GetAngles();

	playerAngles = desiredAngle;

	//int droneId = drone.Get();

	switch (seat.Type)
	{
		case Seat_Pilot: // Look direction will control the drone's angles if the angles are locked to the pilot view angles
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
					movementRot = InterpRotation(movementRot, movementRotTarg, GetGameFrameTime(), drone.TurnRate * 90.0);

					drone.SetInputRotation(movementRot);

					if (drone.MoveType == MoveType_Hover)
					{
						desiredAngle.Roll = currentAngle.Roll;
					}
					else
					{
						desiredAngle.Roll = movementRot.Roll;
					}

					if (!drone.HeloChangePitch || drone.MoveType == MoveType_Hover) // hover never changes pitch based on player angles
						desiredAngle.Pitch = movementRot.Pitch;
					
					if (drone.MoveType == MoveType_Hover)
					{
						NormalizeAngles(desiredAngle);
						AdjustHoverDroneAngles(drone, desiredAngle);
					}
				}
				currentAngle = InterpRotation(currentAngle, desiredAngle, GetGameFrameTime(), drone.TurnRate);

				// For flying based drones we want to adjust the roll based on how much we are turning
				if (drone.MoveType == MoveType_Fly)
				{
					drone.LastFrameYaw = drone.CurrentFrameYaw; // Set last yaw frame to previous frame
					drone.CurrentFrameYaw = currentAngle.Yaw; // Update current yaw

					float turnRate = AngleDifference(currentAngle, desiredAngle);
					float diff = drone.LastFrameYaw - drone.CurrentFrameYaw;
					bool positive = (diff > 0);
					//PrintCenterTextAll("Turn Rate: %.1f\n%s\nCur: %.1f\nPrev: %.1f\n%.1f", turnRate, positive ? "right" : "left", drone.CurrentFrameYaw, drone.LastFrameYaw, diff);

					if (FloatAbs(turnRate) >= 0.2 && FloatAbs(diff) <= 80.0)
					{
						if (positive)
							drone.RollValue = turnRate / 1.0;
						else
							drone.RollValue = (turnRate / 1.0) * -1.0;
					}

					currentAngle.Roll = drone.RollValue;
				}
				
				FVector velocity;
				GetSmoothedVelocity(drone, velocity);
				TeleportEntity(drone.Get(), NULL_VECTOR, currentAngle.ToFloat(), velocity.ToFloat());

				// Update our camera rotation
				FObject camera;
				camera = drone.GetCamera();
				if (camera.Valid())
				{
					FRotator difference;
					difference = SubtractRotators(playerAngles, currentAngle);

					camera.SetAngles(difference);
				}
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

void AdjustHoverDroneAngles(ADrone drone, FRotator currentAngle)
{
	float distance = GetDistanceToGround(drone);
	float maxDistance = drone.HoverMaxHeight * 1.8;
	if (distance <= maxDistance)
	{
		// Perform an "IK" for this drone
		FVector mins, maxs;
		mins = ConstructVector(-1.0 * drone.HoverBackwardIK, -1.0 * drone.HoverLeftIK, 0.0);
		maxs = ConstructVector(drone.HoverForwardIK, drone.HoverRightIK, 20.0);

		FVector testmins, testmaxs;
		testmins = mins;
		testmaxs = maxs;

		FRotator absAngle;
		absAngle.Yaw = currentAngle.Yaw;

		FVector start, end, offset;
		offset.X = maxs.X / 2.0;
		start = FMath.OffsetVector(drone.GetPosition(), absAngle, offset);
		end = start;
		end.Z -= maxDistance;

		// Test each side of the drone
		// X-axis first
		FVector positions[4];
		testmins.X = 0.0;
		testmaxs.X = maxs.X / 2.0;
		FHullTrace trace = new FHullTrace(start, end, testmins, testmaxs, MASK_SHOT_HULL, DroneMovementTrace, drone);
		//trace.DebugTrace(0.1);
		positions[0] = trace.GetEndPosition();
		delete trace;

		offset.X = mins.X / 2.0;
		start = FMath.OffsetVector(drone.GetPosition(), absAngle, offset);
		end = start;
		end.Z -= maxDistance;

		testmins = mins;
		testmaxs = maxs;
		testmaxs.X = 0.0;
		testmins.X = mins.X / 2.0;
		trace = new FHullTrace(start, end, testmins, testmaxs, MASK_SHOT_HULL, DroneMovementTrace, drone);
		//trace.DebugTrace(0.1);
		positions[1] = trace.GetEndPosition();
		delete trace;

		// Now Y-axis
		offset.X = 0.0;
		offset.Y = maxs.Y / 2.0;
		start = FMath.OffsetVector(drone.GetPosition(), absAngle, offset);
		end = start;
		end.Z -= maxDistance;

		testmins = mins;
		testmaxs = maxs;
		testmins.Y = 0.0;
		testmaxs.Y = maxs.Y / 2.0;
		trace = new FHullTrace(start, end, testmins, testmaxs, MASK_SHOT_HULL, DroneMovementTrace, drone);
		//trace.DebugTrace(0.1);
		positions[2] = trace.GetEndPosition();
		delete trace;

		offset.Y = mins.Y / 2.0;
		start = FMath.OffsetVector(drone.GetPosition(), absAngle, offset);
		end = start;
		end.Z -= maxDistance;

		testmins = mins;
		testmaxs = maxs;
		testmaxs.Y = 0.0;
		testmins.Y = mins.Y / 2.0;
		trace = new FHullTrace(start, end, testmins, testmaxs, MASK_SHOT_HULL, DroneMovementTrace, drone);
		//trace.DebugTrace(0.1);
		positions[3] = trace.GetEndPosition();
		delete trace;

		// now that we have our horizontal positions, lets get the angle between the two and that will be our adjustment
		FRotator adjustX, adjustY;
		adjustX = Vector_GetAngles(Vector_MakeFromPoints(positions[1], positions[0]));
		NormalizeAngles(adjustX);

		adjustY = Vector_GetAngles(Vector_MakeFromPoints(positions[2], positions[3]));
		currentAngle.Pitch = adjustX.Pitch;
		currentAngle.Roll = adjustY.Pitch;
		drone.SetCurrentIncline(currentAngle);
		//PrintCenterTextAll("Angle = %.1f | New Angle = %.1f", adjustX.Pitch, currentAngle.Pitch);
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
	FRotator newAngle, difference;
	difference = SubtractRotators(desired, droneAngle);

	newAngle = FMath.InterpRotatorTo(current, difference, GetGameFrameTime(), weapon.TurnRate);

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

void GetSmoothedVelocity(ADrone drone, FVector velocity)
{
	if (SmoothedVel)
	{
		float vel[3];
		SDKCall(SmoothedVel, drone.Get(), vel);

		velocity.Set(vel);
	}
}
