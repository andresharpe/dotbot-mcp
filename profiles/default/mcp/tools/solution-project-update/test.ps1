#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for solution_project_update tool
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

Write-Host "Test: Update Project Metadata" -ForegroundColor Yellow
Write-Host "Note: This test requires a registered project" -ForegroundColor Gray

# First ensure we have a registered project
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
    
    # Try to update (will fail if not registered, which is expected)
    $response = Send-McpRequest -Process $Process -Request @{
        jsonrpc = '2.0'
        id = 2
        method = 'tools/call'
        params = @{
            name = 'solution_project_update'
            arguments = @{
                project_name = $testProject
                summary = "Updated summary from test script"
            }
        }
    }
    
    if ($response.result) {
        $result = $response.result.content[0].text | ConvertFrom-Json
        if ($result.success) {
            Write-Host "✓ Project updated successfully" -ForegroundColor Green
            Write-Host "  - Updated fields: $($result.updated_fields -join ', ')" -ForegroundColor Cyan
        }
    } else {
        Write-Host "⚠ Update requires project to be registered first" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ No projects found to test with" -ForegroundColor Yellow
}
