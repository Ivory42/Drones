void SimulateController(FDroneAI ai, FDroneSeat seat, ADrone drone)
{
	FRotator currentAngle;
	currentAngle = ai.GetViewAngle();

	bool thinkTick = false;
	if (ai.NextThinkTime <= GetGameTime())
	{
		ai.NextThinkTime = GetGameTime() + ai.ThinkRate;
		thinkTick = true;
	}
	switch (drone.MoveType)
	{
		case MoveType_Helo:
		{
			SimulateHeloAI(ai, seat, drone, thinkTick);
		}
		case MoveType_Fly:
		{

		}
	}

	if (seat.Type == Seat_Pilot)
	{
		FVector velocity;
		if (ai.Moving)
		{
			FVector moveDir;
			moveDir = Vector_MakeFromPoints(drone.GetPosition(), ai.GetMovePosition());

			if (ai.CurrentState != Controller_Attacking)
				ai.SetTargetAngle(Vector_GetAngles(moveDir));
					
			CalcMovementVector(ai, drone, velocity, moveDir);

			if (drone.GetPosition().DistanceTo(ai.GetMovePosition()) < 270.0)
			{
				ai.Moving = false;
				ai.Stalling = true;
				if (drone.GetVelocity().Length() >= 150.0)
				{
					ai.NextMovementTime = GetGameTime() + 1.5; // Slight delay before next move
				}
			}
		}
		else
		{
			FVector inputVel, targetVel;
			targetVel = drone.GetVelocity();
			targetVel.Negate();

			inputVel = drone.GetInputVelocity();
			inputVel = FMath.InterpVectorTo(inputVel, targetVel, GetGameFrameTime(), 0.95);
			drone.SetInputVelocity(inputVel);

			//inputVel = drone.GetInputVelocity();
			//inputVel.Scale(0.98);
			
			velocity.Add(inputVel);
		}

		CalcMovementTilt(drone, ai.Stalling);
		SimulateDrone(drone, velocity, drone.MaxSpeed);
	}

	// Now handle our view angles
	if (seat)
	{
		FRotator desiredAngle;
		desiredAngle = currentAngle;
		OnDroneAimChanged(desiredAngle, seat, drone);

		currentAngle = FMath.InterpRotatorTo(currentAngle, ai.GetTargetAngle(), GetGameFrameTime(), 80.0);
		ai.SetViewAngle(currentAngle);
	}
}

