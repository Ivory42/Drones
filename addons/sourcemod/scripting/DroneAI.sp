#include "AIControllers/AggressiveAI.sp"
#include "AIControllers/SupportAI.sp"

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

	if (drone.MoveType == MoveType_Physics)
	{
		if (drone.Stunned)
		{
			//PrintCenterTextAll("Drone stunned for %.1fs", drone.StunnedUntilTime - GetGameTime());
		}
		if (drone.Stunned && drone.StunnedUntilTime <= GetGameTime())
		{
			drone.Stunned = false;
		}
	}

	SimulateDecisionTree(ai, seat, drone, thinkTick);

	if (seat.Type == Seat_Pilot)
	{	
		FVector velocity;
		if (ai.Moving)
		{
			FVector moveDir, lookDir;

			switch (drone.MoveType)
			{
				case MoveType_Fly:
				{
					moveDir = drone.GetAngles().GetForwardVector();
				}
				default:
				{
					moveDir = Vector_MakeFromPoints(drone.GetPosition(), ai.GetMovePosition());
				}
			}

			if (drone.MoveType == MoveType_Physics && !ai.OverrideMovement)
			{
				//PrintCenterTextAll("Drone Physics movement");
				if (!drone.Stunned)
				{
					// Motor handles physics movement
					FVector movepos;
					movepos = ai.GetMovePosition();
					movepos.Z = drone.GetPosition().Z; // Always level out our position
					ai.SetMovePosition(movepos);
					
					FVector motorDir;
					motorDir = moveDir;
					motorDir.Z = 0.0; // No vertical movement
					motorDir.Normalize();

					FVector vecRight;
					vecRight = Vector_GetAngles(motorDir).GetRightVector();
					vecRight.Negate();

					//FRayTraceSingle trace = new FRayTraceSingle(drone.GetPosition(), ai.GetMovePosition(), MASK_SHOT, DroneMovementTrace, drone);
					//trace.DebugTrace(0.2);

					FObject motor;
					motor = drone.GetComponents().Motor;
					if (motor.Valid())
					{
						motor.SetPropVector(Prop_Data, "m_axis", vecRight);
						motor.Input("Deactivate");
						motor.Input("Activate");

						//PrintCenterTextAll("Applying motor force on axis: %.1f, %.1f, %.1f", vecRight.X, vecRight.Y, vecRight.Z);
					}
				}
			}
			
			// If we do not have a target, turn towards the direction we are moving
			if (ai.GetControllerParams().AimTowardsMovement && ai.CurrentState != Controller_Attacking && drone.MoveType != MoveType_Physics)
			{
				lookDir = Vector_MakeFromPoints(drone.GetPosition(), ai.GetMovePosition());
				ai.SetTargetAngle(Vector_GetAngles(lookDir));
			}
			
			if (drone.MoveType == MoveType_Fly)
			{
				FVector inputs;
				GetSmoothedVelocity(drone, velocity);
				float maxSpeed = drone.MaxSpeed;
				OnDroneMoveForward(drone, 1.0, inputs);

				if (velocity.Length() < maxSpeed)
				{
					velocity.Add(inputs);
				}
			}
			else if (drone.MoveType != MoveType_Physics)
			{
				CalcMovementVector(ai, drone, velocity, moveDir);
			}

			float timeout = 99990.0;
			ai.GetValue("MoveTimeoutTime", timeout);
			
			if (drone.GetPosition().DistanceTo(ai.GetMovePosition()) < GetBrakingDistance(drone) || timeout <= GetGameTime()) // 270.0
			{
				EndMove(ai);
				if (drone.MoveType == MoveType_Fly)
				{
					ai.NextMovementTime = GetGameTime() + 0.0; // Very little delay between movement when piloting a flying drone
				}
				else if (ai.CurrentState == Controller_Seeking)
				{
					ai.NextMovementTime = GetGameTime() + 0.5;
				}
				else if (drone.GetVelocity().Length() >= 150.0)
				{
					ai.NextMovementTime = GetGameTime() + GetRandomFloat(1.5, 3.5); // Slight delay before next move
				}
			}
		}
		else if (drone.MoveType != MoveType_Physics) // If we arent currently moving to a position, negate our input direction and begin braking
		{
			FVector inputVel, currentVel, targetVel;
			currentVel = drone.GetVelocity();
			if (currentVel.Length() > 15.0)
			{
				targetVel = currentVel;
				targetVel.Negate();

				inputVel = drone.GetInputVelocity();
				inputVel = FMath.InterpVectorTo(inputVel, targetVel, GetGameFrameTime(), ai.GetControllerParams().Braking); // 0.95
				drone.SetInputVelocity(inputVel);

				velocity.Add(inputVel);
			}
		}
		else
		{
			//PrintCenterTextAll("Not moving");
		}

		if (ai.AvoidanceCheckTime <= GetGameTime() && drone.MoveType != MoveType_Physics)
		{
			ai.AvoidanceCheckTime = GetGameTime() + 0.10;
			// Collision avoidance. If we are about to hit an object, try to move away
			FVector position, checkPos;
			position = drone.GetPosition();
			checkPos = velocity;
			checkPos.Scale(0.75); // about 750ms ahead
			checkPos.Add(position);

			FVector mins, maxs, result;
			mins = drone.GetComponents().MinBounds;
			maxs = drone.GetComponents().MaxBounds;

			mins.Z /= 2.0;
			maxs.Z /= 2.0;

			if (DebugAI.BoolValue)
			{
				FVector minstest, maxstest;
				minstest = mins;
				maxstest = maxs;
				Tempent_DrawBox(drone.GetPosition(), minstest, maxstest);
			}
			FHullTrace trace = new FHullTrace(position, checkPos, mins, maxs, MASK_SHOT_HULL, DroneMovementTrace, drone);
			if (DebugAI.BoolValue)
			{
				trace.DebugTrace(0.2);
			}
			if (trace.DidHit()) // There is something in our way, let's move backwards
			{
				result = trace.GetNormalVector();
				result.Scale(ai.HoverHeight);
				result.Add(checkPos);

				FDroneMoveParams move; // empty set
				DroneFindMovePosition(ai, drone, result, move, DebugAI.BoolValue);
				ai.AvoidanceCheckTime = GetGameTime() + ai.GetControllerParams().AvoidanceCheckDelay; // Slight delay so we dont keep recalculating our path

				// Disengage if we have a target
				if (drone.MoveType == MoveType_Fly && ai.CurrentState == Controller_Attacking)
				{
					ChangeControllerState(ai, Controller_Disengaged);
				}
			}
			delete trace;
		}

		CalcMovementTilt(drone, ai.Stalling);
		if (!ai.OverrideMovement)
		{
			if (drone.MoveType != MoveType_Physics)
			{
				SimulateDrone(drone, velocity, drone.MaxSpeed, true);
			}
		}
	}

	// Now handle our view angles
	if (seat)
	{
		FRotator desiredAngle;
		desiredAngle = currentAngle;
		OnDroneAimChanged(desiredAngle, seat, drone);

		currentAngle = FMath.InterpRotatorTo(currentAngle, ai.GetTargetAngle(), GetGameFrameTime(), ai.GetControllerParams().AimSpeed);
		ai.SetViewAngle(currentAngle);

		/*
		FVector start, end;
		start = drone.GetCamera().GetPosition();
		end = currentAngle.GetForwardVector();
		end.Scale(1000.0);
		end.Add(start);
		
		FRayTraceSingle trace = new FRayTraceSingle(start, end, MASK_SHOT, DroneVisionTrace, drone);
		trace.DebugTrace(0.1);
		delete trace;

		FVector target;
		target = ai.GetTargetAngle().GetForwardVector();
		target.Scale(1000.0);
		target.Add(start);
		trace = new FRayTraceSingle(start, target, MASK_SHOT, DroneVisionTrace, drone);
		trace.DebugTrace(0.1);
		delete trace;
		*/
	}
}

