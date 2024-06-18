/* Aggressive drone behaviors
 *
 * Aggressive drones will act as guards around their current position
 * They may move around the area while looking for targets, or remain completely stationary
 * Aggressive drones will pursue targets after line of sight has been broken, if `DroneAIParams.PursueTarget` is set to true
 * If pursuing, aggressive drones will retrace steps of the lost target and continue in that direction until giving up
 * 
 */


void Aggressive_SimulateIdle(FDroneAI ai, FDroneSeat seat, ADrone drone, bool thinkTick)
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
					FDroneMoveParams params;
					params.MaxDist = ai.MoveRange;
					params.MinDist = ai.MinMoveRange;
					params.Ceiling = ai.MaxMoveHeight;
					params.MinHeight = ai.HoverHeight;
					DroneFindMovePosition(ai, drone, drone.GetPosition(), params);
				}
			}
			/*
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
					movePos = FindPositionAroundLocation(ai, drone, ai.GetMovePosition(), radius, minRad, hover, height);
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
			*/
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
				ChangeControllerState(ai, Controller_Attacking);

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

void Aggressive_SimulateAttack(FDroneAI ai, FDroneSeat seat, ADrone drone, ADroneWeapon weapon, FDroneAIParams params, bool thinkTick)
{
	if (seat.HasWeapon() && weapon)
	{
		bool moveTick = false;
		APersistentObject target = ai.CurrentTarget;

		if (thinkTick)
		{
			if (target && CanSeeTarget(drone, target) && InDetectionRange(ai, drone, target))
			{
				// If we can see our target and they are within our detection range, lets process our combat requests
				FRotator angleTowardsEnemy;
				FVector vecTowardsEnemy;

				FVector targPos;
				targPos = target.GetPosition();
				targPos.Z += 60.0;

				vecTowardsEnemy = Vector_MakeFromPoints(drone.GetPosition(), targPos);
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
					// Find a position around our target
					FDroneMoveParams move;
					move.MaxDist = ai.DesiredAttackRange;
					move.MinDist = ai.MinAttackRange;
					move.Ceiling = ai.MaxCombatHeight;
					move.MinHeight = ai.HoverHeight;

					DroneFindMovePosition(ai, drone, targPos, move);
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
				else // Immediately move into range if we are not currently
				{
					FDroneMoveParams move;
					move.MaxDist = ai.DesiredAttackRange;
					move.MinDist = ai.MinAttackRange;
					move.Ceiling = ai.MaxCombatHeight;
					move.MinHeight = ai.HoverHeight;

					DroneFindMovePosition(ai, drone, targPos, move);
				}

				// Also check if we are too close
				if (!ai.Moving && DroneTooClose(ai, drone, target))
				{
					// Move further away
					FDroneMoveParams move;
					move.MaxDist = ai.DesiredAttackRange;
					move.MinDist = ai.MinAttackRange;
					move.Ceiling = ai.MaxCombatHeight;
					move.MinHeight = ai.HoverHeight;

					DroneFindMovePosition(ai, drone, targPos, move);
				}
			}
			else
			{
				ai.CurrentTarget = null;

				// If we can pursue, let's set our state to pursue
				if (params.PursueTarget)
				{
					ai.TargetQueryIndex = 0;
					ChangeControllerState(ai, Controller_Seeking);
					ai.EndPursuitTime = GetGameTime() + ai.GetControllerParams().SeekTime;
				}
				else // Otherwise return to idle and lose our target
				{
					ChangeControllerState(ai, Controller_Idle);
				}
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

void Aggressive_SimulatePursuing(FDroneAI ai, FDroneSeat seat, ADrone drone, FDroneAIParams params, bool thinkTick)
{
	if (seat.Type == Seat_Pilot && thinkTick)
	{
		bool moveTick = false;
		if (ai.NextMovementTime <= GetGameTime())
		{
			ai.NextMovementTime = GetGameTime() + 0.5;
			moveTick = true;
		}

		if (moveTick)
		{
			FVector queriedPosition;
			ai.TargetQueryPositions.GetArray(ai.TargetQueryIndex, queriedPosition, sizeof FVector);

			if (ai.TargetQueryIndex == 0)
			{
				FVector direction;
				direction = Vector_MakeFromPoints(drone.GetPosition(), queriedPosition);
				direction.Scale(100.0);
				queriedPosition.Add(direction);
			}

			queriedPosition.Z += 50.0;
			
			FDroneMoveParams move;
			move.MaxDist = 5.0;
			move.MinDist = 0.0;
			move.Ceiling = params.CombatCeiling;
			move.MinHeight = ai.HoverHeight;
			DroneFindMovePosition(ai, drone, queriedPosition, move);

			FVector movePosition;
			//movePosition = FindPositionAroundLocation(ai, drone, queriedPosition, 20.0, 0.0, ai.HoverHeight, params.CombatCeiling);
			
			movePosition = ai.GetMovePosition();
			if (movePosition.DistanceTo(drone.GetPosition()) <= GetBrakingDistance(drone))
			{
				EndMove(ai);
			}
			ai.TargetQueryIndex++;

			if (ai.TargetQueryIndex >= ai.MaxQueriedPositions || ai.EndPursuitTime <= GetGameTime())
			{
				ChangeControllerState(ai, Controller_Idle); // If we cant find any targets, go back to being idle
			}
		}

		APersistentObject target = ai.CurrentTarget;

		if (!target)
		{
			ai.CurrentTarget = FindClosestTarget(ai, drone);
		}
		// Otherwise enter attack state if we can see our target
		else if (CanSeeTarget(drone, target))
		{
			ChangeControllerState(ai, Controller_Attacking);
		}
	}
}
