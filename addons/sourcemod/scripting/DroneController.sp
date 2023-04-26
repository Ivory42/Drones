#pragma semicolon 1

void OnDroneAttack(const FClient client, const FDroneSeat seat, FDrone drone)
{

}

void OnDroneMoveForward(FDrone drone, float axisValue, FVector velocity)
{

}

void OnDroneMoveRight(FDrone drone, float axisValue, FVector velocity)
{

}

void OnDroneMoveUp(FDrone drone, float axisValue, FVector velocity)
{

}

void OnDroneAimChanged(FClient client, FDroneSeat seat, FDrone drone)
{
    FRotator currentAngle, desiredAngle;
    currentAngle = drone.GetAngles();
    desiredAngle = client.GetEyeAngles();

    if (drone.Valid() && seat.HasWeapon())
    {
        int droneId = drone.Get();
        int weaponIndex = seat.GetWeaponIndex();

        switch (seat.GetSeatType())
        {
            case Seat_Pilot: // Look direction will control the drone's angles if the angles are locked to the client view angles
            {
                if (drone.Viewlocked)
                {
                    // Smoothly rotate drone in direction the player is aiming
                    currentAngle = InterpRotation(currentAngle, desiredAngle, GetGameFrameTime(), drone.TurnRate);

                    drone.SetAngles(currentAngle);
                }
                UpdateDroneWeaponAngles(currentAngle, desiredAngle, DroneWeapons[droneId][weaponIndex]); // Update any controlled weapons
            }
            case Seat_Gunner: // Gunners can only rotate their controller weapons
            {
                UpdateDroneWeaponAngles(currentAngle, desiredAngle, DroneWeapons[droneId][weaponIndex]);
            }
        }
    }
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