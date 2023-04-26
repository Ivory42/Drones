#pragma semicolon 1

void OnDroneAttack(const FClient client, const FDroneSeat seat, FDrone drone)
{

}

// TODO - Update movement to be based on axis value
void OnDroneMoveForward(FDrone drone, float axisValue, FVector velocity, float maxSpeed)
{
    FRotator direction;
    FVector forwardVel, backVel;

    direction = drone.GetAngles();

    int droneId = drone.Get();

    switch (drone.GetMoveType())
    {
        case MoveType_Helo:
        {
            if (axisValue > 0.0) // Forwards
                DroneSpeeds[droneId][0] += drone.Acceleration * axisValue;
            else if (axisValue < 0.0) // Backwards
                DroneSpeeds[droneId][1] += drone.Acceleration * (axisValue * -1.0);

            // decrease if no input
            if (axisValue = 0.0)
            {
                DroneSpeeds[droneId][0] -= drone.Acceleration;
                DroneSpeeds[droneId][1] -= drone.Acceleration;
            }

            // Clamp our max speed on both ends
            ClampFloat(DroneSpeeds[droneId][1], 0.0, maxSpeed);
            ClampFloat(DroneSpeeds[droneId][0], 0.0, maxspeed);

            // Tilt drone based on movement direction
            if (axisValue > 0.0)
                direction.pitch -= (drone.Acceleration * 5.0); // Base tilt speed on acceleration
            else if (axisValue < 0.0)
                direction.pitch += (drone.Acceleration * 5.0);
            else
            {
                if (direction.pitch > 0.0)
                    direction.pitch -= (drone.Acceleration * 5.0);
                else if (direction.pitch < 0.0)
                    direction.pitch += (drone.Acceleration * 5.0);
            }

            ClampFloat(direction.pitch, -25.0, 25.0);

            drone.SetAngles(direction);

            // Reset pitch for velocity calculations
            direction.pitch = 0.0;
        }
        case MoveType_Fly:
        {
            if (axisValue == 0.0)
                axisValue = -0.67;
            DroneSpeeds[droneId][0] += drone.Acceleration * axisValue;

            ClampFloat(DroneSpeeds[droneId][1], 200.0, maxSpeed); // TODO - setup minimum speed for flying drones
        }
    }

    // Now update our velocity
    forwardVel = direction.GetForwardVector();
    backVel = forwardVel;

    forwardVel.Scale(DroneSpeeds[droneId][0]);
    backVel.Scale(DroneSpeeds[droneId][1] * -1.0);

    forwardVel.Add(backVel);

    velocity.Add(frowardVel);
}

void OnDroneMoveRight(FDrone drone, float axisValue, FVector velocity, float maxSpeed)
{
    FRotator direction;
    FVector rightVel, leftVel;

    direction = drone.GetAngles();

    int droneId = drone.Get();

    switch (drone.GetMoveType())
    {
        case MoveType_Helo:
        {
            if (axisValue > 0.0) // Right
                DroneSpeeds[droneId][2] += drone.Acceleration * axisValue;
            else if (axisValue < 0.0) // Backwards
                DroneSpeeds[droneId][3] += drone.Acceleration * (axisValue * -1.0);

            // decrease if no input
            if (axisValue = 0.0)
            {
                DroneSpeeds[droneId][2] -= drone.Acceleration;
                DroneSpeeds[droneId][3] -= drone.Acceleration;
            }

            // Clamp our max speed on both ends
            ClampFloat(DroneSpeeds[droneId][2], 0.0, maxSpeed);
            ClampFloat(DroneSpeeds[droneId][3], 0.0, maxspeed);

            // Tilt drone based on movement direction
            if (axisValue > 0.0)
                direction.roll -= (drone.Acceleration * 5.0); // Base tilt speed on acceleration
            else if (axisValue < 0.0)
                direction.roll += (drone.Acceleration * 5.0);
            else
            {
                if (direction.roll > 0.0)
                    direction.roll -= (drone.Acceleration * 5.0);
                else if (direction.roll < 0.0)
                    direction.roll += (drone.Acceleration * 5.0);
            }

            ClampFloat(direction.roll, -25.0, 25.0);

            drone.SetAngles(direction);

            // Reset pitch for velocity calculations
            direction.roll = 0.0;
        }
    }

    // Now update our velocity
    rightVel = direction.GetRightVector();
    leftVel = rightVel;

    rightVel.Scale(DroneSpeeds[droneId][2]);
    leftVel.Scale(DroneSpeeds[droneId][3] * -1.0);

    rightVel.Add(leftVel);

    velocity.Add(rightVel);
}

