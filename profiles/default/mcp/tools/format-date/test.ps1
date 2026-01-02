#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for format_date tool
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

Write-Host "Test: Format date from ISO to US format" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'format_date'
        arguments = @{
            date = '2026-01-15'
            output_format = 'MM/dd/yyyy'
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Formatted: $($result.formatted)" -ForegroundColor Green
