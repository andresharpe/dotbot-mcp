# Test All Envelopes
# Integration tests for envelope response standard across all solution.* tools

# Import solution helpers
$helpersPath = Join-Path $PSScriptRoot '..\solution-helpers.psm1'
Import-Module $helpersPath -Force -DisableNameChecking

Write-Host "`n=== Envelope Response Integration Tests ===`n" -ForegroundColor Cyan

$testResults = @{
    passed = 0
    failed = 0
    errors = @()
}

function Test-EnvelopeStructure {
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,
        [Parameter(Mandatory)]
        [hashtable]$Response
    )
    
    $issues = @()
    
    # Test required fields
    $required = @('schema_id', 'tool', 'version', 'status', 'summary', 'data', 'warnings', 'errors', 'audit')
    foreach ($field in $required) {
        if (-not $Response.ContainsKey($field)) {
            $issues += "Missing required field: $field"
        }
    }
    
    # Test schema_id
    if ($Response.schema_id -ne 'dotbot-mcp-response@1') {
        $issues += "Invalid schema_id: expected 'dotbot-mcp-response@1', got '$($Response.schema_id)'"
    }
    
    # Test tool name
    if ($Response.tool -ne $ToolName) {
        $issues += "Tool name mismatch: expected '$ToolName', got '$($Response.tool)'"
    }
    
    # Test status enum
    if ($Response.status -notin @('ok', 'warning', 'error')) {
        $issues += "Invalid status: expected 'ok|warning|error', got '$($Response.status)'"
    }
    
    # Test summary is non-empty string
    if ([string]::IsNullOrWhiteSpace($Response.summary)) {
        $issues += "Summary is empty or null"
    }
    
    # Test data is hashtable
    if ($Response.data -isnot [hashtable]) {
        $issues += "Data must be a hashtable"
    }
    
    # Test arrays
    if ($Response.warnings -isnot [array]) {
        $issues += "Warnings must be an array"
    }
    if ($Response.errors -isnot [array]) {
        $issues += "Errors must be an array"
    }
    
    # Test audit metadata
    $auditRequired = @('timestamp', 'duration_ms', 'source')
    foreach ($field in $auditRequired) {
        if (-not $Response.audit.ContainsKey($field)) {
            $issues += "Missing required audit field: $field"
        }
    }
    
    # Test timestamp format (ISO 8601)
    if ($Response.audit.timestamp -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') {
        $issues += "Invalid timestamp format: $($Response.audit.timestamp)"
    }
    
    # Test duration_ms is positive number
    if ($Response.audit.duration_ms -lt 0) {
        $issues += "Duration must be positive: $($Response.audit.duration_ms)"
    }
    
    # Test status computation logic
    if ($Response.errors.Count -gt 0 -and $Response.status -ne 'error') {
        $issues += "Status should be 'error' when errors exist"
    }
    if ($Response.errors.Count -eq 0 -and $Response.warnings.Count -gt 0 -and $Response.status -ne 'warning') {
        $issues += "Status should be 'warning' when warnings exist but no errors"
    }
    if ($Response.errors.Count -eq 0 -and $Response.warnings.Count -eq 0 -and $Response.status -ne 'ok') {
        $issues += "Status should be 'ok' when no errors or warnings"
    }
    
    return $issues
}

