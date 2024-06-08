/* Support drone behavior
 * 
 * Support drones look for movement positions around teammates or their owner if they have one
 * While idle, they will follow nearby teammates and look for available targets
 * When attacking, support drones will remain around teammates rather than pursue targets
 * 
 * Support drones are best used as "personal defense" type companions
 */


void Support_SimulateIdle(FDroneAI ai, FDroneSeat seat, ADrone drone, bool thinkTick)
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
					ai.NextMovementTime = GetGameTime() + ai.GetControllerParams().CombatMoveTime;
				}
			}
		}
	}
}

void Support_SimulateAttack(FDroneAI ai, FDroneSeat seat, ADrone drone, ADroneWeapon weapon, FDroneAIParams params, bool thinkTick)
{
	if (seat.HasWeapon() && weapon)
	{
		bool moveTick = false;
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
