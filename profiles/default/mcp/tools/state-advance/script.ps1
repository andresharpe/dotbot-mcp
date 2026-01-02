function Invoke-StateAdvance {
    param(
        [hashtable]$Arguments
    )
    
    # Import helpers
    $coreHelpersPath = Join-Path $PSScriptRoot '..\..\core-helpers.psm1'
    $stateHelpersPath = Join-Path $PSScriptRoot '..\..\state-helpers.psm1'
    Import-Module $coreHelpersPath -Force -DisableNameChecking -WarningAction SilentlyContinue
    Import-Module $stateHelpersPath -Force -DisableNameChecking -WarningAction SilentlyContinue
    
    $timer = Start-ToolTimer
    
    try {
        # Find solution root
        $solutionRoot = Find-SolutionRoot
        if (-not $solutionRoot) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-advance" `
                -Version "1.0.0" `
                -Summary "Failed: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/state-advance/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Check if state initialized
        if (-not (Test-StateInitialized -SolutionRoot $solutionRoot)) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-advance" `
                -Version "1.0.0" `
                -Summary "State not initialized. Use state-set first." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "STATE_NOT_INITIALIZED" -Message "State file does not exist. Initialize with state-set first.")) `
                -Source ".bot/mcp/tools/state-advance/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Validate target parameter
        $target = $Arguments['target']
        if (-not $target) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-advance" `
                -Version "1.0.0" `
                -Summary "Missing required parameter: target" `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "INVALID_PARAMETER" -Message "target parameter is required (next-task or next-phase)")) `
                -Source ".bot/mcp/tools/state-advance/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Read current state
        $state = Get-State -SolutionRoot $solutionRoot
        $patch = @{}
        $advanceType = $null
        
        # Handle advancement based on target
        switch ($target) {
            'next-task' {
                $nextTaskId = $Arguments['next_task_id']
                if (-not $nextTaskId) {
                    $duration = Get-ToolDuration -Stopwatch $timer
                    return New-EnvelopeResponse `
                        -Tool "state-advance" `
                        -Version "1.0.0" `
                        -Summary "Missing next_task_id for task advancement" `
                        -Data @{} `
                        -Errors @((New-ErrorObject -Code "INVALID_PARAMETER" -Message "next_task_id is required when target=next-task")) `
                        -Source ".bot/mcp/tools/state-advance/script.ps1" `
                        -DurationMs $duration `
                        -Host (Get-McpHost)
                }
                
                # Validate task ID format
                if ($nextTaskId -notmatch '^[A-Z0-9-]+$') {
                    $duration = Get-ToolDuration -Stopwatch $timer
                    return New-EnvelopeResponse `
                        -Tool "state-advance" `
                        -Version "1.0.0" `
                        -Summary "Invalid task_id format: $nextTaskId" `
                        -Data @{} `
                        -Errors @((New-ErrorObject -Code "INVALID_TASK_ID" -Message "Task ID must match pattern: ^[A-Z0-9-]+`$ (got: $nextTaskId)")) `
                        -Source ".bot/mcp/tools/state-advance/script.ps1" `
                        -DurationMs $duration `
                        -Host (Get-McpHost)
                }
                
                $patch.current_task_id = $nextTaskId
                $advanceType = 'task'
            }
            
            'next-phase' {
                $nextPhase = $Arguments['next_phase']
                
                # If next_phase not provided, try to read from phase-order.json
                if (-not $nextPhase) {
                    $phaseOrderPath = Join-Path $solutionRoot '.bot\state\phase-order.json'
                    if (Test-Path $phaseOrderPath) {
                        try {
                            $phaseOrder = Get-Content $phaseOrderPath -Raw | ConvertFrom-Json
                            $currentPhase = $state.phase
                            $currentIndex = [array]::IndexOf($phaseOrder.phases, $currentPhase)
                            
                            if ($currentIndex -ge 0 -and $currentIndex -lt ($phaseOrder.phases.Count - 1)) {
                                $nextPhase = $phaseOrder.phases[$currentIndex + 1]
                            }
                            else {
                                $duration = Get-ToolDuration -Stopwatch $timer
                                return New-EnvelopeResponse `
                                    -Tool "state-advance" `
                                    -Version "1.0.0" `
                                    -Summary "Cannot determine next phase from phase-order.json" `
                                    -Data @{} `
                                    -Errors @((New-ErrorObject -Code "PHASE_ORDER_MISSING" -Message "Current phase '$currentPhase' is last in phase-order.json or not found")) `
                                    -Source ".bot/mcp/tools/state-advance/script.ps1" `
                                    -DurationMs $duration `
                                    -Host (Get-McpHost)
                            }
                        }
                        catch {
                            $duration = Get-ToolDuration -Stopwatch $timer
                            return New-EnvelopeResponse `
                                -Tool "state-advance" `
                                -Version "1.0.0" `
                                -Summary "Failed to parse phase-order.json: $_" `
                                -Data @{} `
                                -Errors @((New-ErrorObject -Code "PHASE_ORDER_MISSING" -Message "Invalid phase-order.json: $_")) `
                                -Source ".bot/mcp/tools/state-advance/script.ps1" `
                                -DurationMs $duration `
                                -Host (Get-McpHost)
                        }
                    }
                    else {
                        $duration = Get-ToolDuration -Stopwatch $timer
                        return New-EnvelopeResponse `
                            -Tool "state-advance" `
                            -Version "1.0.0" `
                            -Summary "next_phase required (phase-order.json not found)" `
                            -Data @{} `
                            -Errors @((New-ErrorObject -Code "PHASE_ORDER_MISSING" -Message "Either provide next_phase parameter or create .bot/state/phase-order.json")) `
                            -Source ".bot/mcp/tools/state-advance/script.ps1" `
                            -DurationMs $duration `
                            -Host (Get-McpHost)
                    }
                }
                
                # Validate phase
                $validPhases = @('spec', 'tasks', 'implement', 'verify', 'deploy')
                if ($nextPhase -notin $validPhases) {
                    $duration = Get-ToolDuration -Stopwatch $timer
                    return New-EnvelopeResponse `
                        -Tool "state-advance" `
                        -Version "1.0.0" `
                        -Summary "Invalid phase: $nextPhase" `
                        -Data @{} `
                        -Errors @((New-ErrorObject -Code "INVALID_PHASE" -Message "Phase must be one of: $($validPhases -join ', ')")) `
                        -Source ".bot/mcp/tools/state-advance/script.ps1" `
                        -DurationMs $duration `
                        -Host (Get-McpHost)
                }
                
                $patch.phase = $nextPhase
                
                # Update phase_index if it exists
                if ($state.PSObject.Properties['phase_index']) {
                    $currentIndex = $state.phase_index
                    if ($null -ne $currentIndex) {
                        $patch.phase_index = $currentIndex + 1
                    }
                }
                
                $advanceType = 'phase'
            }
            
            default {
                $duration = Get-ToolDuration -Stopwatch $timer
                return New-EnvelopeResponse `
                    -Tool "state-advance" `
                    -Version "1.0.0" `
                    -Summary "Invalid target: $target" `
                    -Data @{} `
                    -Errors @((New-ErrorObject -Code "INVALID_PARAMETER" -Message "target must be 'next-task' or 'next-phase'")) `
                    -Source ".bot/mcp/tools/state-advance/script.ps1" `
                    -DurationMs $duration `
                    -Host (Get-McpHost)
            }
        }
        
        # Compute diff
        $diff = Compute-StateDiff -OldState $state -NewFields $patch
        
        if ($diff.Count -eq 0) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-advance" `
                -Version "1.0.0" `
                -Summary "No changes (already at target state)" `
                -Data @{ changed = $false; state = $state } `
                -Source ".bot/mcp/tools/state-advance/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Apply patch
        foreach ($key in $patch.Keys) {
            $state.$key = $patch[$key]
        }
        $state.updated_at = Get-Date -Format 'o'
        
        # Write state atomically
        Write-StateAtomic -SolutionRoot $solutionRoot -State $state
        
        # Append to history
        $historyEvent = @{
            timestamp = $state.updated_at
            type = 'state_advance'
            advance_type = $advanceType
            diff = $diff
        }
        
        if ($Arguments['correlation_id']) {
            $historyEvent.correlation_id = $Arguments['correlation_id']
        }
        if ($Arguments['reason']) {
            $historyEvent.reason = $Arguments['reason']
        }
        
        Append-StateEvent -SolutionRoot $solutionRoot -Event $historyEvent
        
        # Build summary
        $changedFields = $diff.Keys -join ', '
        $summary = if ($advanceType -eq 'task') {
            "Advanced to task: $($patch.current_task_id)"
        }
        else {
            "Advanced to phase: $($patch.phase)"
        }
        
        # Build result
        $result = @{
            changed = $true
            advance_type = $advanceType
            state = $state
            diff = $diff
        }
        
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "state-advance" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $result `
            -Source ".bot/mcp/tools/state-advance/script.ps1" `
            -WriteTo ".bot/state/state.json, .bot/state/history.ndjson" `
            -DurationMs $duration `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module core-helpers -ErrorAction SilentlyContinue
        Remove-Module state-helpers -ErrorAction SilentlyContinue
    }
}
