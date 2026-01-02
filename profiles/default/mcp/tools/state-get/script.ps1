function Invoke-StateGet {
    param([hashtable]$Arguments)
    
    # Import helpers
    $coreHelpersPath = Join-Path $PSScriptRoot '..\..\core-helpers.psm1'
    $stateHelpersPath = Join-Path $PSScriptRoot '..\..\state-helpers.psm1'
    Import-Module $coreHelpersPath -Force -DisableNameChecking
    Import-Module $stateHelpersPath -Force -DisableNameChecking
    
    $timer = Start-ToolTimer
    
    try {
        $solutionRoot = Find-SolutionRoot
        if (-not $solutionRoot) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-get" `
                -Version "1.0.0" `
                -Summary "Failed to get state: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/state-get/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        if (-not (Test-StateInitialized -SolutionRoot $solutionRoot)) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-get" `
                -Version "1.0.0" `
                -Summary "State not initialized." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "STATE_NOT_INITIALIZED" -Message "State not initialized. Use state-set to initialize.")) `
                -Source ".bot/mcp/tools/state-get/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        $state = Get-State -SolutionRoot $solutionRoot
        $includeHistory = $Arguments['include_history'] -eq $true
        $historyLimit = if ($Arguments['history_limit']) { $Arguments['history_limit'] } else { 20 }
        
        $data = @{
            state = $state
            paths = @{
                state_file = ".bot/state/state.json"
                history_file = ".bot/state/history.ndjson"
            }
        }
        
        if ($includeHistory) {
            $history = Read-StateHistory -SolutionRoot $solutionRoot -Limit $historyLimit
            $data.history = $history
        }
        
        # Build summary
        $feature = if ($state.current_feature) { $state.current_feature } else { "(none)" }
        $phase = if ($state.phase) { $state.phase } else { "(none)" }
        $task = if ($state.current_task_id) { $state.current_task_id } else { "(none)" }
        $summary = "Active feature $feature, phase $phase, task $task."
        
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "state-get" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $data `
            -Source ".bot/mcp/tools/state-get/script.ps1" `
            -DurationMs $duration `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module core-helpers -ErrorAction SilentlyContinue
        Remove-Module state-helpers -ErrorAction SilentlyContinue
    }
}