void SimulateHeloAI(FDroneAI ai, FDroneSeat seat, ADrone drone, bool thinkTick)
{
	FDroneAIParams params;
	params = ai.GetControllerParams();

	ADroneWeapon weapon = null;

	if (seat.HasWeapon())
	{
		weapon = seat.ActiveWeapon;
		weapon.Simulate();
	}

	switch (ai.CurrentState)
	{
		case Controller_Idle:
		{
			if (seat.Type == Seat_Pilot) // Pilot seat controls the drone's movement
			{
				bool moveTick = false;
				if (ai.NextMovementTime <= GetGameTime())
				{
					ai.NextMovementTime = GetGameTime() + ai.IdleTime;
					moveTick = true;
				}
				if (moveTick)
				{
					if (!ai.Moving)
					{
						// Either look around or move to a new position
						if (GetRandomInt(1, 10) > 4)
							ai.SetTargetAngle(FindNewLookAngle());
						else
						{
							// Get a random position around the drone to move to
							FVector movePos;
							float radius = ai.MoveRange;
							float minRad = ai.MinMoveRange;
							float height = ai.MaxMoveHeight;
							float hover = ai.HoverHeight;
							movePos = FindPositionAroundLocation(drone, drone.GetPosition(), radius, minRad, hover, height);
							MoveToPosition(ai, movePos);
						}
					}
					else
					{
						// We can still change direction if we choose to
						if (GetRandomInt(1, 10) > 3)
						{
							FVector movePos;
							float radius = ai.MoveRange;
							float minRad = ai.MinMoveRange;
							float height = ai.MaxMoveHeight;
							float hover = ai.HoverHeight;
							movePos = FindPositionAroundLocation(drone, ai.GetMovePosition(), radius, minRad, hover, height);
							FRotator velocityRot, direction;
							velocityRot = Vector_GetAngles(drone.GetVelocity());
							direction = Vector_GetAngles(movePos);

							float angle = FMath.GetAngle(velocityRot, direction);
							if (angle < 90.0) // Do not completely change direction while already moving
							{
								ai.SetMovePosition(movePos);
							}
						}
					}
				}
			}
			// If this seat has a weapon, perform weapon checks
			if (seat.HasWeapon())
			{
				APersistentObject target = ai.CurrentTarget;

				if (thinkTick)
				{
					// Search for a target
					if (!target)
					{
						ai.CurrentTarget = FindClosestTarget(ai, drone);
					}
					// Otherwise enter attack state if we can see our target
					else if (CanSeeTarget(drone, target))
					{
						ai.CurrentState = Controller_Attacking;

						// Update our move position to be around our target
						if (ai.Moving)
						{
							FVector movePosition;
							movePosition = FindTargetPosition(ai, drone, target);

							ai.SetMovePosition(movePosition);
							ai.NextMovementTime = GetGameTime() + ai.IdleTime * 2.0; // double our next move time
						}
					}
				}
			}
		}
		case Controller_Attacking:
		{
			bool moveTick = false;

			if (seat.HasWeapon() && weapon)
			{
				APersistentObject target = ai.CurrentTarget;

				if (thinkTick)
				{
					if (target && CanSeeTarget(drone, target))
					{
						FRotator angleTowardsEnemy;
						FVector vecTowardsEnemy;

						vecTowardsEnemy = Vector_MakeFromPoints(drone.GetPosition(), target.GetPosition());
						angleTowardsEnemy = Vector_GetAngles(vecTowardsEnemy);
						ai.SetTargetAngle(angleTowardsEnemy);

						if (ai.NextCombatCheckTime <= GetGameTime())
						{
							ai.NextCombatCheckTime = GetGameTime() + params.CombatTime;
							target = FindClosestTarget(ai, drone);
						}

						if (ai.NextMovementTime <= GetGameTime())
						{
							moveTick = true;
						}

						if (moveTick && !ai.Moving)
						{
							FVector movePosition;
							movePosition = FindTargetPosition(ai, drone, target);

							MoveToPosition(ai, movePosition);
						}

						if (DroneInRange(ai, drone, target))
						{
							if (!ai.InAttack && weapon.State == WeaponState_Ready)
							{
								if (ai.NextFireTime <= GetGameTime())
								{
									ai.InAttack = true;
									if (params.BurstTime <= 0.0) // hold down fire as long as we have a target
									{
										ai.EndFireTime = -1.0;
									}
									else
									{
										ai.EndFireTime = GetGameTime() + params.BurstTime;
									}
								}
							}
						}
						else if (moveTick)
						{
							FVector movePosition;
							movePosition = FindTargetPosition(ai, drone, target);

							MoveToPosition(ai, movePosition);
						}

						// Also check if we are too close
						if (!ai.Moving && DroneTooClose(ai, drone, target))
						{
							// Move further away
							FVector movePosition;
							movePosition = FindTargetPosition(ai, drone, target);

							MoveToPosition(ai, movePosition);
						}
					}
					else
					{
						ai.CurrentTarget = null;
						ai.CurrentState = Controller_Idle; // return to idle for now
					}
				}

				if (moveTick)
				{
					ai.NextMovementTime = GetGameTime() + ai.IdleTime;
				}

				if (ai.InAttack)
				{
					OnDroneAIAttack(ai, weapon, drone, seat);
					if (ai.EndFireTime <= -1.0)
					{
						if (!target || !(weapon.State == WeaponState_Ready)) // We lose our target or our weapon is no longer ready
						{
							ai.InAttack = false;
							ai.NextFireTime = GetGameTime() + params.BurstDelay;
						}
					}
					else if (ai.EndFireTime <= GetGameTime())
					{
						ai.InAttack = false;
						ai.NextFireTime = GetGameTime() + params.BurstDelay;
					}
				}
			}
		}
	}
}

bool DroneInRange(FDroneAI ai, ADrone drone, APersistentObject target)
{
	bool result = false;

	if (target && FGameplayStatics.GetDistanceBetweenObjects(drone.GetObject(), target.GetObject()) <= ai.DesiredAttackRange)
	{
		result = true;
	}

	return result;
}

bool DroneTooClose(FDroneAI ai, ADrone drone, APersistentObject target)
{
	bool result = false;

	if (target && FGameplayStatics.GetDistanceBetweenObjects(drone.GetObject(), target.GetObject()) < ai.MinAttackRange)
	{
		result = true;
	}

	return result;
}

