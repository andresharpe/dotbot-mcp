#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for parse_timestamp tool
#>

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

Write-Host "Test: Parse Unix timestamp" -ForegroundColor Yellow
$timestamp = [DateTimeOffset]::new(2026, 1, 1, 0, 0, 0, [TimeSpan]::Zero).ToUnixTimeSeconds()
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'parse_timestamp'
        arguments = @{
            timestamp = $timestamp
            format = 'yyyy-MM-dd HH:mm:ss'
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Parsed timestamp $timestamp : $($result.datetime)" -ForegroundColor Green
