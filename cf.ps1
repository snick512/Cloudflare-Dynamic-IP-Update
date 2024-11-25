param (
    [Parameter(Mandatory = $true)]
    [string]$ip,

    [Parameter(Mandatory = $true)]
    [string]$domain,

    [switch]$remove  # Optional switch to indicate record removal
)

# Validate the provided IP address format
if (-not ($ip -match '^(\d{1,3}\.){3}\d{1,3}$') -or $ip -split '\.' | ForEach-Object { $_ -gt 255 -or $_ -lt 0 }) {
    Write-Host "Invalid IP address format: $ip" -ForegroundColor Red
    exit 1
}

# Set your Cloudflare API token and Zone ID
$apiToken = ""
$zoneId = ""

$domainName = $domain  # Use the provided domain

# Get the existing DNS record for the subdomain
$response = Invoke-RestMethod -Method GET `
    -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?type=A&name=$domainName" `
    -Headers @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }

if ($response.success -ne $true) {
    Write-Host "Failed to fetch DNS record: $($response.errors[0].message)" -ForegroundColor Red
    exit 1
}

# Check if the record exists
if ($response.result.Count -eq 0) {
    if ($remove) {
        Write-Host "No A record found for $domainName to remove." -ForegroundColor Yellow
        exit 0
    }

    # Create a new A record
    $createPayload = @(
        @{
            type    = "A"
            name    = $domainName
            content = $ip
            ttl     = 1  # Auto TTL
            proxied = $false
        }
    ) | ConvertTo-Json -Depth 10

    $createResponse = Invoke-RestMethod -Method POST `
        -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records" `
        -Headers @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" } `
        -Body $createPayload

    if ($createResponse.success -eq $true) {
        Write-Host "Successfully created A record for $domainName with IP $ip." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Failed to create A record: $($createResponse.errors[0].message)" -ForegroundColor Red
        exit 1
    }
}

# If remove flag is set, delete the record
if ($remove) {
    $recordId = $response.result[0].id
    $deleteResponse = Invoke-RestMethod -Method DELETE `
        -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId" `
        -Headers @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }

    if ($deleteResponse.success -eq $true) {
        Write-Host "Successfully removed A record for $domainName." -ForegroundColor Green
    } else {
        Write-Host "Failed to remove A record: $($deleteResponse.errors[0].message)" -ForegroundColor Red
    }
    exit 0
}

# Extract the record ID and current IP
$recordId = $response.result[0].id
$currentIPAddress = $response.result[0].content

if ($currentIPAddress -eq $ip) {
    Write-Host "The A record for $domainName is already set to $ip." -ForegroundColor Yellow
    exit 0
}

# Update the existing A record
$updatePayload = @{
    type    = "A"
    name    = $domainName
    content = $ip
    ttl     = 1  # Auto TTL
    proxied = $response.result[0].proxied
} | ConvertTo-Json -Depth 10

$updateResponse = Invoke-RestMethod -Method PUT `
    -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId" `
    -Headers @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" } `
    -Body $updatePayload

if ($updateResponse.success -eq $true) {
    Write-Host "Successfully updated A record for $domainName to $ip." -ForegroundColor Green
} else {
    Write-Host "Failed to update A record: $($updateResponse.errors[0].message)" -ForegroundColor Red
    exit 1
}