void ClampVector(FVector vector, float magnitude)
{
	FVector temp;
	temp = vector;
	float sizeSquared = (temp.X * temp.X + temp.Y * temp.Y + temp.Z * temp.Z);
	if (sizeSquared > Pow(magnitude, 2.0))
	{
		float scale = magnitude * (1.0 / Pow(sizeSquared, 0.5));
		vector.X *= scale;
		vector.Y *= scale;
		vector.Z *= scale;
	}
}

void CalcMovementVector(FDroneAI ai, ADrone drone, FVector velocity, FVector direction)
{
	float scale = drone.Acceleration;

	// Check if we should be decelerating first
	if (ai.Moving)
	{
		FRotator velRotation, inputRotation;
		velRotation = Vector_GetAngles(drone.GetVelocity());
		inputRotation = Vector_GetAngles(direction);

		float angle = FMath.GetAngle(velRotation, inputRotation);
		if (angle > 25.0)
		{
			scale = drone.Deceleration;
		}
	}

	//PrintCenterTextAll("Drone acceleration = %.1f", scale);

	FVector currentVel, inputVel;
	currentVel = direction;
	currentVel.Normalize();
	currentVel.Scale(scale);

	inputVel = drone.GetInputVelocity();
	inputVel.Add(currentVel);

	ClampVector(inputVel, drone.MaxSpeed);

	drone.SetInputVelocity(inputVel);

	//FVector realVel;
	//realVel = drone.GetVelocity();
	//currentVel.Add(realVel);
	velocity.Add(inputVel);
	ClampVector(velocity, drone.MaxSpeed);
}

void CalcMovementTilt(ADrone drone, bool reverse)
{
	FRotator rotation;
	rotation = drone.GetInputRotation();

	rotation.Pitch = FMath.ClampFloat(CalcForwardTilt(drone, drone.GetInputVelocity(), 0.45, reverse), -22.0, 22.0);
	rotation.Roll = FMath.ClampFloat(CalcRightTilt(drone, drone.GetInputVelocity(), 0.45, reverse), -35.0, 35.0);

	drone.SetInputRotation(rotation);
}

FVector FindPositionAroundLocation(ADrone drone, FVector location, float radius, float minDistance, float minHeight = 0.0, float maxHeight = 0.0)
{
	FVector result;

	if (minDistance > 0.0)
	{
		result = RandomUnitVector();
		result.Scale(GetRandomFloat(minDistance, radius));
		result.Add(location);
	}
	else
	{
		result = location;

		result.X += GetRandomFloat(-radius, radius);
		result.Y += GetRandomFloat(-radius, radius);
		result.Z += GetRandomFloat(-radius, radius);
	}

	if (maxHeight && maxHeight < radius) // Limit our height if applicable. we dont care about having a minimum distance for this
	{
		result.Z = location.Z;
		result.Z += GetRandomFloat(-radius, maxHeight); // We can still travel down normally
	}

	FVector mins, maxs;
	mins = drone.GetComponents().MinBounds;
	maxs = drone.GetComponents().MaxBounds;
	FHullTrace trace = new FHullTrace(drone.GetPosition(), result, mins, maxs, MASK_SHOT, DroneMovementTrace, drone);
	result = trace.GetEndPosition();
	//trace.DebugTrace();
	if (trace.DidHit()) // Shift off the hit surface by this drone's pathfind radius
	{
		FVector normal;
		normal = trace.GetNormalVector();

		normal.Scale(200.0);

		result.Add(normal);
	}
	delete trace;

	// Now check our height
	FVector end;
	end = result;
	end.Z -= minHeight - 5.0;
	trace = new FHullTrace(result, end, mins, maxs, MASK_SHOT, FilterIgnorePlayersEx, drone.Get());
	//trace.DebugTrace();
	if (trace.DidHit())
	{
		result = trace.GetEndPosition();
		FVector normal;
		normal = trace.GetNormalVector();

		normal.Scale(minHeight);

		result.Add(normal);
	}
	delete trace;

	return result;
}

FVector RandomUnitVector()
{
	FVector result;
	float length;

	do
	{
		// Check random vectors in the unit sphere so result is statistically uniform.
		result.X = GetURandomFloat() * 2.0 - 1.0;
		result.Y = GetURandomFloat() * 2.0 - 1.0;
		result.Z = GetURandomFloat() * 2.0 - 1.0;
		length = (result.X * result.X + result.Y * result.Y + result.Z * result.Z);
	}
	while (length > 1.0 || length < 0.001);

	result.Scale(1.0 / Pow(length, 0.5));

	return result; 
}

