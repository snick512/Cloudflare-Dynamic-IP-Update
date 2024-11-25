param (
    [Parameter(Mandatory = $true)]
    [string]$ip,

    [Parameter(Mandatory = $true)]
    [string]$domain
)

# Validate the provided IP address format
if (-not ($ip -match '^(\d{1,3}\.){3}\d{1,3}$') -or $ip -split '\.' | ForEach-Object { $_ -gt 255 -or $_ -lt 0 }) {
    Write-Host "Invalid IP address format: $ip" -ForegroundColor Red
    exit 1
}

# Set your Cloudflare API token and Zone ID
$apiToken = ""
$zoneId = ""

$newIPAddress = $ip  # Use the provided IP address
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
    Write-Host "No A record found for $domainName" -ForegroundColor Red
    exit 1
}

# Extract the record ID and current IP
$recordId = $response.result[0].id
$currentIPAddress = $response.result[0].content

if ($currentIPAddress -eq $newIPAddress) {
    Write-Host "The A record for $domainName is already set to $newIPAddress." -ForegroundColor Yellow
    exit 0
}

# Update the A record with the new IP address
$updatePayload = @{
    type    = "A"
    name    = $domainName
    content = $newIPAddress
    ttl     = 1  # Auto TTL
    proxied = $response.result[0].proxied
} | ConvertTo-Json -Depth 10

$updateResponse = Invoke-RestMethod -Method PUT `
    -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId" `
    -Headers @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" } `
    -Body $updatePayload

if ($updateResponse.success -eq $true) {
    Write-Host "Successfully updated A record for $domainName to $newIPAddress." -ForegroundColor Green
} else {
    Write-Host "Failed to update A record: $($updateResponse.errors[0].message)" -ForegroundColor Red
    exit 1
}