/*
FVector ScalePosition(FVector position, FRotator rotation, float scale)
{
	FVector scalar;
	scalar = FMath.OffsetVector(position, rotation, ConstructVector(scale, 0.0, 0.0));

	scalar.Add(position);

	return scalar;
}
*/

/*
void AIMoveTowardsLastDirection(ADrone drone, FDroneAI controller, FVector currentTarget)
{
	FVector velocity;
	velocity = controller.GetLastSeenVelocity();

	FVector position;
	position = ScalePosition(currentTarget, Vector_GetAngles(velocity), velocity.Length());

	FDroneMoveParams params;
	params.MaxDist = 0.0;
	params.MinDist = 0.0;
	params.Ceiling = 50.0;
	params.MinHeight = 5.0;
	DroneFindMovePosition(controller, drone, position, params, true);	
}
*/

FVector GetPredictedPosition(ADrone drone, APersistentObject target, FVector targPos, ADroneWeapon weapon)
{
	FVector position;
	// We can only predict with a projectile based weapon
	if (weapon.Type == WeaponType_Projectile)
	{
		ADroneProjectileWeapon projWep = view_as<ADroneProjectileWeapon>(weapon);
		FVector velocity;
		velocity = target.GetPropVector(Prop_Data, "m_vecAbsVelocity");
		float distance = FGameplayStatics.GetDistanceBetweenObjects(drone.GetObject(), target.GetObject());

		// Prediction will be very simple to save on resources. Gravity will not be taken into account and only the current speed will be factored
		float factor = distance / projWep.ProjectileSpeed;
		velocity.Scale(factor);

		//PrintCenterTextAll("Distance: %.1f|Speed: %.1f|TravelTime: %.1f", distance, projWep.ProjectileSpeed, factor);

		FVector prediction;
		prediction = targPos;
		prediction.Add(velocity);

		position = prediction;
	}

	return position;
}