void OnDroneMoveUp(FDrone drone, float axisValue, FVector velocity, float maxSpeed)
{
    /*
    FRotator direction;
    FVector forwardVel, backVel;

    direction = drone.GetAngles();

    int droneId = drone.Get();

    switch (drone.GetMoveType())
    {
        case MoveType_Helo:
        {
            if (axisValue > 0.0) // Forwards
                DroneSpeeds[droneId][0] += drone.Acceleration * axisValue;
            else if (axisValue < 0.0) // Backwards
                DroneSpeeds[droneId][1] += drone.Acceleration * (axisValue * -1.0);

            // decrease if no input
            if (axisValue = 0.0)
            {
                DroneSpeeds[droneId][0] -= drone.Acceleration;
                DroneSpeeds[droneId][1] -= drone.Acceleration;
            }

            // Clamp our max speed on both ends
            ClampFloat(DroneSpeeds[droneId][1], 0.0, maxSpeed);
            ClampFloat(DroneSpeeds[droneId][0], 0.0, maxspeed);

            // Tilt drone based on movement direction
            if (axisValue > 0.0)
                direction.pitch -= (drone.Acceleration * 5.0); // Base tilt speed on acceleration
            else if (axisValue < 0.0)
                direction.pitch += (drone.Acceleration * 5.0);
            else
            {
                if (direction.pitch > 0.0)
                    direction.pitch -= (drone.Acceleration * 5.0);
                else if (direction.pitch < 0.0)
                    direction.pitch += (drone.Acceleration * 5.0);
            }

            ClampFloat(direction.pitch, -25.0, 25.0);

            drone.SetAngles(direction);

            // Reset pitch for velocity calculations
            direction.pitch = 0.0;
        }
        case MoveType_Fly:
        {
            if (axisValue == 0.0)
                axisValue = -0.67;
            DroneSpeeds[droneId][0] += drone.Acceleration * axisValue;

            ClampFloat(DroneSpeeds[droneId][1], 200.0, maxSpeed); // TODO - setup minimum speed for flying drones
        }
    }

    // Now update our velocity
    forwardVel = direction.GetForwardVector();
    backVel = forwardVel;

    forwardVel.Scale(DroneSpeeds[droneId][0]);
    backVel.Scale(DroneSpeeds[droneId][0] * -1.0);

    forwardVel.Add(backVel);

    velocity.Add(frowardVel);
    */
}

void OnDroneAimChanged(FClient client, FDroneSeat seat, FDrone drone)
{
    FRotator currentAngle, desiredAngle;
    currentAngle = drone.GetAngles();
    desiredAngle = client.GetEyeAngles();

    if (drone.Valid())
    {
        int droneId = drone.Get();

        switch (seat.GetSeatType())
        {
            case Seat_Pilot: // Look direction will control the drone's angles if the angles are locked to the client view angles
            {
                if (drone.Viewlocked)
                {
                    // Smoothly rotate drone in direction the player is aiming
                    currentAngle = InterpRotation(currentAngle, desiredAngle, GetGameFrameTime(), drone.TurnRate);

                    // For flying based drones we want to adjust the roll based on how much we are turning
                    if (drone.GetMoveType() == MoveType_Fly)
                    {
                        DroneYaw[droneId][1] = DroneYaw[droneId][0]; // Set last yaw frame to previous frame
                        DroneYaw[droneId][0] = currentAngle.yaw; // Update current yaw

                        float turnRate = AngleDifference(currentAngle, desiredAngle);
                        float diff = DroneYaw[droneId][1] - DroneYaw[droneId][0];
                        bool positive = (diff > 0) != 0;

                        if (FloatAbs(turnRate) >= 0.2 && FloatAbs(diff) <= 80.0)
                        {
                            if (positive)
                                DroneRoll[droneId] = turnRate / 1.0;
                            else
                                DroneRoll[droneId] = (turnRate / 1.0) * -1.0;
                        }

                        currentAngle.roll = DroneRoll[droneId];
                        drone.SetAngles(currentAngle);
                    }
                }
                if (seat.HasWeapon())
                {
                    int weaponIndex = seat.GetWeaponIndex();
                    UpdateDroneWeaponAngles(currentAngle, desiredAngle, DroneWeapons[droneId][weaponIndex]); // Update any controlled weapons
                }
            }
            case Seat_Gunner: // Gunners can only rotate their controller weapons
            {
                if (seat.HasWeapon())
                {
                    int weaponIndex = seat.GetWeaponIndex();
                    UpdateDroneWeaponAngles(currentAngle, desiredAngle, DroneWeapons[droneId][weaponIndex]); // Update any controlled weapons
                }
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
    tempCurrent.yaw = currentAngle.yaw;
    tempTarget.yaw = targetAngle.yaw;

    forwardVec = tempCurrent.GetForwardVector();
    aimVec = tempTarget.GetForwardVector();

    return RadToDeg(ArcCosine(Vector_DotProduct(forwardVec, aimVec) / forwardVec.Length(true)));
}

void UpdateDroneWeaponAngles(FRotator current, FRotator desired, FDroneWeapon weapon)
{
    FRotator newAngle;
    newAngle = InterpRotation(current, desired, GetGameFrameTime(), weapon.TurnRate);

    // Let's determine how to use this new angle
    if (weapon.ComplexAngles)
    {
        // If we have complex angles and both a mount and receiver, split the pitch and yaw
        if (weapon.Receiver.Valid())
        {
            FRotator receiverRot;
            receiverRot.pitch = newAngle.pitch; // Angles become relative so we can keep yaw/roll at 0

            weapon.Receiver.SetAngles(receiverRot);
        }
        if (weapon.Mount.Valid())
        {
            FRotator mountRot;
            mountRot.yaw = newAngle.yaw;

            weapon.Mount.SetAngles(mountRot);
        }
    }
    else if (weapon.Receiver.Valid()) // Otherswise apply all angles onto the receiver
        weapon.Receiver.SetAngles(newAngle);
    
}

void CycleNextWeapon(const FClient client, FDroneSeat seat, FDrone drone)
{

}