# Rich Celedon
# 05/14/2026

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$InputFile  = ".\ticket_numbers.txt"
$OutputFile = ".\ticket_ids.csv"

$ApiIntegrationCode = '<SNIP>'
$UserName           = '<SNIP>'
$Secret             = '<SNIP>'

$Uri = "https://webservices1.autotask.net/ATServicesRest/V1.0/Tickets/query"

$Headers = @{
    "ApiIntegrationCode" = $ApiIntegrationCode
    "UserName"           = $UserName
    "Secret"             = $Secret
    "Accept"             = "application/json"
}

if (-not (Test-Path $InputFile)) {
    throw "Input file not found: $InputFile"
}

$TicketNumbers = Get-Content $InputFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$TotalTickets = $TicketNumbers.Count

if ($TotalTickets -eq 0) {
    throw "No ticket numbers found in input file: $InputFile"
}

$CsvLines = New-Object System.Collections.Generic.List[string]
$CsvLines.Add("TicketNumber,TicketId")

$CurrentIndex = 0

foreach ($ticketNumber in $TicketNumbers) {
    $CurrentIndex++

    $PercentComplete = [math]::Round(($CurrentIndex / $TotalTickets) * 100, 0)

    Write-Progress `
        -Activity "Querying Autotask tickets" `
        -Status "Processing $CurrentIndex of ${TotalTickets}: $ticketNumber" `
        -PercentComplete $PercentComplete

    $BodyObject = @{
        MaxRecords    = 1
        IncludeFields = @("id")
        Filter        = @(
            @{
                op    = "eq"
                field = "ticketNumber"
                value = $ticketNumber
                udf   = $false
                items = @()
            }
        )
    }

    $BodyJson = $BodyObject | ConvertTo-Json -Depth 10

    try {
        $Response = Invoke-RestMethod `
            -Uri $Uri `
            -Method Post `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $BodyJson `
            -ErrorAction Stop

        $TicketId = ""

        if ($null -ne $Response.items -and @($Response.items).Count -gt 0) {
            $TicketId = @($Response.items)[0].id
            Write-Host "TicketID found: $TicketId"
        }

        $CsvLines.Add("$ticketNumber,$TicketId")
    }
    catch {
        $CsvLines.Add("$ticketNumber,")
    }
}

Write-Progress `
    -Activity "Querying Autotask tickets" `
    -Completed

$CsvLines | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host "Done. Results exported to $OutputFile"