FRotator FindAngleForTrajectory(FDroneAI controller, ADrone drone, FVector origin, FVector target, ADroneWeapon weapon)
{
	FRotator rotation;
	if (weapon.Type == WeaponType_Projectile)
	{
		ADroneProjectileWeapon projWep = view_as<ADroneProjectileWeapon>(weapon);
		float speed = projWep.ProjectileSpeed;
		float distance = origin.DistanceTo(target);
		float gravity = FindConVar("sv_gravity").FloatValue;
		float factor = ((gravity * distance) / Pow(speed, 2.0));

		rotation = Vector_GetAngles(Vector_MakeFromPoints(origin, target));

		if (factor >= 1.0) // There is no angle that can reach this position
		{
			rotation.Pitch -= 45.0; // 45 degrees gives us the longest range
		}
		else
		{
			rotation.Pitch -= RadToDeg(ArcSine(factor) * 0.5); // Get best angle to reach our position
		}

		NormalizeAngles(rotation);
		float pitch = rotation.Pitch;
		Action action = Plugin_Continue;
		Call_StartForward(FindTossAngle);
		Call_PushCell(controller);
		Call_PushCell(drone);
		Call_PushCell(weapon);
		Call_PushFloatRef(pitch);
		Call_Finish(action);

		if (action == Plugin_Changed)
		{
			rotation.Pitch = pitch;
		}
	}

	return rotation;
}

