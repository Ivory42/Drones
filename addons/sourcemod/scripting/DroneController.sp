#pragma semicolon 1

void OnDroneAttack(const FClient client, const FDroneSeat seat, FDrone drone)
{
	//
}

void OnDroneMoveForward(ADrone drone, float axisValue, FVector speeds, FVector velocity, float maxSpeed, bool stall)
{
	FRotator direction;
	bool ignorePitch = false;

	direction = drone.GetAngles();

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
		switch (drone.GetMoveType())
		{
			case MoveType_Helo, MoveType_Hover:
			{
				speeds.X += drone.Acceleration * axisValue;
				ignorePitch = true;

				ClampFloat(speeds.X, maxSpeed * -1.0, maxSpeed);
			}
			case MoveType_Fly:
			{
				speeds.X += drone.Acceleration * axisValue;
				ClampFloat(speeds.X, 200.0, maxSpeed); // TODO - setup minimum speed for flying drones
			}
			case MoveType_Custom:
			{
				// Setup forwards to manually update input speeds
			}
		}
	}

	// Now update our velocity
	FVector inputVel;
	inputVel = direction.GetForwardVector();

	if (ignorePitch)
	{
		direction.Pitch = 0.0; // null pitch value for helo drones
	}

	inputVel.Scale(speeds.X);
	velocity.Add(inputVel);
}

void OnDroneMoveRight(ADrone drone, float axisValue, FVector speeds, FVector velocity, float maxSpeed, bool stall)
{
	FRotator direction;
	bool ignoreRoll = false;

	direction = drone.GetAngles();

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
		switch (drone.GetMoveType())
		{
			case MoveType_Helo, MoveType_Hover:
			{
				speeds.Y += drone.Acceleration * axisValue;
				ignoreRoll = true;

				ClampFloat(speeds.Y, maxSpeed * -1.0, maxSpeed);
			}
			case MoveType_Custom:
			{
				// Setup forwards to manually update input speeds
			}
		}
	}

	// Now update our velocity
	FVector inputVel;
	inputVel = direction.GetRightVector();

	if (ignoreRoll)
	{
		direction.Roll = 0.0; // null pitch value for helo drones
	}

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
		switch (drone.GetMoveType())
		{
			case MoveType_Helo:
			{
				speeds.Z += drone.Acceleration * axisValue;

				ClampFloat(speeds.Z, maxSpeed * -1.0, maxSpeed);
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

void OnDroneAimChanged(ADronePlayer client, FDroneSeat seat, ADrone drone)
{
	if (!drone || !drone.Valid() || !drone.IsDrone)
		return;

	FRotator currentAngle, desiredAngle;
	currentAngle = drone.GetAngles();
	desiredAngle = client.GetEyeAngles();

	int droneId = drone.Get();

	switch (seat.Type)
	{
		case Seat_Pilot: // Look direction will control the drone's angles if the angles are locked to the client view angles
		{
			if (drone.Viewlocked)
			{
				// Smoothly rotate drone in direction the player is aiming
				currentAngle = FMath.InterpRotation(currentAngle, desiredAngle, GetGameFrameTime(), drone.TurnRate);

				// For flying based drones we want to adjust the roll based on how much we are turning
				if (drone.GetMoveType() == MoveType_Fly)
				{
					drone.LastFrameYaw = drone.CurrentFrameYaw; // Set last yaw frame to previous frame
					drone.CurrentFrameYaw = currentAngle.Yaw; // Update current yaw

					float turnRate = AngleDifference(currentAngle, desiredAngle);
					float diff = drone.LastFrameYaw - drone.CurrentFrameYaw;
					bool positive = (diff > 0) != 0;

					if (FloatAbs(turnRate) >= 0.2 && FloatAbs(diff) <= 80.0)
					{
						if (positive)
							drone.RollValue = turnRate / 1.0;
						else
							drone.RollValue = (turnRate / 1.0) * -1.0;
					}

					currentAngle.roll = drone.RollValue;
					drone.SetAngles(currentAngle);
				}
			}
			if (seat.HasWeapon())
			{
				UpdateDroneWeaponAngles(currentAngle, desiredAngle, seat.ActiveWeapon); // Update any controlled weapons
			}
		}
		case Seat_Gunner: // Gunners can only rotate their controller weapons
		{
			if (seat.HasWeapon())
			{
				UpdateDroneWeaponAngles(currentAngle, desiredAngle, seat.ActiveWeapon); // Update any controlled weapons
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

void UpdateDroneWeaponAngles(FRotator current, FRotator desired, ADroneWeapon weapon)
{
	FRotator newAngle;
	newAngle = FMath.InterpRotation(current, desired, GetGameFrameTime(), weapon.TurnRate);

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

void CycleNextWeapon(ADronePlayer client, FDroneSeat seat, ADrone drone)
{

}