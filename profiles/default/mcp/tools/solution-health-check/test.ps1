#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for solution_health_check tool
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
    
    Start-Sleep -Milliseconds 200
    
    $response = $Process.StandardOutput.ReadLine()
    
    if ($response) {
        return $response | ConvertFrom-Json
    }
    
    return $null
}

Write-Host "Test: Health Check (basic)" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'solution_health_check'
        arguments = @{
            check_level = 'basic'
            include_recommendations = $false
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Status: $($result.status)" -ForegroundColor Green
Write-Host "✓ Check categories: $($result.checks.Count)" -ForegroundColor Green

Write-Host "`nTest: Health Check (standard)" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 2
    method = 'tools/call'
    params = @{
        name = 'solution_health_check'
        arguments = @{
            check_level = 'standard'
            include_recommendations = $true
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Status: $($result.status)" -ForegroundColor Green
if ($result.issues) {
    Write-Host "  - Issues found: $($result.issues.Count)" -ForegroundColor Yellow
}

Write-Host "`nTest: Health Check (comprehensive)" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 3
    method = 'tools/call'
    params = @{
        name = 'solution_health_check'
        arguments = @{
            check_level = 'comprehensive'
            include_recommendations = $true
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Comprehensive check completed" -ForegroundColor Green
Write-Host "  - Total checks: $($result.checks.Count)" -ForegroundColor Cyan

# Display orphan detection if present
$orphanCategory = $result.checks | Where-Object { $_.category -eq 'orphan-files' }
if ($orphanCategory) {
    Write-Host "  - Orphan detection: $($orphanCategory.status)" -ForegroundColor Cyan
}

# Display file reference integrity
$refCategory = $result.checks | Where-Object { $_.category -eq 'file-reference-integrity' }
if ($refCategory) {
    Write-Host "  - File references: $($refCategory.status)" -ForegroundColor Cyan
}