void SimulateDecisionTree(FDroneAI ai, FDroneSeat seat, ADrone drone, bool thinkTick)
{
	FDroneAIParams params;
	params = ai.GetControllerParams();

	ADroneWeapon weapon = null;

	if (seat.HasWeapon())
	{
		// simulate all weapons
		int weapons = seat.Weapons.Length;
		if (weapons > 0)
		{
			for (int i = 0; i < weapons; i++)
			{
				ADroneWeapon dronewep = seat.Weapons.Get(i);
				dronewep.Simulate();
			}
		}

		weapon = seat.ActiveWeapon;
	}

	switch (ai.CurrentState)
	{
		case Controller_Idle:
		{
			switch (ai.Behavior)
			{
				case Behavior_Aggressive: Aggressive_SimulateIdle(ai, seat, drone, thinkTick);
				case Behavior_Support:
				{
					Support_SimulateIdle(ai, seat, drone, thinkTick);
					FSupportAI controller = view_as<FSupportAI>(ai);
					if (thinkTick && controller.FollowTarget)
					{
						FVector targetPos;
						targetPos = controller.FollowTarget.GetPosition();
						ai.TargetQueryPositions.SetArray(ai.TargetQueryIndex, targetPos, sizeof FVector);
						ai.TargetQueryIndex++;

						ai.SetLastSeenVelocity(controller.FollowTarget.GetVelocity());

						// Reset our position index if above max
						if (ai.TargetQueryIndex >= ai.MaxQueriedPositions)
						{
							ai.TargetQueryIndex = 0;
						}
					}
				}
			}
		}
		case Controller_Attacking:
		{
			if (!drone.Stunned)
			{
				switch (ai.Behavior)
				{
					case Behavior_Aggressive: Aggressive_SimulateAttack(ai, seat, drone, weapon, params, thinkTick);
					case Behavior_Support: Support_SimulateAttack(ai, seat, drone, weapon, params, thinkTick);
				}

				if (thinkTick && ((params.PursueTarget && ai.CurrentTarget) || ai.Behavior == Behavior_Support)) // Support always tries to find its follow
				{
					FVector targetPos;
					targetPos = ai.CurrentTarget.GetPosition();
					ai.TargetQueryPositions.SetArray(ai.TargetQueryIndex, targetPos, sizeof FVector);
					ai.TargetQueryIndex++;

					ai.SetLastSeenVelocity(ai.CurrentTarget.GetVelocity());

					// Reset our position index if above max
					if (ai.TargetQueryIndex >= ai.MaxQueriedPositions)
					{
						ai.TargetQueryIndex = 0;
					}
				}
			}
		}
		case Controller_Disengaged:
		{
			switch (ai.Behavior)
			{
				case Behavior_Aggressive: Aggressive_SimulateDisengaged(ai, seat, drone, params, thinkTick);
				//case Behavior_Support: Support_SimulateDisengaged(ai, seat, drone, weapon, params, thinkTick);
			}
		}
		case Controller_Seeking:
		{
			switch (ai.Behavior)
			{
				case Behavior_Aggressive: Aggressive_SimulatePursuing(ai, seat, drone, params, thinkTick);
				case Behavior_Support: Support_SimulatePursuing(ai, seat, drone, params, thinkTick);
			}
		}
	}
}

bool InDetectionRange(FDroneAI controller, ADrone drone, APersistentObject target)
{
	bool result = false;

	if (target && FGameplayStatics.GetDistanceBetweenObjects(drone.GetObject(), target.GetObject()) <= controller.DetectionRange)
	{
		result = true;
	}

	return result;
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

bool InFOV(ADrone drone, ADroneWeapon weapon, APersistentObject target, float fov = 180.0, bool bdebug = false)
{
	bool result = false;
	if (fov <= 0.0)
	{
		fov = 180.0;
	}

	ABaseEntity source = drone;
	bool weaponUsesMount;
	if (weapon && !weapon.UsesParent)
	{
		source = weapon;
		weaponUsesMount = weapon.ComplexAngles;
	}

	// TODO - check the active weapon's fov
	FVector position, targPos;
	position = drone.GetPosition();
	targPos = target.GetPosition();

	FVector direction;
	direction = Vector_MakeFromPoints(position, targPos);

	FRotator sourceAngle;
	if (weapon && weaponUsesMount)
	{
		// combine angles from mount and weapon
		sourceAngle = weapon.GetAngles();
		sourceAngle = SubtractRotators(weapon.GetAngles(), weapon.GetMount().GetAngles());

		FVector start, end;
		start = weapon.GetWorldPosition();
		end = sourceAngle.GetForwardVector();
		end.Add(start);
		end.Scale(600.0);
	}
	else
	{
		sourceAngle = source.GetAngles();
	}
	
	float angle = FMath.GetAngle(sourceAngle, Vector_GetAngles(direction));
	if (bdebug)
	{
		PrintCenterTextAll("FOV = %.2f | max = %.2f", angle, fov);
	}
	if (angle < fov)
	{
		result = true;
	}

	return result;
}

bool DroneTooClose(FDroneAI ai, ADrone drone, APersistentObject target, float variance = 0.0, float override = 0.0)
{
	bool result = false;

	float range = ai.MinAttackRange;
	if (override > 0.0)
	{
		range = override;
	}
	if (variance > 0.0)
	{
		range += GetRandomFloat(0.0, variance);
	}
	if (target && FGameplayStatics.GetDistanceBetweenObjects(drone.GetObject(), target.GetObject()) < range)
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
			scale *= 6.0;
		}
	}

	//PrintCenterTextAll("Drone acceleration = %.3f", scale);

	FVector currentVel, inputVel;
	currentVel = direction;
	currentVel.Normalize();
	currentVel.Scale(scale);

	inputVel = drone.GetInputVelocity();
	inputVel.Add(currentVel);

	ClampVector(inputVel, drone.MaxSpeed);

	drone.SetInputVelocity(inputVel);

	velocity.Add(inputVel);
	ClampVector(velocity, drone.MaxSpeed);
}

