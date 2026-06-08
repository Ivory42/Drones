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
	if (seat.Type == Seat_Pilot && drone.MoveType != MoveType_Physics_NoMovement) // Pilot seat controls the drone's movement
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
				if ((drone.MoveType != MoveType_Fly && drone.MoveType != MoveType_Physics) && GetRandomInt(1, 10) > 4)
					ai.SetTargetAngle(FindNewLookAngle());
				else if (!ai.Stationary)
				{
					// Get a random position around the drone to move to
					FDroneMoveParams params;
					params.MaxDist = ai.MoveRange;
					params.MinDist = ai.MinMoveRange;
					params.Ceiling = ai.MaxMoveHeight;
					params.MinHeight = ai.HoverHeight;
					//PrintToChatAll("Finding Move Position with params:\nMax = %.1f\nMin = %.1f\nCeiling = %.1f\nHeight = %.1f", params.MaxDist, params.MinDist, params.Ceiling, params.MinHeight);
					//PrintToChatAll("Idle move");
					DroneFindMovePosition(ai, drone, drone.GetPosition(), params);
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
			//PrintToConsoleAll("Simulate Aggressive: %x", seat);
			// Search for a target
			if (!target)
			{
				ai.CurrentTarget = FindClosestTarget(ai, drone, seat);
			}
			// Otherwise enter attack state if we can see our target
			else
			{
				FClient client;
				client = CastToClient(target.GetObject());
				if (client.Valid() && !client.Alive())
				{
					ai.CurrentTarget = null;
				}

				if (CanSeeTarget(ai, drone, target, seat))
				{
					ChangeControllerState(ai, Controller_Attacking);

					// Update our move position to be around our target
					if (!ai.Stationary && ai.Moving)
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
}

void Aggressive_SimulateAttack(FDroneAI ai, FDroneSeat seat, ADrone drone, ADroneWeapon weapon, FDroneAIParams params, bool thinkTick)
{
	if (seat.HasWeapon() && weapon)
	{
		bool moveTick = false;
		APersistentObject target = ai.CurrentTarget;

		if (thinkTick)
		{
			if (target && CanSeeTarget(ai, drone, target, seat) && InDetectionRange(ai, drone, target))
			{
				// If we can see our target and they are within our detection range, lets process our combat requests
				FRotator angleTowardsEnemy;
				FVector vecTowardsEnemy;

				FVector targPos;
				targPos = target.GetPosition();
				targPos.Z += 20.0;

				if (weapon.AILeadTargets)
				{
					targPos = GetPredictedPosition(drone, target, targPos, weapon);
				}
				
				if (ai.FactorGravity || WeaponFiresGrenades(weapon))
				{
					angleTowardsEnemy = FindAngleForTrajectory(ai, drone, drone.GetPosition(), targPos, weapon);
				}
				else
				{
					vecTowardsEnemy = Vector_MakeFromPoints(drone.GetPosition(), targPos);
					angleTowardsEnemy = Vector_GetAngles(vecTowardsEnemy);
				}

				if (drone.MoveType != MoveType_Physics)
				{
					ai.SetTargetAngle(angleTowardsEnemy);
				}

				if (ai.NextCombatCheckTime <= GetGameTime())
				{
					ai.NextCombatCheckTime = GetGameTime() + params.CombatTime;
					target = FindClosestTarget(ai, drone, seat);
				}

				if (!ai.Stationary && ai.NextMovementTime <= GetGameTime())
				{
					moveTick = true;
				}

				if (!ai.Stationary && moveTick && !ai.Moving)
				{
					// Find a position around our target
					FDroneMoveParams move;
					move.MaxDist = ai.DesiredAttackRange;
					move.MinDist = ai.MinAttackRange;
					move.Ceiling = ai.MaxCombatHeight;
					move.MinHeight = ai.HoverHeight;

					if (drone.MoveType == MoveType_Physics) // Temporary, will add new params for combat movement
					{
						move.MaxDist = 0.0;
						move.MinDist = 0.0;
					}

					//PrintToChatAll("Found target");
					DroneFindMovePosition(ai, drone, targPos, move);
				}

				bool inrange = DroneInRange(ai, drone, target);
				bool infov = InFOV(ai, drone, weapon, target, ai.GetControllerParams().AimFOV, false);
				//PrintCenterTextAll("in range = %d | in fov = %d", inrange, infov);
				if (inrange && infov)
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
				else if (!ai.Stationary) // Immediately move into range if we are not currently
				{
					FDroneMoveParams move;
					move.MaxDist = ai.DesiredAttackRange;
					move.MinDist = ai.MinAttackRange;
					move.Ceiling = ai.MaxCombatHeight;
					move.MinHeight = ai.HoverHeight;

					if (drone.MoveType == MoveType_Physics) // Temporary, will add new params for combat movement
					{
						move.MaxDist = 0.0;
						move.MinDist = 0.0;
					}

					//PrintToChatAll("Lost range");
					DroneFindMovePosition(ai, drone, targPos, move);
				}

				// Also check if we are too close
				if (!ai.Stationary && (drone.MoveType == MoveType_Fly || !ai.Moving) && DroneTooClose(ai, drone, target))
				{
					// Move further away
					FDroneMoveParams move;
					move.MaxDist = ai.DesiredAttackRange;
					move.MinDist = ai.MinAttackRange;
					move.Ceiling = ai.MaxCombatHeight;
					move.MinHeight = ai.HoverHeight;

					if (drone.MoveType == MoveType_Fly)
					{
						ai.InAttack = false;
						ai.NextFireTime = GetGameTime();
						ai.EndFireTime = GetGameTime();
						ChangeControllerState(ai, Controller_Disengaged);
					}

					//PrintToChatAll("Too close");
					DroneFindMovePosition(ai, drone, targPos, move);
				}
			}
			else
			{
				ai.CurrentTarget = null;

				// If we can pursue, let's set our state to pursue
				if (!ai.Stationary && params.PursueTarget)
				{
					ai.TargetQueryIndex = 0;
					ChangeControllerState(ai, Controller_Seeking);
					ai.EndPursuitTime = GetGameTime() + ai.GetControllerParams().SeekTime;
				}
				else // Otherwise return to idle and lose our target
				{
					//PrintToChatAll("lost target");
					ChangeControllerState(ai, Controller_Idle);
				}
			}
		}

		if (!ai.Stationary && moveTick)
		{
			ai.NextMovementTime = GetGameTime() + ai.IdleTime;
		}

		if (ai.InAttack)
		{
			if (!InFOV(ai, drone, weapon, target, ai.GetControllerParams().AimFOV, false))
			{
				//PrintToChatAll("lost fov");
				ai.InAttack = false;
				ai.NextFireTime = GetGameTime() + params.BurstDelay;
			}
			else
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

stock void Aggressive_SimulateDisengaged(FDroneAI ai, FDroneSeat seat, ADrone drone, FDroneAIParams params, bool thinkTick)
{
	#pragma unused params
	if (seat.Type == Seat_Pilot && thinkTick)
	{
		APersistentObject target = ai.CurrentTarget;
		if (target)
		{
			if (!DroneTooClose(ai, drone, target, 200.0, ai.GetControllerParams().DisengageRange))
			{
				ChangeControllerState(ai, Controller_Attacking);
				ai.InAttack = false;
				ai.NextFireTime = GetGameTime();
				ai.EndFireTime = GetGameTime();
			}
			else 
			{
				if (CastToClient(target.GetObject()).Valid())
				{
					FClient targetClient;
					targetClient = CastToClient(target.GetObject())
					if (!targetClient.Alive())
					{
						target = null;
						ChangeControllerState(ai, Controller_Idle);
					}
				}

				if (target)
				{
					if (!ai.Moving)
					{
						// Move away from our target
						FVector direction;
						direction = Vector_MakeFromPoints(drone.GetPosition(), target.GetPosition());
						direction.Negate();
						direction.Normalize();
						direction.Scale(ai.GetControllerParams().DisengageRange);
						direction.Add(drone.GetPosition());

						FDroneMoveParams move;
						move.MaxDist = 200.0;
						move.MinDist = 0.0;
						move.Ceiling = 200.0;
						move.MinHeight = 0.0;

						//PrintToChatAll("Disengaged");
						DroneFindMovePosition(ai, drone, direction, move);
					}
				}
			}
		}
	}
}

void Aggressive_SimulatePursuing(FDroneAI ai, FDroneSeat seat, ADrone drone, FDroneAIParams params, bool thinkTick)
{
	if (ai.Stationary)
	{
		return;
	}

	if (seat.Type == Seat_Pilot && thinkTick)
	{
		bool moveTick = false;
		if (ai.NextMovementTime <= GetGameTime())
		{
			ai.NextMovementTime = GetGameTime() + 0.5;
			moveTick = true;
		}

		if (moveTick && !ai.Moving)
		{
			if (ai.TargetQueryIndex <= ai.MaxQueriedPositions)
			{
				if (ai.TargetQueryIndex < ai.MaxQueriedPositions)
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
					//PrintToChatAll("Pursuing target");
					DroneFindMovePosition(ai, drone, queriedPosition, move);

					FVector movePosition;
					//movePosition = FindPositionAroundLocation(ai, drone, queriedPosition, 20.0, 0.0, ai.HoverHeight, params.CombatCeiling);
					
					movePosition = ai.GetMovePosition();
					if (movePosition.DistanceTo(drone.GetPosition()) <= GetBrakingDistance(drone))
					{
						EndMove(ai);
					}
				}
				ai.TargetQueryIndex++;
			}

			if (ai.TargetQueryIndex >= ai.MaxQueriedPositions)
			{
				if (ai.EndPursuitTime <= GetGameTime())
				{
					ChangeControllerState(ai, Controller_Idle); // Pursuit has ended, go back to being idle
				}

				/*
				if (!ai.PursuitEnding)
				{
					ai.PursuitEnding = true;
					
					AIMoveTowardsLastDirection(drone, ai, ai.GetMovePosition());
				}
				*/
			}

			if (ai.EndPursuitTime <= GetGameTime())
			{
				ChangeControllerState(ai, Controller_Idle);
			}
		}

		APersistentObject target = ai.CurrentTarget;

		if (!target)
		{
			ai.CurrentTarget = FindClosestTarget(ai, drone, seat);
		}
		// Otherwise enter attack state if we can see our target
		else if (CanSeeTarget(ai, drone, target, seat))
		{
			ChangeControllerState(ai, Controller_Attacking);
		}
	}
}