function Invoke-ToolTest {
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,
        [Parameter(Mandatory)]
        [string]$FunctionName,
        [hashtable]$Arguments = @{},
        [string]$Description
    )
    
    Write-Host "Testing $ToolName..." -NoNewline
    
    try {
        # Load tool script
        $toolPath = Join-Path $PSScriptRoot "$ToolName\script.ps1"
        if (-not (Test-Path $toolPath)) {
            Write-Host " SKIP (not found)" -ForegroundColor Yellow
            return
        }
        
        . $toolPath
        
        # Invoke tool
        $response = & $FunctionName -Arguments $Arguments
        
        if (-not $response) {
            Write-Host " FAIL (no response)" -ForegroundColor Red
            $script:testResults.failed++
            $script:testResults.errors += "$ToolName ($Description): No response returned"
            return
        }
        
        # Validate envelope structure
        $issues = Test-EnvelopeStructure -ToolName $ToolName -Response $response
        
        if ($issues.Count -gt 0) {
            Write-Host " FAIL" -ForegroundColor Red
            $script:testResults.failed++
            foreach ($issue in $issues) {
                Write-Host "  ✗ $issue" -ForegroundColor Red
                $script:testResults.errors += "$ToolName ($Description): $issue"
            }
        }
        else {
            Write-Host " PASS" -ForegroundColor Green
            $script:testResults.passed++
            Write-Host "  ✓ Schema valid, status=$($response.status), duration=$($response.audit.duration_ms)ms" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host " ERROR" -ForegroundColor Red
        $script:testResults.failed++
        $script:testResults.errors += "$ToolName ($Description): $($_.Exception.Message)"
        Write-Host "  Exception: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}

# Test 1: solution.info
Write-Host "`n[1/7] solution.info" -ForegroundColor Cyan
Invoke-ToolTest `
    -ToolName "solution-info" `
    -FunctionName "Invoke-SolutionInfo" `
    -Arguments @{ include_mission = $true; include_roadmap = $false } `
    -Description "Basic info with mission"

Invoke-ToolTest `
    -ToolName "solution-info" `
    -FunctionName "Invoke-SolutionInfo" `
    -Arguments @{ include_mission = $true; include_roadmap = $true } `
    -Description "Full info with mission and roadmap"

# Test 2: solution.structure
Write-Host "`n[2/7] solution.structure" -ForegroundColor Cyan
Invoke-ToolTest `
    -ToolName "solution-structure" `
    -FunctionName "Invoke-SolutionStructure" `
    -Arguments @{ include_dependencies = $false; include_file_counts = $false } `
    -Description "Basic structure"

Invoke-ToolTest `
    -ToolName "solution-structure" `
    -FunctionName "Invoke-SolutionStructure" `
    -Arguments @{ include_dependencies = $true; include_file_counts = $true } `
    -Description "Full structure with dependencies"

# Test 3: solution.tech_stack
Write-Host "`n[3/7] solution.tech_stack" -ForegroundColor Cyan
Invoke-ToolTest `
    -ToolName "solution-tech-stack" `
    -FunctionName "Invoke-SolutionTechStack" `
    -Arguments @{ category = 'all' } `
    -Description "All categories"

# Test 4: solution.standards.list
Write-Host "`n[4/7] solution.standards.list" -ForegroundColor Cyan
Invoke-ToolTest `
    -ToolName "solution-standards-list" `
    -FunctionName "Invoke-SolutionStandardsList" `
    -Arguments @{ domain = 'all'; include_summaries = $true } `
    -Description "All standards with summaries"

Invoke-ToolTest `
    -ToolName "solution-standards-list" `
    -FunctionName "Invoke-SolutionStandardsList" `
    -Arguments @{ domain = 'backend' } `
    -Description "Backend standards only"

# Test 5: solution.health.check
Write-Host "`n[5/7] solution.health.check" -ForegroundColor Cyan
Invoke-ToolTest `
    -ToolName "solution-health-check" `
    -FunctionName "Invoke-SolutionHealthCheck" `
    -Arguments @{ check_level = 'basic' } `
    -Description "Basic health check"

Invoke-ToolTest `
    -ToolName "solution-health-check" `
    -FunctionName "Invoke-SolutionHealthCheck" `
    -Arguments @{ check_level = 'standard' } `
    -Description "Standard health check"

# Test 6 & 7: solution.project.* (only if in dotbot solution)
$solutionRoot = Find-SolutionRoot
if ($solutionRoot) {
    Write-Host "`n[6/7] solution.project.register" -ForegroundColor Cyan
    # Note: This is a write operation, so we just test error handling
    Invoke-ToolTest `
        -ToolName "solution-project-register" `
        -FunctionName "Invoke-SolutionProjectRegister" `
        -Arguments @{ project_name = 'NonExistentProject' } `
        -Description "Register non-existent project (expect error)"
    
    Write-Host "`n[7/7] solution.project.update" -ForegroundColor Cyan
    Invoke-ToolTest `
        -ToolName "solution-project-update" `
        -FunctionName "Invoke-SolutionProjectUpdate" `
        -Arguments @{ project_name = 'NonExistentProject' } `
        -Description "Update non-existent project (expect error)"
}
else {
    Write-Host "`n[6/7] solution.project.register - SKIP (not in dotbot solution)" -ForegroundColor Yellow
    Write-Host "[7/7] solution.project.update - SKIP (not in dotbot solution)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $($testResults.passed)" -ForegroundColor Green
Write-Host "Failed: $($testResults.failed)" -ForegroundColor $(if ($testResults.failed -gt 0) { 'Red' } else { 'Gray' })

if ($testResults.failed -gt 0) {
    Write-Host "`n=== Errors ===" -ForegroundColor Red
    foreach ($error in $testResults.errors) {
        Write-Host "  • $error" -ForegroundColor Red
    }
    exit 1
}
else {
    Write-Host "`n✓ All envelope tests passed!" -ForegroundColor Green
    exit 0
}