void CalcMovementTilt(ADrone drone, bool reverse)
{
	if (drone.MoveType != MoveType_Fly && drone.MoveType != MoveType_Physics)
	{
		FRotator rotation;
		rotation = drone.GetInputRotation();

		rotation.Pitch = FMath.ClampFloat(CalcForwardTilt(drone, drone.GetInputVelocity(), 0.45, reverse), -22.0, 22.0);
		rotation.Roll = FMath.ClampFloat(CalcRightTilt(drone, drone.GetInputVelocity(), 0.45, reverse), -35.0, 35.0);

		drone.SetInputRotation(rotation);
	}
}

void DroneFindMovePosition(FDroneAI controller, ADrone drone, FVector position, FDroneMoveParams params, bool bDebug = false)
{
	FVector movePos;
	Action move = ForwardDronePosition(controller, drone, movePos);
	if (move == Plugin_Continue)
	{
		//PrintToChatAll("Proceeding with move position");
		movePos = FindPositionAroundLocation(controller, drone, position, params.MaxDist, params.MinDist, params.MinHeight, params.Ceiling, bDebug);
	}
	else if (move == Plugin_Handled || move == Plugin_Stop)
	{
		return; // do nothing
	}

	MoveToPosition(controller, movePos);
}

Action ForwardDronePosition(FDroneAI controller, ADrone drone, FVector movePosition)
{
	Action result = Plugin_Continue;
	Call_StartForward(DroneAIFindPosition);

	Call_PushCell(controller);
	Call_PushCell(drone);
	Call_PushArrayEx(movePosition, sizeof FVector, SM_PARAM_COPYBACK);

	Call_Finish(result);

	return result;
}

FVector FindPositionAroundLocation(FDroneAI ai, ADrone drone, FVector location, float radius, float minDistance, float minHeight = 0.0, float maxHeight = 0.0, bool bDebug = false)
{
	FVector result;

	if (DebugAI.BoolValue)
	{
		bDebug = true;
	}

	if (minDistance > 1.0)
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

		if (drone.MoveType != MoveType_Physics)
		{
			result.Z += GetRandomFloat(-radius, radius);
		}
	}

	if (maxHeight > 0.0 && maxHeight < radius) // Limit our height if applicable. we dont care about having a minimum distance for this
	{
		result.Z = location.Z;
		result.Z += GetRandomFloat(-radius, maxHeight); // We can still travel down normally
	}

	FVector mins, maxs;
	mins = drone.GetComponents().MinBounds;
	maxs = drone.GetComponents().MaxBounds;

	mins.Z *= 0.5;
	maxs.Z *= 0.5;

	FVector dronePos;
	dronePos = drone.GetPosition();
	dronePos.Z += 10.0;
	if (bDebug)
	{
		Tempent_DrawBox(dronePos, mins, maxs, 2.5);
	}
	FHullTrace trace = new FHullTrace(dronePos, result, mins, maxs, MASK_SHOT_HULL, DroneMovementTrace, drone);
	result = trace.GetEndPosition();
	if (bDebug)
		trace.DebugTrace(2.5);
	if (trace.DidHit() && ai.GetControllerParams().PathFindRadius > 0.0) // Shift off the hit surface by this drone's pathfind radius
	{
		FVector normal;
		normal = trace.GetNormalVector();

		normal.Scale(ai.GetControllerParams().PathFindRadius);

		result.Add(normal);
	}
	delete trace;

	// Now check our height
	if (minHeight > 0.0)
	{
		FVector end;
		end = result;
		end.Z -= minHeight - 5.0;
		trace = new FHullTrace(result, end, mins, maxs, MASK_SHOT_HULL, DroneMovementTrace, drone);
		if (bDebug)
		{
			trace.DebugTrace(2.5);
		}
		if (trace.DidHit())
		{
			result = trace.GetEndPosition();
			FVector normal;
			normal = trace.GetNormalVector();

			normal.Scale(minHeight);

			result.Add(normal);
		}
		delete trace;
	}

	if(bDebug)
	{
		//PrintToChatAll("Found Move Position: %.1f, %.1f, %.1f", result.X, result.Y, result.Z);
		Tempent_DrawBox(result, ConstructVector(-5.0, -5.0, -5.0), ConstructVector(5.0, 5.0, 5.0), 2.0);
	}

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

