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

Write-Host "Test 1: Check holiday using place name - Mondeor" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'get_public_holidays'
        arguments = @{
            location = 'Mondeor'
        }
    }
}

if ($response.result) {
    $result = $response.result.content[0].text | ConvertFrom-Json
    Write-Host "✓ Result: isHoliday=$($result.isHoliday), country=$($result.country), coordinates=($($result.coordinates.latitude),$($result.coordinates.longitude))" -ForegroundColor Green
} else {
    Write-Host "✗ Test failed: $($response.error.message)" -ForegroundColor Red
}

Write-Host "`nTest 2: Check holiday using coordinates - Zurich on New Year's Day 2026" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 2
    method = 'tools/call'
    params = @{
        name = 'get_public_holidays'
        arguments = @{
            latitude = 47.3769
            longitude = 8.5417
            date = '2026-01-01'
        }
    }
}

if ($response.result) {
    $result = $response.result.content[0].text | ConvertFrom-Json
    Write-Host "✓ Result: isHoliday=$($result.isHoliday), country=$($result.country), holidays=$($result.holidays.Count)" -ForegroundColor Green
    if ($result.isHoliday) {
        Write-Host "  Holiday: $($result.holidays[0].name)" -ForegroundColor Cyan
    }
} else {
    Write-Host "✗ Test failed: $($response.error.message)" -ForegroundColor Red
}

Write-Host "`nTest 3: Check holiday using place name - Paris on Bastille Day" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 3
    method = 'tools/call'
    params = @{
        name = 'get_public_holidays'
        arguments = @{
            location = 'Paris, France'
            date = '2026-07-14'
        }
    }
}

if ($response.result) {
    $result = $response.result.content[0].text | ConvertFrom-Json
    Write-Host "✓ Result: isHoliday=$($result.isHoliday), country=$($result.country), holiday=$($result.holidays.name)" -ForegroundColor Green
    if ($result.isHoliday) {
        Write-Host "  Holiday: $($result.holidays.name)" -ForegroundColor Cyan
    }
} else {
    Write-Host "✗ Test failed: $($response.error.message)" -ForegroundColor Red
}
