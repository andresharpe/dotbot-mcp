#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for solution_standards_list tool
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

Write-Host "Test: List All Standards" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 1
    method = 'tools/call'
    params = @{
        name = 'solution_standards_list'
        arguments = @{
            domain = 'all'
            include_summaries = $true
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Standards found: $($result.summary.total)" -ForegroundColor Green
if ($result.summary.by_domain) {
    $domainKeys = $result.summary.by_domain.PSObject.Properties.Name
    Write-Host "  - Domains: $($domainKeys -join ', ')" -ForegroundColor Cyan
}

Write-Host "`nTest: List Backend Standards" -ForegroundColor Yellow
$response = Send-McpRequest -Process $Process -Request @{
    jsonrpc = '2.0'
    id = 2
    method = 'tools/call'
    params = @{
        name = 'solution_standards_list'
        arguments = @{
            domain = 'backend'
            include_summaries = $true
        }
    }
}
$result = $response.result.content[0].text | ConvertFrom-Json
Write-Host "✓ Backend standards: $($result.standards.Count)" -ForegroundColor Green
