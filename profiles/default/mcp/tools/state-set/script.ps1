function Invoke-StateSet {
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
                -Tool "state-set" `
                -Version "1.0.0" `
                -Summary "Failed to set state: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/state-set/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Get patch parameter
        $patch = $Arguments['patch']
        if (-not $patch) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-set" `
                -Version "1.0.0" `
                -Summary "No patch provided." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "INVALID_ARGUMENTS" -Message "The 'patch' parameter is required.")) `
                -Source ".bot/mcp/tools/state-set/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Convert patch to hashtable if it's a PSCustomObject
        $patchHash = @{}
        if ($patch -is [hashtable]) {
            $patchHash = $patch
        }
        elseif ($patch.PSObject.Properties) {
            $patch.PSObject.Properties | ForEach-Object {
                $patchHash[$_.Name] = $_.Value
            }
        }
        
        # Get correlation_id if provided
        $correlationId = $Arguments['correlation_id']
        $reason = $Arguments['reason']
        
        # Auto-initialize if not initialized
        $stateInitialized = Test-StateInitialized -SolutionRoot $solutionRoot
        if (-not $stateInitialized) {
            $oldState = Initialize-State -SolutionRoot $solutionRoot
            $isNewInit = $true
        }
        else {
            $oldState = Get-State -SolutionRoot $solutionRoot
            $isNewInit = $false
        }
        
        # Apply patch to create new state
        $newState = @{}
        foreach ($key in $oldState.Keys) {
            $newState[$key] = $oldState[$key]
        }
        foreach ($key in $patchHash.Keys) {
            $newState[$key] = $patchHash[$key]
        }
        
        # Always update timestamp
        $newState['updated_at'] = (Get-Date).ToUniversalTime().ToString('o')
        
        # Validate state if validation is enabled (default: true)
        $skipValidation = $Arguments['skip_validation'] -eq $true
        if (-not $skipValidation) {
            $validationIssues = Test-StateValid -State $newState
            if ($validationIssues.Count -gt 0) {
                $duration = Get-ToolDuration -Stopwatch $timer
                return New-EnvelopeResponse `
                    -Tool "state-set" `
                    -Version "1.0.0" `
                    -Summary "State validation failed: $($validationIssues[0])" `
                    -Data @{ validation_errors = $validationIssues } `
                    -Errors @((New-ErrorObject -Code "INVALID_STATE" -Message "State validation failed: $($validationIssues -join '; ')")) `
                    -Source ".bot/mcp/tools/state-set/script.ps1" `
                    -DurationMs $duration `
                    -Host (Get-McpHost)
            }
        }
        
        # Compute diff
        $diff = Compute-StateDiff -OldState $oldState -NewState $newState
        
        # Check if there are any changes (excluding updated_at)
        $meaningfulChanges = $diff.Clone()
        $meaningfulChanges.Remove('updated_at')
        
        if ($meaningfulChanges.Count -eq 0 -and -not $isNewInit) {
            # No changes
            $duration = Get-ToolDuration -Stopwatch $timer
            $data = @{
                state = $newState
                changed = $false
                diff = @{}
            }
            
            return New-EnvelopeResponse `
                -Tool "state-set" `
                -Version "1.0.0" `
                -Summary "No changes to state." `
                -Data $data `
                -Source ".bot/mcp/tools/state-set/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Write state atomically
        Write-StateAtomic -SolutionRoot $solutionRoot -State $newState
        
        # Append to history (unless it's the initial creation, which already logged)
        if (-not $isNewInit) {
            $eventReason = if ($reason) { $reason } else { "State updated" }
            Append-StateEvent `
                -SolutionRoot $solutionRoot `
                -Type "state_set" `
                -Reason $eventReason `
                -Diff $meaningfulChanges `
                -CorrelationId $correlationId
        }
        
        # Build summary
        $changeCount = $meaningfulChanges.Count
        $changedKeys = $meaningfulChanges.Keys -join ', '
        $summary = if ($isNewInit) {
            "State initialized with $changeCount field(s): $changedKeys"
        }
        else {
            "State updated: $changeCount field(s) changed ($changedKeys)"
        }
        
        $data = @{
            state = $newState
            changed = $true
            diff = $meaningfulChanges
            paths = @{
                state_file = ".bot/state/state.json"
                history_file = ".bot/state/history.ndjson"
            }
        }
        
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "state-set" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $data `
            -Source ".bot/mcp/tools/state-set/script.ps1" `
            -DurationMs $duration `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module core-helpers -ErrorAction SilentlyContinue
        Remove-Module state-helpers -ErrorAction SilentlyContinue
    }
}
