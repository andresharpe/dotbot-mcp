function Invoke-StateReset {
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
                -Tool "state-reset" `
                -Version "1.0.0" `
                -Summary "Failed: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/state-reset/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Check if state initialized
        if (-not (Test-StateInitialized -SolutionRoot $solutionRoot)) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-reset" `
                -Version "1.0.0" `
                -Summary "State not initialized. Nothing to reset." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "STATE_NOT_INITIALIZED" -Message "State file does not exist.")) `
                -Source ".bot/mcp/tools/state-reset/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Validate scope
        $scope = $Arguments['scope']
        if (-not $scope) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-reset" `
                -Version "1.0.0" `
                -Summary "Missing required parameter: scope" `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "INVALID_PARAMETER" -Message "scope parameter is required (all, feature, phase, or task)")) `
                -Source ".bot/mcp/tools/state-reset/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        $validScopes = @('all', 'feature', 'phase', 'task')
        if ($scope -notin $validScopes) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-reset" `
                -Version "1.0.0" `
                -Summary "Invalid scope: $scope" `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "INVALID_PARAMETER" -Message "scope must be one of: $($validScopes -join ', ')")) `
                -Source ".bot/mcp/tools/state-reset/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Check confirmation
        $confirm = $Arguments['confirm']
        if (-not $confirm) {
            $duration = Get-ToolDuration -Stopwatch $timer
            $message = "Reset scope='$scope' requires confirm=true and reason. Set confirm=true to proceed."
            return New-EnvelopeResponse `
                -Tool "state-reset" `
                -Version "1.0.0" `
                -Summary "Confirmation required for reset" `
                -Data @{ confirmation_required = $true; scope = $scope } `
                -Warnings @($message) `
                -Source ".bot/mcp/tools/state-reset/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Require reason when confirmed
        $reason = $Arguments['reason']
        if (-not $reason) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-reset" `
                -Version "1.0.0" `
                -Summary "Reason required when confirm=true" `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "CONFIRMATION_REQUIRED" -Message "reason parameter is required when confirm=true")) `
                -Source ".bot/mcp/tools/state-reset/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Read current state
        $state = Get-State -SolutionRoot $solutionRoot
        $patch = @{}
        
        # Build reset patch based on scope
        switch ($scope) {
            'all' {
                # Reset everything except updated_at
                $patch.current_feature = $null
                $patch.phase = 'spec'
                $patch.phase_index = $null
                $patch.current_task_id = $null
                $patch.active_branch = $null
                $patch.worktree_path = $null
                $patch.last_commit = $null
                $patch.notes = $null
            }
            
            'feature' {
                # Reset feature scope
                $patch.current_feature = $null
                $patch.phase = 'spec'
                $patch.phase_index = $null
                $patch.current_task_id = $null
            }
            
            'phase' {
                # Reset phase and task
                $patch.phase = 'spec'
                $patch.phase_index = $null
                $patch.current_task_id = $null
            }
            
            'task' {
                # Reset task only
                $patch.current_task_id = $null
            }
        }
        
        # Compute diff
        $diff = Compute-StateDiff -OldState $state -NewFields $patch
        
        if ($diff.Count -eq 0) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-reset" `
                -Version "1.0.0" `
                -Summary "No changes (already at reset state)" `
                -Data @{ changed = $false; state = $state } `
                -Source ".bot/mcp/tools/state-reset/script.ps1" `
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
            type = 'state_reset'
            scope = $scope
            reason = $reason
            diff = $diff
        }
        
        if ($Arguments['correlation_id']) {
            $historyEvent.correlation_id = $Arguments['correlation_id']
        }
        
        Append-StateEvent -SolutionRoot $solutionRoot -Event $historyEvent
        
        # Build summary
        $fieldCount = $diff.Count
        $summary = "Reset complete (scope=$scope, $fieldCount fields changed)"
        
        # Build result
        $result = @{
            changed = $true
            scope = $scope
            state = $state
            diff = $diff
        }
        
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "state-reset" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $result `
            -Source ".bot/mcp/tools/state-reset/script.ps1" `
            -WriteTo ".bot/state/state.json, .bot/state/history.ndjson" `
            -DurationMs $duration `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module core-helpers -ErrorAction SilentlyContinue
        Remove-Module state-helpers -ErrorAction SilentlyContinue
    }
}
