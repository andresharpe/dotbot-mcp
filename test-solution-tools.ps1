#!/usr/bin/env pwsh
#
# Test all solution-* tools to ensure they produce clean JSON output with no warnings
#

param(
    [string]$SolutionRoot = "C:\Users\andre\repos\Axiome"
)

$ErrorActionPreference = 'Continue'
$toolsPath = "C:\Users\andre\repos\dotbot-mcp\profiles\default\mcp\tools"
$tools = @(
    "solution-info"
    "solution-health-check"
    "solution-structure"
    "solution-tech-stack"
    "solution-standards-list"
)

$results = @()

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Testing Solution-* Tools" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

foreach ($tool in $tools) {
    Write-Host "Testing: $tool" -ForegroundColor Yellow
    
    $scriptPath = Join-Path $toolsPath "$tool\script.ps1"
    $functionName = "Invoke-" + ($tool -replace '-', '')
    
    $command = @"
cd '$SolutionRoot'
Import-Module 'C:\Users\andre\repos\dotbot-mcp\profiles\default\mcp\core-helpers.psm1' -Force -DisableNameChecking -WarningAction SilentlyContinue
Import-Module 'C:\Users\andre\repos\dotbot-mcp\profiles\default\mcp\solution-helpers.psm1' -Force -DisableNameChecking -WarningAction SilentlyContinue
. '$scriptPath'
`$result = $functionName @{}
`$result | ConvertTo-Json -Depth 10 -Compress
"@
    
    $output = pwsh -NoProfile -Command $command 2>&1
    
    # Check for warnings/errors in stderr
    $hasWarnings = $false
    $hasErrors = $false
    $jsonOutput = $null
    
    foreach ($line in $output) {
        if ($line -is [System.Management.Automation.WarningRecord]) {
            $hasWarnings = $true
            Write-Host "  ❌ WARNING: $($line.Message)" -ForegroundColor Red
        }
        elseif ($line -is [System.Management.Automation.ErrorRecord]) {
            $hasErrors = $true
            Write-Host "  ❌ ERROR: $($line.Exception.Message)" -ForegroundColor Red
        }
        elseif ($line -match '^WARNING:') {
            $hasWarnings = $true
            Write-Host "  ❌ $line" -ForegroundColor Red
        }
        elseif ($line -match '^\{') {
            $jsonOutput = $line
        }
    }
    
    # Try to parse JSON
    $jsonValid = $false
    if ($jsonOutput) {
        try {
            $parsed = $jsonOutput | ConvertFrom-Json
            $jsonValid = $true
            
            # Check envelope structure
            if ($parsed.status -and $parsed.tool -and $parsed.data) {
                Write-Host "  ✅ Valid envelope response" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠️  Missing envelope fields" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  ❌ Invalid JSON: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    $result = @{
        tool = $tool
        hasWarnings = $hasWarnings
        hasErrors = $hasErrors
        jsonValid = $jsonValid
        passed = -not $hasWarnings -and -not $hasErrors -and $jsonValid
    }
    
    $results += $result
    
    if ($result.passed) {
        Write-Host "  ✅ PASSED" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ FAILED" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$passed = ($results | Where-Object { $_.passed }).Count
$total = $results.Count

Write-Host "Passed: $passed/$total" -ForegroundColor $(if ($passed -eq $total) { 'Green' } else { 'Yellow' })

foreach ($result in $results) {
    $status = if ($result.passed) { "✅" } else { "❌" }
    Write-Host "  $status $($result.tool)" -ForegroundColor $(if ($result.passed) { 'Green' } else { 'Red' })
}

Write-Host ""

if ($passed -eq $total) {
    Write-Host "✅ All tests passed! MCP compliance verified." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "❌ Some tests failed. Review output above." -ForegroundColor Red
    exit 1
}
