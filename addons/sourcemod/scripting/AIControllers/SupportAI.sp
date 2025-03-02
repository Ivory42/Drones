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
	FSupportAI support = view_as<FSupportAI>(ai);
	if (seat.Type == Seat_Pilot) // Pilot seat controls the drone's movement
	{
		bool moveTick = false;
		if (thinkTick)
		{
			if (!ai.Stationary && ai.NextMovementTime <= GetGameTime())
			{
				ai.NextMovementTime = GetGameTime() + ai.IdleTime;
				moveTick = true;
			}
			// First we check to see if we have a target, then move to them if they are too far
			SimulateSupportFollow(support, drone, moveTick);
			if (!support.FollowTarget)
			{
				SimulateIdleNoFollow(support, drone, moveTick);
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
			// Otherwise enter attack state if we can see our target. Support drones do not move towards their targets
			else if (CanSeeTarget(ai, drone, target))
			{
				ChangeControllerState(ai, Controller_Attacking);
			}
		}
	}
}

void SimulateIdleNoFollow(FSupportAI controller, ADrone drone, bool moveTick)
{
	if (controller.Stationary)
	{
		if (GetRandomInt(1, 10) > 4)
			controller.SetTargetAngle(FindNewLookAngle());

		return;
	}

	if (moveTick)
	{
		if (!controller.Moving)
		{
			// Either look around or move to a new position
			if (GetRandomInt(1, 10) > 2)
				controller.SetTargetAngle(FindNewLookAngle());
			else
			{
				// Get a random position around the drone to move to
				FDroneMoveParams params;
				params.MaxDist = controller.MoveRange;
				params.MinDist = controller.MinMoveRange;
				params.Ceiling = controller.MaxMoveHeight;
				params.MinHeight = controller.HoverHeight;
				DroneFindMovePosition(controller, drone, drone.GetPosition(), params);
			}
		}
	}
}

void Support_SimulateAttack(FDroneAI ai, FDroneSeat seat, ADrone drone, ADroneWeapon weapon, FDroneAIParams params, bool thinkTick)
{
	if (seat.HasWeapon() && weapon)
	{
		FSupportAI support = view_as<FSupportAI>(ai);
		bool moveTick = false;
		APersistentObject target = ai.CurrentTarget;

		if (thinkTick)
		{
			if (!ai.Stationary && ai.NextMovementTime <= GetGameTime())
			{
				moveTick = true;
			}

			SimulateSupportFollow(support, drone, moveTick);
			if (target && CanSeeTarget(support, drone, target))
			{
				FRotator angleTowardsEnemy;
				FVector vecTowardsEnemy;

				FVector targPos;
				targPos = target.GetPosition();

				if (weapon.AILeadTargets)
				{
					targPos = GetPredictedPosition(drone, target, target.GetPosition(), weapon);
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

				ai.SetTargetAngle(angleTowardsEnemy);

				if (ai.NextCombatCheckTime <= GetGameTime())
				{
					ai.NextCombatCheckTime = GetGameTime() + params.CombatTime;
					target = FindClosestTarget(ai, drone);
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
			}
			else
			{
				ai.CurrentTarget = null;
				ChangeControllerState(ai, Controller_Idle); // return to idle for now
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

void Support_SimulatePursuing(FDroneAI ai, FDroneSeat seat, ADrone drone, FDroneAIParams params, bool thinkTick)
{
	if (ai.Stationary)
	{
		return;
	}

	if (seat.Type == Seat_Pilot && thinkTick)
	{
		FSupportAI support = view_as<FSupportAI>(ai);
		bool moveTick = false;
		if (ai.NextMovementTime <= GetGameTime())
		{
			ai.NextMovementTime = GetGameTime() + 0.5;
			moveTick = true;
		}

		if (moveTick && !ai.Moving)
		{
			if (ai.TargetQueryIndex <= ai.MaxQueriedPositions) // Check inclusive first
			{
				if (ai.TargetQueryIndex < ai.MaxQueriedPositions) // Now only process movement if we are within our bounds
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
					move.MaxDist = 0.0;
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
				}

				// We still want to increase our index by one more to signal we have reached the end, this is why we check inclusively first
				ai.TargetQueryIndex++;
			}
		}

		// We have reached the end of our pursuit, now move in the last seen direction of the target or give up if we have searched for long enough
		if (ai.TargetQueryIndex > ai.MaxQueriedPositions)
		{
			if (ai.EndPursuitTime <= GetGameTime())
			{
				ChangeControllerState(ai, Controller_Idle); // If we cant find any targets, go back to being idle and reset our target
				support.FollowTarget = null;
			}

			/*
			if (!ai.PursuitEnding)
			{
				ai.PursuitEnding = true;
				
				AIMoveTowardsLastDirection(drone, ai, ai.GetMovePosition());
			}
			*/
		}

		// Even if we have not reached our last seen position, end our pursuit if we take too long
		if (ai.EndPursuitTime <= GetGameTime())
		{
			ChangeControllerState(ai, Controller_Idle);
			support.FollowTarget = null;
		}

		if (support.FollowTarget && CanSeeTarget(support, drone, support.FollowTarget))
		{
			ChangeControllerState(ai, Controller_Idle); // We can see our target once again, go back to idle
		}
		else if (!support.FollowTarget) // Look for a new target while seeking
		{
			support.FollowTarget = view_as<AClient>(FindClosestTarget(support, drone, false, true))
			if (support.FollowTarget)
			{
				ChangeControllerState(ai, Controller_Idle); // If we have no target and find a new target, immediately stop seeking
			}
		}
	}
}

void SimulateSupportFollow(FSupportAI support, ADrone drone, bool moveTick)
{
	if (support.Stationary)
	{
		return;
	}

	AClient follow = support.FollowTarget;
	if (follow)
	{
		if (support.GetControllerParams().PrioritizeOwner && support.CurrentState != Controller_Attacking)
		{
			if (support.Owner && follow != support.Owner)
			{
				// Look if we can see our owner, if we can, move to them instead
				if (CanSeeTarget(support, drone, support.Owner))
				{
					support.FollowTarget = support.Owner;
				}
			}
		}
		if (CanSeeTarget(support, drone, follow))
		{
			// If we are too far from our target, move anyway. Otherwise, only move when we can
			//PrintCenterTextAll("Drone distance = %.1f\nSupport Range = %.1f", follow.GetPosition().DistanceTo(drone.GetPosition()), support.SupportRange);
			if (follow.GetPosition().DistanceTo(drone.GetPosition()) > support.SupportRange)
			{
				FDroneMoveParams params;
				params.MaxDist = 5.0;
				params.MinDist = 0.0;
				params.Ceiling = support.MaxCombatHeight;
				params.MinHeight = support.HoverHeight;
				
				DroneFindMovePosition(support, drone, follow.GetEyePosition(), params);
			}
			else if (moveTick && !support.Moving)
			{
				FDroneMoveParams params;
				params.MaxDist = support.SupportRange;
				params.MinDist = support.MinSupportRange;
				params.Ceiling = support.MaxCombatHeight;
				params.MinHeight = support.HoverHeight;
				
				DroneFindMovePosition(support, drone, follow.GetEyePosition(), params);
			}
		}
		else
		{
			support.EndPursuitTime = GetGameTime() + support.GetControllerParams().SeekTime;
			ChangeControllerState(support, Controller_Seeking); // Start looking where our follow target was last
			//support.FollowTarget = null;
			//follow = null;
		}
	}
	else
	{
		support.FollowTarget = view_as<AClient>(FindClosestTarget(support, drone, false, true)); // Follow teammates
	}
}
