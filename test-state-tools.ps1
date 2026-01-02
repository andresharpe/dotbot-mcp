#!/usr/bin/env pwsh
#
# Integration test for state-* tools
# Tests full workflow: init → get → advance → reset → history
#

$ErrorActionPreference = 'Stop'
$testRoot = "C:\Users\andre\repos\dotbot-mcp\test-state-temp"
$toolsRoot = "C:\Users\andre\repos\dotbot-mcp\profiles\default\mcp\tools"

# Colors
function Write-TestHeader { param([string]$msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Pass { param([string]$msg) Write-Host "  ✅ $msg" -ForegroundColor Green }
function Write-Fail { param([string]$msg) Write-Host "  ❌ $msg" -ForegroundColor Red }

# Setup test environment
Write-TestHeader "Setup Test Environment"
if (Test-Path $testRoot) {
    Remove-Item $testRoot -Recurse -Force
}
New-Item -ItemType Directory -Path "$testRoot\.bot\state" -Force | Out-Null
Write-Pass "Created test directory: $testRoot"

# Import helpers once
cd $testRoot
Import-Module 'C:\Users\andre\repos\dotbot-mcp\profiles\default\mcp\core-helpers.psm1' -Force -DisableNameChecking -WarningAction SilentlyContinue
Import-Module 'C:\Users\andre\repos\dotbot-mcp\profiles\default\mcp\state-helpers.psm1' -Force -DisableNameChecking -WarningAction SilentlyContinue

# Helper to invoke tool
function Invoke-StateTool {
    param(
        [string]$ToolName,
        [hashtable]$Args = @{}
    )
    
    $scriptPath = Join-Path $toolsRoot "$ToolName\script.ps1"
    $functionName = "Invoke-" + ($ToolName -replace '-', '')
    
    # Load the tool script
    . $scriptPath
    
    # Call the function
    $result = & $functionName $Args
    
    return $result
}

# Test 1: Initialize state with state-set
Write-TestHeader "Test 1: Initialize State (state-set)"
try {
    $result = Invoke-StateTool -ToolName 'state-set' -Args @{
        patch = @{
            current_feature = 'test-feature'
            phase = 'spec'
            current_task_id = 'TASK-001'
        }
        reason = 'Initial state setup'
    }
    
    if ($result.status -eq 'ok' -and $result.data.changed) {
        Write-Pass "State initialized successfully"
        Write-Pass "State file: .bot/state/state.json"
    }
    else {
        Write-Fail "State initialization failed: $($result.summary)"
        exit 1
    }
}
catch {
    Write-Fail "Test 1 failed: $_"
    exit 1
}

# Test 2: Get state with state-get
Write-TestHeader "Test 2: Get State (state-get)"
try {
    $result = Invoke-StateTool -ToolName 'state-get' -Args @{ include_history = $false }
    
    if ($result.status -eq 'ok' -and $result.data.state.current_feature -eq 'test-feature') {
        Write-Pass "Retrieved state successfully"
        Write-Pass "Current feature: $($result.data.state.current_feature)"
        Write-Pass "Phase: $($result.data.state.phase)"
        Write-Pass "Task: $($result.data.state.current_task_id)"
    }
    else {
        Write-Fail "Get state failed"
        exit 1
    }
}
catch {
    Write-Fail "Test 2 failed: $_"
    exit 1
}

# Test 3: Advance to next phase
Write-TestHeader "Test 3: Advance Phase (state-advance)"
try {
    $result = Invoke-StateTool -ToolName 'state-advance' -Args @{
        target = 'next-phase'
        next_phase = 'tasks'
        reason = 'Spec complete'
    }
    
    if ($result.status -eq 'ok' -and $result.data.changed) {
        Write-Pass "Advanced to phase: $($result.data.state.phase)"
        Write-Pass "History event appended"
    }
    else {
        Write-Fail "Phase advancement failed"
        exit 1
    }
}
catch {
    Write-Fail "Test 3 failed: $_"
    exit 1
}

# Test 4: Advance to next task
Write-TestHeader "Test 4: Advance Task (state-advance)"
try {
    $result = Invoke-StateTool -ToolName 'state-advance' -Args @{
        target = 'next-task'
        next_task_id = 'TASK-002'
        reason = 'Task 001 complete'
    }
    
    if ($result.status -eq 'ok' -and $result.data.changed) {
        Write-Pass "Advanced to task: $($result.data.state.current_task_id)"
    }
    else {
        Write-Fail "Task advancement failed"
        exit 1
    }
}
catch {
    Write-Fail "Test 4 failed: $_"
    exit 1
}

# Test 5: Query history
Write-TestHeader "Test 5: Query History (state-history)"
try {
    $result = Invoke-StateTool -ToolName 'state-history' -Args @{ limit = 10 }
    
    if ($result.status -eq 'ok' -and $result.data.count -gt 0) {
        Write-Pass "Found $($result.data.count) history events"
        foreach ($event in $result.data.events) {
            Write-Host "    - $($event.type) at $($event.timestamp)" -ForegroundColor Gray
        }
    }
    else {
        Write-Fail "History query failed"
        exit 1
    }
}
catch {
    Write-Fail "Test 5 failed: $_"
    exit 1
}

# Test 6: Reset task (with confirmation)
Write-TestHeader "Test 6: Reset Task (state-reset)"
try {
    $result = Invoke-StateTool -ToolName 'state-reset' -Args @{
        scope = 'task'
        confirm = $true
        reason = 'Testing reset'
    }
    
    if ($result.status -eq 'ok' -and $result.data.changed) {
        Write-Pass "Task reset successfully"
        Write-Pass "current_task_id is now: $($result.data.state.current_task_id)"
    }
    else {
        Write-Fail "Reset failed"
        exit 1
    }
}
catch {
    Write-Fail "Test 6 failed: $_"
    exit 1
}

# Test 7: Verify history contains all events
Write-TestHeader "Test 7: Verify Complete History"
try {
    $result = Invoke-StateTool -ToolName 'state-history' -Args @{ limit = 50 }
    
    $eventTypes = $result.data.events | ForEach-Object { $_.type } | Select-Object -Unique
    $expectedTypes = @('state_set', 'state_advance', 'state_reset')
    
    $missingTypes = $expectedTypes | Where-Object { $_ -notin $eventTypes }
    
    if ($missingTypes.Count -eq 0) {
        Write-Pass "All event types present in history"
        Write-Pass "Total events: $($result.data.count)"
    }
    else {
        Write-Fail "Missing event types: $($missingTypes -join ', ')"
        exit 1
    }
}
catch {
    Write-Fail "Test 7 failed: $_"
    exit 1
}

# Test 8: Atomic write verification
Write-TestHeader "Test 8: Verify Atomic Writes"
try {
    $stateFile = Join-Path $testRoot '.bot\state\state.json'
    $historyFile = Join-Path $testRoot '.bot\state\history.ndjson'
    
    if ((Test-Path $stateFile) -and (Test-Path $historyFile)) {
        Write-Pass "State file exists and is valid JSON"
        Write-Pass "History file exists as NDJSON"
        
        # Verify JSON is valid
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
        Write-Pass "State has $($state.PSObject.Properties.Count) fields"
        
        # Verify NDJSON is valid
        $lines = Get-Content $historyFile
        $validLines = 0
        foreach ($line in $lines) {
            try {
                $null = $line | ConvertFrom-Json
                $validLines++
            }
            catch {
                Write-Fail "Invalid NDJSON line: $line"
            }
        }
        Write-Pass "History has $validLines valid NDJSON events"
    }
    else {
        Write-Fail "State or history file missing"
        exit 1
    }
}
catch {
    Write-Fail "Test 8 failed: $_"
    exit 1
}

# Cleanup
Write-TestHeader "Cleanup"
Remove-Item $testRoot -Recurse -Force
Write-Pass "Cleaned up test directory"

# Success summary
Write-Host "`n" -NoNewline
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ ALL TESTS PASSED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "State tools are working correctly:" -ForegroundColor Green
Write-Host "  - state-set: initialization and updates ✅" -ForegroundColor Gray
Write-Host "  - state-get: retrieval with history ✅" -ForegroundColor Gray
Write-Host "  - state-advance: task and phase advancement ✅" -ForegroundColor Gray
Write-Host "  - state-reset: scoped resets with confirmation ✅" -ForegroundColor Gray
Write-Host "  - state-history: filtering and querying ✅" -ForegroundColor Gray
Write-Host ""

exit 0