float GetBrakingDistance(ADrone drone)
{
	if (drone.MoveType == MoveType_Physics)
	{
		return 15.0;
	}
	float speed = drone.GetVelocity().Length();
	float decel = 8.0 * (1 / GetGameFrameTime()); // Hu/s

	float distance = 0.0;

	if (decel > 0.0)
	{
		distance = (speed * speed) / (2 * decel);
	}

	return distance;
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

APersistentObject FindClosestTarget(FDroneAI ai, ADrone drone, bool enemy = true, bool playersOnly = false)
{
	TFTeam team = drone.Team;
	float distance;
	float range = ai.DetectionRange; // Will be configurable
	float closest = range;

	APersistentObject best;
	AClient test, owner;
	ArrayList targetList = new ArrayList(64);

	Action result = Plugin_Continue;
	bool validity = true;

	// Clients first
	FClient client;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			client = ConstructClient(i);

			if (!client.Alive())
			{
				continue;
			}

			if (!enemy)
			{
				if (ai.GetControllerParams().OnlyFollowOwner && ai.Owner)
				{
					if (ai.Owner.Get() != client.Get())
					{
						continue;
					}
				}
				else if (ai.GetControllerParams().PrioritizeOwner && ai.Owner)
				{
					if (ai.Owner.Get() == client.Get())
					{
						owner = FEntityStatics.GetClient(client);
						if (CanSeeTarget(ai, drone, owner))
						{
							return owner;
						}
					}
				}
			}
			else if (ai.Owner && ai.Owner.Get() == client.Get())
			{
				continue;
			}

			test = FEntityStatics.GetClient(client);

			if (CanSeeTarget(ai, drone, test) && InFOV(drone, null, test, ai.GetControllerParams().DetectionFOV))
			{
				//PrintCenterTextAll("Visible target %d", test.Get());
				bool skip = false;
				if (enemy) // Enemies only
				{
					if (client.GetTeam() == view_as<int>(team))
					{
						validity = false; // set to false by default
						skip = true;
					}
				}
				else // otherwise only look for teammates
				{
					if (client.GetTeam() != view_as<int>(team))
					{
						validity = false;
						skip = true;
					}
				}
				// Forward to determine if the iterated target is valid for selection
				Action testValid = Plugin_Continue;
				Call_StartForward(DroneAITargetValid);
				Call_PushCell(ai);
				Call_PushCell(drone);
				Call_PushCell(test);
				Call_PushCellRef(validity);
				Call_Finish(testValid);

				if (testValid != Plugin_Continue)
				{
					if (validity)
					{
						targetList.Push(test);
					}
				}
				else
				{
					//PrintCenterTextAll("Added target %d to list", test.Get());
					if (skip)
					{
						continue;
					}
					targetList.Push(test);
				}
			}
		}
	}

	// TODO - check buildings/drones too
	if (!playersOnly)
	{
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, "prop_physics_multiplayer")) != -1)
		{
			ADrone targetDrone = CastToDrone(FEntityStatics.GetEntityFromIndex(entity));
			if (targetDrone)
			{
				if (targetDrone.Team == team)
				{
					continue;
				}

				if (!targetDrone.Alive)
				{
					continue;
				}

				if (CanSeeTarget(ai, drone, targetDrone) && InFOV(drone, null, targetDrone, ai.GetControllerParams().DetectionFOV))
				{
					// Forward to determine if the iterated target is valid for selection
					Action testValid = Plugin_Continue;
					Call_StartForward(DroneAITargetValid);
					Call_PushCell(ai);
					Call_PushCell(drone);
					Call_PushCell(targetDrone);
					Call_PushCellRef(validity);
					Call_Finish(testValid);

					if (testValid != Plugin_Continue)
					{
						if (validity)
						{
							targetList.Push(targetDrone);
						}
					}
					else
					{
						targetList.Push(targetDrone);
					}
				}
			}
		}
	}

	APersistentObject listObject;
	if (targetList.Length > 0)
	{
		for (int x = 0; x < targetList.Length; x++)
		{
			listObject = targetList.Get(x);
			if (listObject)
			{
				distance = FGameplayStatics.GetDistanceBetweenObjects(drone.GetObject(), listObject.GetObject());
				if (distance < closest)
				{
					if (CanSeeTarget(ai, drone, listObject))
					{
						closest = distance;
						best = listObject;
					}
				}
			}
		}
	}

	delete targetList;

	// Forward to override target selection
	if (best)
	{
		APersistentObject newTarget = best;
		Call_StartForward(DroneAIFindTarget);

		Call_PushCell(ai);
		Call_PushCell(drone);
		Call_PushCell(enemy);
		Call_PushCellRef(newTarget);

		Call_Finish(result);

		if (result == Plugin_Changed)
		{
			return newTarget;
		}
		if (result == Plugin_Handled)
		{
			return null;
		}
	}

	return best;
}

