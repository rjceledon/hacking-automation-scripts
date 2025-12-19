#rjceledon 10/31/25

# Define input and output CSV paths
$InputCsv = "C:\Temp\Company Team_2025-10-31.csv"
$OutputCsv = "C:\Temp\Company Team_2025-10-31EmployeeID.csv"

# Import the original CSV
$Users = Import-Csv -Path $InputCsv

# Connect to Microsoft Graph (requires MSGraph module and proper permissions)
Connect-MgGraph -Scopes "User.Read.All"

# Initialize counter for progress
$Total = $Users.Count
$Counter = 0

# Loop through each user and fetch employeeId
$UpdatedUsers = foreach ($User in $Users) {
    $Counter++
    $PercentComplete = ($Counter / $Total) * 100
    Write-Progress -Activity "Fetching employeeId from Microsoft Graph" `
                   -Status "Processing $Counter of $Total users" `
                   -PercentComplete $PercentComplete

    $Upn = $User.userPrincipalName
    $GraphUser = Get-MgUser -UserId $Upn -Property "employeeId" -ErrorAction SilentlyContinue

    # Add employeeId to the object
    $EmployeeId = $GraphUser.employeeId
    $User | Add-Member -NotePropertyName "employeeId" -NotePropertyValue $EmployeeId -Force

    # Output to console for tracking
    Write-Host "[+] Processed: $Upn | employeeId: $EmployeeId"

    $User
}

# Export updated data to new CSV
$UpdatedUsers | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "`n[+] CSV updated successfully with employeeId column: $OutputCsv"