/*
FVector GetGroundPosition(ADrone drone, FVector position)
{
	FVector buffer;
	buffer = position;
	buffer.Z -= 9000.0;
	FRayTraceSingle trace = new FRayTraceSingle(position, buffer, MASK_SHOT, GenericFilter, drone.Get());
	buffer = trace.GetEndPosition();

	delete trace;

	return buffer;
}
*/

APersistentObject FindClosestTarget(FDroneAI ai, ADrone drone, bool enemy = true)
{
	TFTeam team = drone.Team;
	float distance;
	float range = ai.DetectionRange; // Will be configurable
	float closest = range;

	APersistentObject best;
	AClient test;

	// Clients first
	FClient client;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			client = ConstructClient(i);
			if (enemy)
			{
				if (client.GetTeam() == view_as<int>(team))
				{
					continue;
				}
			}

			if (!client.Alive())
			{
				continue;
			}

			distance = FGameplayStatics.GetDistanceBetweenObjects(drone.GetObject(), client.GetObject());
			if (distance < closest)
			{
				test = FEntityStatics.GetClient(client);
				if (CanSeeTarget(drone, test))
				{
					closest = distance;
					best = test;
				}
			}
		}
	}

	return best;
}

bool CanSeeTarget(ADrone drone, APersistentObject target)
{
	FVector start, end;
	start = drone.GetPosition();
	end = target.GetPosition();
	end.Z += 40.0;

	FClient client;
	client = CastToClient(target.GetObject());
	if (client.Valid())
	{
		if (!client.Alive())
		{
			return false;
		}
	}

	FRayTraceSingle trace = new FRayTraceSingle(start, end, MASK_SHOT, DroneMovementTrace, drone);
	if (trace.DidHit())
	{
		FObject hit;
		hit = trace.GetHitEntity();
		if (hit.Get() == target.Get())
		{
			delete trace;
			return true;
		}
	}
	delete trace;
	return false;
}

bool DroneMovementTrace(int entity, int mask, ADrone drone)
{
	if (entity == drone.Get())
		return false;

	if (entity <= MaxClients && entity > 0)
	{
		return true;
	}
	
	if (ConstructObject(entity).Cast("prop_physics"))
	{
		return false;
	}

	return true;
}


// returns a random rotation range
FRotator FindNewLookAngle()
{
	FRotator rot;
	rot.Pitch = GetRandomFloat(-60.0, 60.0);
	rot.Yaw = GetRandomFloat(-180.0, 180.0);

	//PrintToChatAll("New look angle pitch = %.1f\nyaw = %.1f", rot.Pitch, rot.Yaw);

	return rot;
}

FTransform FindTargetPosition(FDroneAI ai, ADrone drone, APersistentObject target)
{
	FVector position;
	position = FindPositionAroundLocation(drone, target.GetPosition(), ai.DesiredAttackRange, ai.MinAttackRange, ai.HoverHeight, ai.MaxCombatHeight);

	// If we should remain level with our target, do not go below their height position
	if (ai.LevelCombat)
	{
		if (position.Z < target.GetPosition().Z)
		{
			position.Z = target.GetPosition().Z + ai.HoverHeight; // stay above based on our hovering height

			// Now make sure we can see this position as well
			position = FindPositionAroundLocation(drone, position, 20.0, 0.0);
		}
	}

	return position;
}

void MoveToPosition(FDroneAI ai,FVector position)
{
	ai.SetMovePosition(position);
	ai.Moving = true;
	ai.Stalling = false;
}

float CalcForwardTilt(ADrone drone, FVector velocity, float adjust = 0.1, bool reverse = false)
{
	FRotator rot;
	rot = drone.GetAngles();

	rot.Pitch = 0.0;

	FVector forwardVec;
	forwardVec = rot.GetForwardVector();

	float tilt = Vector_DotProduct(velocity, forwardVec);

	if (reverse)
		adjust *= -0.5;

	return tilt * adjust;
}

float CalcRightTilt(ADrone drone, FVector velocity, float adjust = 0.1, bool reverse = false)
{
	FRotator rot;
	rot = drone.GetAngles();

	rot.Roll = 0.0;

	FVector rightVec;
	rightVec = rot.GetRightVector();

	float tilt = Vector_DotProduct(velocity, rightVec);

	if (reverse)
		adjust *= -0.6;

	return tilt * adjust;
}
