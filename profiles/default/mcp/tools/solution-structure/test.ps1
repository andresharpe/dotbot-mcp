#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for solution_structure tool
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

Write-Host "Test: Get Solution Structure (basic)" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'solution_structure'
        arguments = @{
            include_dependencies = $false
            include_file_counts = $false
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Solution root: $($result.solution_root)" -ForegroundColor Green
Write-Host "✓ Projects found: $($result.projects.Count)" -ForegroundColor Green

# Verify auto-discovery worked
if ($result.projects.Count -gt 0) {
    Write-Host "✓ Auto-discovery successful" -ForegroundColor Green
    $firstProject = $result.projects[0]
    Write-Host "  - Sample project: $($firstProject.name) (alias: $($firstProject.alias), type: $($firstProject.type))" -ForegroundColor Cyan
}

Write-Host "`nTest: Get Solution Structure (with dependencies)" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 2
    method = 'tools/call'
    params = @{
        name = 'solution_structure'
        arguments = @{
            include_dependencies = $true
            include_file_counts = $false
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
if ($result.projects[0].dependency_count -ge 0) {
    Write-Host "✓ Dependency counts included" -ForegroundColor Green
}