bool CanSeeTarget(FDroneAI controller, ADrone drone, APersistentObject target)
{
	FVector start, end;
	start = drone.GetCamera().GetPosition();
	end = target.GetPosition();
	end.Z += 55.0;

	FClient client;
	client = CastToClient(target.GetObject());
	if (client.Alive() && ClientVisible(client))
	{
		if (!client.Alive())
		{
			return false;
		}
	}

	if (controller.IgnoreWalls)
	{
		return true;
	}

	FRayTraceSingle trace = new FRayTraceSingle(start, end, MASK_SHOT_HULL, DroneVisionTrace, drone);
	if (trace.DidHit())
	{
		FObject hit;
		hit = trace.GetHitEntity();
		if (hit.Get() == target.Get())
		{
			delete trace;
			return true;
		}
		else // if something is blocking, check lower to see if we can still see the target
		{
			delete trace;

			end.Z -= 45.0;
			trace = new FRayTraceSingle(start, end, MASK_SHOT_HULL, DroneVisionTrace, drone);
			if (trace.DidHit())
			{
				hit = trace.GetHitEntity();
				if (hit.Get() == target.Get())
				{
					delete trace;
					return true;
				}
				else // One more check on the center. If this fails, we likely cant see the target
				{
					delete trace;
					
					end.Z += 25.0;
					trace = new FRayTraceSingle(start, end, MASK_SHOT_HULL, DroneVisionTrace, drone);
					if (trace.DidHit())
					{
						hit = trace.GetHitEntity();
						if (hit.Get() == target.Get())
						{
							delete trace;
							return true;
						}
					}
				}
			}
		}
	}
	delete trace;
	return false;
}

bool ClientVisible(FClient client)
{
	if (client.InCondition(TFCond_Cloaked) || client.InCondition(TFCond_Stealthed) || client.InCondition(TFCond_StealthedUserBuffFade))
	{
		return false;
	}

	return true;
}

/*
bool DroneVisionTraceNoWalls(int entity, int mask, ADrone drone)
{
	if (entity == drone.Get())
		return false;

	if (entity <= MaxClients && entity > 0)
	{
		return true;
	}

	return false;
}
*/

bool DroneVisionTrace(int entity, int mask, ADrone drone)
{
	if (entity == drone.Get())
		return false;

	if (entity <= MaxClients && entity > 0)
	{
		return true;
	}

	if (ConstructObject(entity).Cast("prop_physics_multiplayer"))
	{
		return true;
	}
	
	if (ConstructObject(entity).Cast("prop_physics"))
	{
		return false;
	}

	if (ConstructObject(entity).Cast("tf_projectile"))
	{
		return false;
	}

	if (ConstructObject(entity).Cast("obj_")) // ignore friendly buildings
	{
		//PrintCenterTextAll("Hitting building %d team = %d ourteam = %d", entity, GetEntProp(entity, Prop_Send, "m_iTeamNum"), view_as<int>(drone.Team));
		if (GetEntProp(entity, Prop_Send, "m_iTeamNum") == view_as<int>(drone.Team))
		{
			return false;
		}
	}

	return true;
}

