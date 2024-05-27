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

	// Check if this seat is a pilot, if it is we can control the movement of this drone
	if (ai.IsPilot && seat.Type == Seat_Pilot)
	{
		FVector velocity;
		if (thinkTick)
		{
			switch (ai.CurrentState)
			{
				case Controller_Idle:
				{
					// TODO - add different cases depending on the drone move type
					//PrintCenterTextAll("NextMoveTime in %.1f", ai.NextMovementTime - GetGameTime());
					if (ai.NextMovementTime <= GetGameTime())
					{
						ai.NextMovementTime = GetGameTime() + ai.IdleTime;

						ai.SetTargetAngle(FindNewLookAngle());
					}
				}
				case Controller_Attacking:
				{
					//
				}
			}
		}

		SimulateDrone(drone, velocity, drone.MaxSpeed);
	}

	// If this seat has a weapon, and this controller is flagged as a gunner
	if (ai.IsGunner && seat.HasWeapon())
	{
		FDroneAIParams params;
		params = ai.GetControllerParams();

		APersistentObject target = ai.CurrentTarget;
			
		switch (ai.CurrentState)
		{
			case Controller_Idle:
			{
				if (thinkTick)
				{
					// Let's search for a target passively
					if (!target)
					{
						ai.CurrentTarget = FindClosestTarget(drone);
					}
					// Otherwise if we can see our target, enter attack state
					else if (CanSeeTarget(drone, target))
					{
						ai.CurrentState = Controller_Attacking;
					}
				}
			}
			case Controller_Attacking:
			{
				ADroneWeapon weapon = seat.ActiveWeapon;
				weapon.Simulate();
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
							target = FindClosestTarget(drone);
						}

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
					else
					{
						ai.CurrentTarget = null;
						ai.CurrentState = Controller_Idle; // return to idle for now
					}
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

	// Handle our ai view angles if we are a drone or pilot
	if (ai.IsGunner || ai.IsPilot)
	{
		FRotator desiredAngle;
		desiredAngle = currentAngle;
		OnDroneAimChanged(desiredAngle, seat, drone);

		currentAngle = FMath.InterpRotatorTo(currentAngle, ai.GetTargetAngle(), GetGameFrameTime(), 80.0);
		ai.SetViewAngle(currentAngle);
	}
}

APersistentObject FindClosestTarget(ADrone drone, bool enemy = true)
{
	TFTeam team = drone.Team;
	float distance;
	float range = 1200.0; // Will be configurable
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

	FRayTraceSingle trace = new FRayTraceSingle(start, end, MASK_SHOT, DroneWeaponTrace, drone);
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


// returns a random rotation range
FRotator FindNewLookAngle()
{
	FRotator rot;
	rot.Pitch = GetRandomFloat(-60.0, 60.0);
	rot.Yaw = GetRandomFloat(-180.0, 180.0);

	//PrintToChatAll("New look angle pitch = %.1f\nyaw = %.1f", rot.Pitch, rot.Yaw);

	return rot;
}