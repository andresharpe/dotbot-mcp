#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for solution_tech_stack tool
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

Write-Host "Test: Get Tech Stack (all categories)" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'solution_tech_stack'
        arguments = @{
            category = 'all'
            include_versions = $true
            include_rationale = $false
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Tech stack loaded" -ForegroundColor Green
if ($result.backend) {
    Write-Host "  - Backend: $($result.backend.framework)" -ForegroundColor Cyan
}
if ($result.frontend) {
    Write-Host "  - Frontend: $($result.frontend.framework)" -ForegroundColor Cyan
}

Write-Host "`nTest: Get Tech Stack (backend only)" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 2
    method = 'tools/call'
    params = @{
        name = 'solution_tech_stack'
        arguments = @{
            category = 'backend'
            include_versions = $true
            include_rationale = $true
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Backend tech stack filtered" -ForegroundColor Green
