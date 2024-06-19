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

	SimulateDecisionTree(ai, seat, drone, thinkTick);

	if (seat.Type == Seat_Pilot)
	{	
		FVector velocity;
		if (ai.Moving)
		{
			FVector moveDir;
			moveDir = Vector_MakeFromPoints(drone.GetPosition(), ai.GetMovePosition());

			// If we do not have a target, turn towards the direction we are moving
			if (ai.CurrentState != Controller_Attacking)
				ai.SetTargetAngle(Vector_GetAngles(moveDir));
					
			CalcMovementVector(ai, drone, velocity, moveDir);

			if (drone.GetPosition().DistanceTo(ai.GetMovePosition()) < GetBrakingDistance(drone)) // 270.0
			{
				EndMove(ai);
				if (ai.CurrentState == Controller_Seeking)
				{
					ai.NextMovementTime = GetGameTime() + 0.5;
				}
				else if (drone.GetVelocity().Length() >= 150.0)
				{
					ai.NextMovementTime = GetGameTime() + GetRandomFloat(1.5, 3.5); // Slight delay before next move
				}
			}
		}
		else // If we arent currently moving to a position, negate our input direction and begin braking
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

		CalcMovementTilt(drone, ai.Stalling);
		if (!ai.OverrideMovement)
		{
			SimulateDrone(drone, velocity, drone.MaxSpeed);
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

void SimulateDecisionTree(FDroneAI ai, FDroneSeat seat, ADrone drone, bool thinkTick)
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

void DroneFindMovePosition(FDroneAI controller, ADrone drone, FVector position, FDroneMoveParams params, bool bDebug = false)
{
	FVector movePos;
	Action move = ForwardDronePosition(controller, drone, movePos);
	if (move == Plugin_Continue)
	{
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
	if (bDebug)
		trace.DebugTrace(0.5);
	if (trace.DidHit()) // Shift off the hit surface by this drone's pathfind radius
	{
		FVector normal;
		normal = trace.GetNormalVector();

		normal.Scale(ai.GetControllerParams().PathFindRadius);

		result.Add(normal);
	}
	delete trace;

	// Now check our height
	FVector end;
	end = result;
	end.Z -= minHeight - 5.0;
	trace = new FHullTrace(result, end, mins, maxs, MASK_SHOT, FilterIgnorePlayersEx, drone.Get());
	//trace.DebugTrace(0.5);
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

float GetBrakingDistance(ADrone drone)
{
	float speed = drone.GetVelocity().Length();
	float decel = drone.Deceleration * (1 / GetGameFrameTime()); // Hu/s

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

	Action result = Plugin_Continue;
	Call_StartForward(DroneAIFindTarget);

	Call_PushCell(ai);
	Call_PushCell(drone);
	Call_PushCell(enemy);
	Call_PushCellRef(best);

	Call_Finish(result);

	if (result == Plugin_Handled || result == Plugin_Changed)
	{
		return best;
	}

	// Clients first
	FClient client;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			client = ConstructClient(i);
			if (enemy) // Enemies only
			{
				if (client.GetTeam() == view_as<int>(team))
				{
					continue;
				}
			}
			else // otherwise only look for teammates
			{
				if (client.GetTeam() != view_as<int>(team))
				{
					continue;
				}
			}

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
						if (CanSeeTarget(drone, owner))
						{
							return owner;
						}
					}
				}
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

	// TODO - check buildings too
	if (!playersOnly)
	{

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

	FRayTraceSingle trace = new FRayTraceSingle(start, end, MASK_SHOT, DroneVisionTrace, drone);
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

bool DroneVisionTrace(int entity, int mask, ADrone drone)
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

bool DroneMovementTrace(int entity, int mask, ADrone drone)
{
	if (entity == drone.Get())
		return false;

	if (entity <= MaxClients && entity > 0)
	{
		return false;
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

FVector FindTargetPosition(FDroneAI ai, ADrone drone, APersistentObject target)
{
	FVector position;
	position = FindPositionAroundLocation(ai, drone, target.GetPosition(), ai.DesiredAttackRange, ai.MinAttackRange, ai.HoverHeight, ai.MaxCombatHeight);

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
	ai.SetMovePosition(position);
	ai.Moving = true;
	ai.Stalling = false;
}

void EndMove(FDroneAI controller)
{
	controller.Moving = false;
	controller.Stalling = true;
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
