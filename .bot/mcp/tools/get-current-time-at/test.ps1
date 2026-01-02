#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory)]
    [System.Diagnostics.Process]$Process
)

. "$PSScriptRoot\..\..\dotbot-mcp-helpers.ps1"

function Send-McpRequest {
    param(
        [Parameter(Mandatory)]
        [object]$Request,
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process
    )
    
    $json = $Request | ConvertTo-Json -Depth 10 -Compress
    $Process.StandardInput.WriteLine($json)
    $Process.StandardInput.Flush()
    Start-Sleep -Milliseconds 100
    $response = $Process.StandardOutput.ReadLine()
    
    if ($response) {
        return $response | ConvertFrom-Json
    }
    return $null
}

Write-Host "Test 1: Get current time in Tokyo using place name" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'get_current_time_at'
        arguments = @{
            location = 'Tokyo'
        }
    }
}

if ($response.result) {
    $result = $response.result.content[0].text | ConvertFrom-Json
    Write-Host "✓ Result: location=$($result.location), timezone=$($result.timezone), time=$($result.currentTime)" -ForegroundColor Green
    Write-Host "  Address: $($result.formattedAddress)" -ForegroundColor Cyan
    Write-Host "  Timezone: $($result.timezoneName) ($($result.timezoneOffset))" -ForegroundColor Cyan
} else {
    Write-Host "✗ Test failed: $($response.error.message)" -ForegroundColor Red
}

Write-Host "`nTest 2: Get current time at Big Ben (POI) with custom format" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 2
    method = 'tools/call'
    params = @{
        name = 'get_current_time_at'
        arguments = @{
            location = 'Big Ben'
            format = 'dddd, MMMM dd, yyyy hh:mm:ss tt'
        }
    }
}

if ($response.result) {
    $result = $response.result.content[0].text | ConvertFrom-Json
    Write-Host "✓ Result: location=$($result.location), time=$($result.currentTime)" -ForegroundColor Green
    Write-Host "  Timezone: $($result.timezone)" -ForegroundColor Cyan
    Write-Host "  Formatted: $($result.currentTime)" -ForegroundColor Cyan
} else {
    Write-Host "✗ Test failed: $($response.error.message)" -ForegroundColor Red
}

Write-Host "`nTest 3: Get current time using coordinates (Sydney Opera House)" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 3
    method = 'tools/call'
    params = @{
        name = 'get_current_time_at'
        arguments = @{
            latitude = -33.8568
            longitude = 151.2153
        }
    }
}

if ($response.result) {
    $result = $response.result.content[0].text | ConvertFrom-Json
    Write-Host "✓ Result: coordinates=($($result.coordinates.latitude),$($result.coordinates.longitude)), time=$($result.currentTime)" -ForegroundColor Green
    Write-Host "  Timezone: $($result.timezoneName) ($($result.timezoneOffset))" -ForegroundColor Cyan
} else {
    Write-Host "✗ Test failed: $($response.error.message)" -ForegroundColor Red
}

Write-Host "`nTest 4: Get current time in New York with short format" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 4
    method = 'tools/call'
    params = @{
        name = 'get_current_time_at'
        arguments = @{
            location = 'New York'
            format = 'yyyy-MM-dd HH:mm'
        }
    }
}

if ($response.result) {
    $result = $response.result.content[0].text | ConvertFrom-Json
    Write-Host "✓ Result: location=$($result.location), time=$($result.currentTime)" -ForegroundColor Green
    Write-Host "  UTC Time: $($result.utcTime)" -ForegroundColor Cyan
} else {
    Write-Host "✗ Test failed: $($response.error.message)" -ForegroundColor Red
}
