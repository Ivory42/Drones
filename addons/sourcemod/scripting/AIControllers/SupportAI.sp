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
			if (ai.NextMovementTime <= GetGameTime())
			{
				ai.NextMovementTime = GetGameTime() + ai.IdleTime;
				moveTick = true;
			}
			// First we check to see if we have a target, then move to them if they are too far
			SimulateSupportFollow(support, drone, moveTick);
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
			else if (CanSeeTarget(drone, target))
			{
				ai.CurrentState = Controller_Attacking;
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
			if (ai.NextMovementTime <= GetGameTime())
			{
				moveTick = true;
			}

			SimulateSupportFollow(support, drone, moveTick);
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

void SimulateSupportFollow(FSupportAI support, ADrone drone, bool moveTick)
{
	AClient follow = support.FollowTarget;
	if (follow)
	{
		if (CanSeeTarget(drone, follow))
		{
			FVector movePos;

			// If we are too far from our target, move anyway. Otherwise, only move when we can
			//PrintCenterTextAll("Drone distance = %.1f\nSupport Range = %.1f", follow.GetPosition().DistanceTo(drone.GetPosition()), support.SupportRange);
			if (follow.GetPosition().DistanceTo(drone.GetPosition()) > support.SupportRange)
			{
				movePos = FindFollowPosition(support, drone, follow);
				MoveToPosition(support, movePos);
			}
			else if (moveTick && !support.Moving)
			{
				movePos = FindFollowPosition(support, drone, follow);
				MoveToPosition(support, movePos);
			}
		}
		else
		{
			//support.CurrentState = Controller_Seeking; // Start looking where our follow target was last
			support.FollowTarget = null;
			follow = null;
		}
	}
	else
	{
		support.FollowTarget = view_as<AClient>(FindClosestTarget(support, drone, false, true)); // Follow teammates
	}
}

FTransform FindFollowPosition(FSupportAI ai, ADrone drone, APersistentObject target)
{
	FVector position;
	position = FindPositionAroundLocation(ai, drone, target.GetPosition(), ai.SupportRange, ai.MinSupportRange, ai.HoverHeight, ai.MaxCombatHeight);

	return position;
}
