# Rich Celedon
# 05/14/2026

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$InputCsv   = ".\ticket_ids.csv"
$ResultsCsv = ".\time_entry_patch_results.csv"

$ApiIntegrationCode = '<SNIP>'
$UserName           = '<SNIP>'
$Secret             = '<SNIP>'

$BaseUrl        = "https://webservices1.autotask.net/ATServicesRest/V1.0"
$TimeEntriesUri = "$BaseUrl/TimeEntries"
$TicketsUri     = "$BaseUrl/Tickets"

$Headers = @{
    "ApiIntegrationCode" = $ApiIntegrationCode
    "UserName"           = $UserName
    "Secret"             = $Secret
    "accept"             = "application/json"
}

function Get-HttpErrorMessage {
    param (
        $ErrorRecord
    )

    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        return ($ErrorRecord.ErrorDetails.Message -replace "`r", " " -replace "`n", " ")
    }

    if ($ErrorRecord.Exception.Response) {
        try {
            $Stream = $ErrorRecord.Exception.Response.GetResponseStream()
            $Reader = New-Object System.IO.StreamReader($Stream)
            $Body = $Reader.ReadToEnd()
            $Reader.Close()

            if (-not [string]::IsNullOrWhiteSpace($Body)) {
                return ($Body -replace "`r", " " -replace "`n", " ")
            }
        }
        catch {
            return $ErrorRecord.Exception.Message
        }
    }

    return $ErrorRecord.Exception.Message
}

if (-not (Test-Path $InputCsv)) {
    throw "Input CSV not found: $InputCsv"
}

$Rows = @(Import-Csv $InputCsv | Where-Object {
    $null -ne $_.TicketId -and -not [string]::IsNullOrWhiteSpace($_.TicketId)
})

$TotalTickets = $Rows.Count

if ($TotalTickets -eq 0) {
    throw "No TicketId values found in CSV: $InputCsv"
}

$ResultLines = New-Object System.Collections.Generic.List[string]
$ResultLines.Add("TicketId,TimeEntryStatus,TimeEntryId,PatchStatus,Error")

$CurrentIndex = 0

foreach ($row in $Rows) {
    $CurrentIndex++

    $RawTicketId = $row.TicketId.Trim()

    try {
        $TicketId = [int64]$RawTicketId
    }
    catch {
        Write-Warning "Skipping invalid TicketId: $RawTicketId"
        $ResultLines.Add("$RawTicketId,Skipped,,Skipped,Invalid TicketId")
        continue
    }

    $PercentComplete = [math]::Round(($CurrentIndex / $TotalTickets) * 100, 0)

    Write-Progress `
        -Activity "Creating time entries and patching tickets" `
        -Status "Processing $CurrentIndex of ${TotalTickets}: TicketId $TicketId" `
        -PercentComplete $PercentComplete

    $TimeEntryBody = @{
        billingApprovalDateTime            = $null
        billingApprovalLevelMostRecent     = 0
        billingApprovalResourceID          = $null
        billingCodeID                      = 29682801
        contractID                         = $null
        contractServiceBundleID            = $null
        contractServiceID                  = $null
        createDateTime                     = "2026-05-14T16:34:54.060Z"
        creatorUserID                      = 29683676
        dateWorked                         = "2026-05-14T00:00:00.000Z"
        endDateTime                        = "2026-05-14T16:04:00.000Z"
        hoursToBill                        = 0.5
        hoursWorked                        = 0.5
        impersonatorCreatorResourceID      = $null
        impersonatorUpdaterResourceID      = $null
        internalBillingCodeID              = 29682801
        isInternalNotesVisibleToComanaged  = $false
        isNonBillable                      = $true
        lastModifiedDateTime               = "2026-05-14T16:34:54.060Z"
        lastModifiedUserID                 = 29683676
        offsetHours                        = 0
        resourceID                         = 29683676
        roleID                             = 29683355
        showOnInvoice                      = $false
        startDateTime                      = "2026-05-14T15:34:00.000Z"
        summaryNotes                       = "Cancelling ticket: User doesn't exist in Entra, this is a duplicated ticket created by error in the integration."
        taskID                             = $null
        ticketID                           = $TicketId
        timeEntryType                      = 2
    }

    $TimeEntryJson = $TimeEntryBody | ConvertTo-Json -Depth 10

    $TimeEntryId = ""

    try {
        $TimeEntryResponse = Invoke-RestMethod `
            -Uri $TimeEntriesUri `
            -Method Post `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $TimeEntryJson `
            -ErrorAction Stop

        if ($null -ne $TimeEntryResponse.itemId) {
            $TimeEntryId = $TimeEntryResponse.itemId
        }
        elseif ($null -ne $TimeEntryResponse.id) {
            $TimeEntryId = $TimeEntryResponse.id
        }
        elseif ($null -ne $TimeEntryResponse.items -and @($TimeEntryResponse.items).Count -gt 0) {
            $TimeEntryId = @($TimeEntryResponse.items)[0].id
        }

        Write-Host "TimeEntry created. TicketId: $TicketId TimeEntryId: $TimeEntryId"
    }
    catch {
        $ErrorMessage = Get-HttpErrorMessage $_
        $SafeError = $ErrorMessage -replace ",", ";" -replace "`r", " " -replace "`n", " "

        Write-Warning "TimeEntry failed. TicketId: $TicketId Error: $ErrorMessage"

        $ResultLines.Add("$TicketId,Failed,,Skipped,$SafeError")
        continue
    }

    $PatchBody = @{
        id     = $TicketId
        status = 33
    }

    $PatchJson = $PatchBody | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod `
            -Uri $TicketsUri `
            -Method Patch `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $PatchJson `
            -ErrorAction Stop | Out-Null

        Write-Host "Ticket patched. TicketId: $TicketId Status: 33"

        $ResultLines.Add("$TicketId,Success,$TimeEntryId,Success,")
    }
    catch {
        $ErrorMessage = Get-HttpErrorMessage $_
        $SafeError = $ErrorMessage -replace ",", ";" -replace "`r", " " -replace "`n", " "

        Write-Warning "Patch failed. TicketId: $TicketId Error: $ErrorMessage"

        $ResultLines.Add("$TicketId,Success,$TimeEntryId,Failed,$SafeError")
    }
}

Write-Progress `
    -Activity "Creating time entries and patching tickets" `
    -Completed

$ResultLines | Set-Content -Path $ResultsCsv -Encoding UTF8

Write-Host "Done. Results exported to $ResultsCsv"
