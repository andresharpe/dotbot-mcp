#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for solution_info tool
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

Write-Host "Test: Get Solution Info (basic)" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'solution_info'
        arguments = @{
            include_mission = $true
            include_roadmap = $false
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Solution name: $($result.solution.name)" -ForegroundColor Green
Write-Host "✓ Dotbot version: $($result.solution.dotbot_version)" -ForegroundColor Green

if ($result.mission) {
    Write-Host "✓ Mission loaded successfully" -ForegroundColor Green
}
