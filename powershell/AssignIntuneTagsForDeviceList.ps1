#rjceledon 10/08/25
Connect-MgGraph -Scopes "User.Read.All", "Device.ReadWrite.All"

######################################################
# GET INTUNE DEVICES FOR USERS IN LIST
######################################################

$inputCsv = "Company Team_2025-10-8.csv"

$outputCsv = "user_computer_object_ids.csv"

$userList = Import-Csv -Path $inputCsv
$totalUsers = $userList.Count

$counter = 0

# Prepare results array
$results = @()

foreach ($user in $userList) {
    $counter++
    $percentComplete = ($counter / $totalUsers) * 100
    Write-Progress -Activity "Processing Users" -Status "User $counter of $totalUsers" -PercentComplete $percentComplete

    $userId = $user.id
    $userMail = $user.userPrincipalName

    # Get devices registered to the user
    $devices = Get-MgUserRegisteredDevice -UserId $userId -ErrorAction SilentlyContinue

    if ($devices.Count -eq 0) {
        Write-Host "[!] No devices found for $userMail"
    }

    foreach ($device in $devices) {
        Write-Host "[+] Found device for $userMail $($device.additionalproperties.displayName)"

        $results += [PSCustomObject]@{
            UserID            = $userId
            UserEmail         = $userMail
            DeviceDisplayName = $device.additionalproperties.displayName
            DeviceObjectID    = $device.Id
            DeviceOperatingSystem = $device.additionalproperties.operatingSystem
        }
    }
}

# Export results to CSV
$results | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8

Write-Host "✅ Export complete: $outputCsv"




######################################################
# ASSIGN INTUNE TAG FOR LIST
######################################################

# Input CSV file
$inputCsv = "user_computer_object_ids.csv"

# New tag to apply
$newTag = "[OrderID]:[OfficeSite]:US NewYork"

# Read CSV
$deviceList = Import-Csv -Path $inputCsv
$totalDevices = $deviceList.Count
$counter = 0

foreach ($device in $deviceList) {
    $counter++
    $percentComplete = ($counter / $totalDevices) * 100
    Write-Progress -Activity "Tagging Devices" -Status "Processing $($device.DeviceDisplayName)" -PercentComplete $percentComplete

    $deviceId = $device.DeviceObjectID

    try {
        # Get current physical IDs
        $deviceObj = Get-MgDevice -DeviceId $deviceId
        $currentPhysicalIds = $deviceObj.PhysicalIds

        # Ensure no duplicates
        $newPhysicalIds = $currentPhysicalIds | Where-Object { $_ -ne $newTag }
        $newPhysicalIds += $newTag

        # Update device
        Update-MgDevice -DeviceId $deviceId -PhysicalIds $newPhysicalIds

        Write-Host "[+] Tagged device: $($device.DeviceDisplayName)"
    }
    catch {
        Write-Warning "[!] Failed to tag device: $($device.DeviceDisplayName) ($deviceId)"
    }
}

Write-Host "[+] All devices processed."




######################################################
# REMOVE INTUNE TAG FOR LIST
######################################################

$inputCsv = "user_computer_object_ids - Copy.csv"

# Tag to remove
$tagToRemove = "[OrderID]:[OfficeSite]:US NewYork"

# Read CSV
$deviceList = Import-Csv -Path $inputCsv
$totalDevices = $deviceList.Count
$counter = 0

foreach ($device in $deviceList) {
    $counter++
    $percentComplete = ($counter / $totalDevices) * 100
    Write-Progress -Activity "Removing Tags" -Status "Processing $($device.DeviceDisplayName)" -PercentComplete $percentComplete

    $deviceId = $device.DeviceObjectID

    try {
        # Get current physical IDs
        $deviceObj = Get-MgDevice -DeviceId $deviceId
        $currentPhysicalIds = $deviceObj.PhysicalIds

        # Remove the tag if present
        $newPhysicalIds = $currentPhysicalIds | Where-Object { $_ -ne $tagToRemove }

        # Update device only if tag was present
        if ($newPhysicalIds.Count -ne $currentPhysicalIds.Count) {
            Update-MgDevice -DeviceId $deviceId -PhysicalIds $newPhysicalIds
            Write-Host "[+] Removed tag from: $($device.DeviceDisplayName)"
        } else {
            Write-Host "[!] Tag not found on: $($device.DeviceDisplayName)"
        }
    }
    catch {
        Write-Warning "[!] Failed to update device: $($device.DeviceDisplayName) ($deviceId)"
    }
}

Write-Host "[+] All devices processed."
