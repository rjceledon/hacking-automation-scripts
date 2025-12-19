#rjceledon 12/19/25
$total = $users.Count
$counter = 0

# Prepare results
$results = @()

foreach ($user in $users) {
    $counter++
    $percentComplete = ($counter / $total) * 100
    Write-Progress -Activity "Querying Intune Devices" -Status "Processing $($user.UserPrincipalName)" -PercentComplete $percentComplete

    $upn = $user.UserPrincipalName
    Write-Host "`n[?] Looking up user: $upn"

    # Get user object
    $userObj = Get-MgUser -UserId $upn -ErrorAction SilentlyContinue

    if ($userObj) {
        # Get devices assigned to the user
        $devices = Get-MgUserManagedDevice -UserId $userObj.Id -ErrorAction SilentlyContinue

        # Filter only devices starting with "KA-" and exclude phones
        $filteredDevices = $devices | Where-Object {
            $_.DeviceName -like "COMPANY-*" -and $_.OperatingSystem -eq "Windows"
        }

        if ($filteredDevices.Count -eq 0) {
            Write-Host "[!] No matching devices found for $upn"
        }

        foreach ($device in $filteredDevices) {
            Write-Host "[+] Found device: $($device.DeviceName)"

            $results += [PSCustomObject]@{
                UserPrincipalName = $upn
                DeviceName        = $device.DeviceName
                OperatingSystem   = $device.OperatingSystem
                ComplianceState   = $device.ComplianceState
                LastSyncDateTime  = $device.LastSyncDateTime
            }
        }
    } else {
        Write-Host "[!] User not found: $upn"

        $results += [PSCustomObject]@{
            UserPrincipalName = $upn
            DeviceName        = "User Not Found"
            OperatingSystem   = ""
            ComplianceState   = ""
            LastSyncDateTime  = ""
        }
    }
}

# Export to CSV
$outputPath = "C:\\Temp\\intune_devices_output.csv"
$results | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "`n[+] Script completed. Output saved to: $outputPath"