bool DroneMovementTrace(int entity, int mask, ADrone drone)
{
	if (entity == drone.Get())
		return false;

	if (entity == 0)
	{
		return true;
	}

	if (entity > 0 && entity <= MaxClients)
	{
		return false;
	}
	
	if (ConstructObject(entity).Cast("prop_physics"))
	{
		return false;
	}

	if (ConstructObject(entity).Cast("tf_projectile"))
	{
		return false;
	}

	if (ConstructObject(entity).Cast("obj_"))
	{
		return false;
	}

	if (ConstructObject(entity).Cast("phys_"))
	{
		return false;
	}

	if (ConstructObject(entity).Cast("tf_dropped_weapon"))
	{
		return false;
	}

	if (ConstructObject(entity).Cast("tf_ammo_pack"))
	{
		return false;
	}

	return true;
}


// returns a random rotation range
FRotator FindNewLookAngle()
{
	FRotator rot;
	rot.Pitch = GetRandomFloat(-50.0, 50.0);
	rot.Yaw = GetRandomFloat(-180.0, 180.0);

	//PrintToChatAll("New look angle pitch = %.1f\nyaw = %.1f", rot.Pitch, rot.Yaw);

	return rot;
}

FVector FindTargetPosition(FDroneAI ai, ADrone drone, APersistentObject target)
{
	FVector position;
	//position = FindPositionAroundLocation(ai, drone, target.GetPosition(), ai.DesiredAttackRange, ai.MinAttackRange, ai.HoverHeight, ai.MaxCombatHeight);
	if (drone.MoveType != MoveType_Fly)
	{
		position = FindPositionAroundLocation(ai, drone, target.GetPosition(), ai.DesiredAttackRange, ai.MinAttackRange, ai.HoverHeight, ai.MaxCombatHeight);
	}
	else // Flying drones will fly directly towards their target, they can only move forward so aiming towards positions around their target is pointless
	{
		position = target.GetPosition();
		position.Z += 60.0;
	}
	// If we should remain level with our target, do not go below their height position
	if (ai.LevelCombat)
	{
		if (position.Z < target.GetPosition().Z)
		{
			position.Z = target.GetPosition().Z + ai.HoverHeight; // stay above based on our hovering height

			// Now make sure we can see this position as well
			position = FindPositionAroundLocation(ai, drone, position, 20.0, 0.0);
		}
	}

	return position;
}

void MoveToPosition(FDroneAI ai, FVector position)
{
	//PrintToChatAll("Drone moving");
	ai.SetValue("MoveTimeoutTime", GetGameTime() + 5.0); // timeout our move request after this duration
	ai.SetMovePosition(position);
	ai.Moving = true;
	ai.Stalling = false;
}

void EndMove(FDroneAI controller)
{
	controller.Moving = false;
	controller.Stalling = true;

	ADrone drone = controller.Drone;
	if (drone && drone.MoveType == MoveType_Physics)
	{
		// stop the motor
		FObject motor;
		motor = drone.GetComponents().Motor;
		motor.Input("Deactivate");
	}
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

void ChangeControllerState(FDroneAI controller, EControllerState state, bool doForward = true)
{
	EControllerState oldState = controller.CurrentState;
	if (oldState == Controller_Seeking && state != Controller_Seeking)
	{
		// If we change from seeking, reset our queries
		//controller.TargetQueryPositions.Clear();
		controller.TargetQueryIndex = 0;
		controller.PursuitEnding = false;
	}
	controller.CurrentState = state;

	if (controller.Behavior == Behavior_Support)
	{
		// reset queries when changing to aggressive or idle
		if (state == Controller_Attacking || state == Controller_Idle)
		{
			//controller.TargetQueryPositions.Clear();
			controller.TargetQueryIndex = 0;
		}
	}

	if (doForward)
	{
		Call_StartForward(DroneAIStateChanged);

		Call_PushCell(controller);
		Call_PushCell(controller.Drone);
		Call_PushCell(oldState);
		Call_PushCell(state);

		Call_Finish();
	}
}
