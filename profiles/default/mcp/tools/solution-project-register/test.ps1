#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for solution_project_register tool
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
    
    Start-Sleep -Milliseconds 150
    
    $response = $Process.StandardOutput.ReadLine()
    
    if ($response) {
        return $response | ConvertFrom-Json
    }
    
    return $null
}

Write-Host "Test: Register Project" -ForegroundColor Yellow
Write-Host "Note: This test requires a real project in the solution" -ForegroundColor Gray

# Get existing projects first to find a valid project name
$structureResponse = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'solution_structure'
        arguments = @{}
    }
}
$structure = $structureResponse.result.content[0].text | ConvertFrom-Json

if ($structure.projects.Count -gt 0) {
    $testProject = $structure.projects[0].name
    Write-Host "  - Using project: $testProject" -ForegroundColor Cyan
    
    # Register with custom metadata
    $response = Send-McpRequest -Process $Process -Request @{
        jsonrpc = '2.0'
        id = 2
        method = 'tools/call'
        params = @{
            name = 'solution_project_register'
            arguments = @{
                project_name = $testProject
                alias = "test-alias"
                summary = "Test project registered via test script"
                tags = @("test", "automated")
                owner = "test-team"
            }
        }
    }
    $result = $response.result.content[0].text | ConvertFrom-Json
    
    if ($result.success) {
        Write-Host "✓ Project registered successfully" -ForegroundColor Green
        Write-Host "  - Alias: $($result.registered_metadata.alias)" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Registration failed" -ForegroundColor Red
    }
} else {
    Write-Host "⚠ No projects found to test with" -ForegroundColor Yellow
}
