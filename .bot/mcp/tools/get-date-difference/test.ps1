#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for get_date_difference tool
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

Write-Host "Test: Calculate difference between 2026-01-01 and 2026-12-31" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'get_date_difference'
        arguments = @{
            start_date = '2026-01-01'
            end_date = '2026-12-31'
            unit = 'days'
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Difference: $($result.difference) days" -ForegroundColor Green
