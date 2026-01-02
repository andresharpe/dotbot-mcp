# State Management Helper Functions
# Extracted from solution-helpers.psm1 for better modularity

#region State Error Codes

# State-specific error codes
$script:StateErrorCodes = @{
    STATE_NOT_INITIALIZED = "STATE_NOT_INITIALIZED"
    STATE_ALREADY_EXISTS = "STATE_ALREADY_EXISTS"
    INVALID_PHASE = "INVALID_PHASE"
    INVALID_TASK_ID = "INVALID_TASK_ID"
    PHASE_ORDER_MISSING = "PHASE_ORDER_MISSING"
    TASK_NOT_FOUND = "TASK_NOT_FOUND"
    CONFIRMATION_REQUIRED = "CONFIRMATION_REQUIRED"
    HISTORY_FILE_INVALID = "HISTORY_FILE_INVALID"
    INVALID_STATE = "INVALID_STATE"
    INVALID_ARGUMENTS = "INVALID_ARGUMENTS"
}

#endregion

#region State File Operations

function Test-StateInitialized {
    <#
    .SYNOPSIS
    Check if state is initialized and valid
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot
    )
    
    $statePath = Join-Path $SolutionRoot '.bot\state\state.json'
    if (-not (Test-Path $statePath)) {
        return $false
    }
    
    try {
        $content = Get-Content $statePath -Raw | ConvertFrom-Json
        return $true
    }
    catch {
        return $false
    }
}

function Get-State {
    <#
    .SYNOPSIS
    Read current state from state.json
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot
    )
    
    $statePath = Join-Path $SolutionRoot '.bot\state\state.json'
    if (-not (Test-Path $statePath)) {
        return $null
    }
    
    try {
        $content = Get-Content $statePath -Raw | ConvertFrom-Json
        # Convert to hashtable for easier manipulation
        $state = @{}
        $content.PSObject.Properties | ForEach-Object {
            $state[$_.Name] = $_.Value
        }
        return $state
    }
    catch {
        throw "Failed to read state file: $_"
    }
}

function Initialize-State {
    <#
    .SYNOPSIS
    Create default state.json with null/default fields
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot
    )
    
    $stateDir = Join-Path $SolutionRoot '.bot\state'
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    
    $defaultState = @{
        current_feature = $null
        phase = $null
        phase_index = $null
        current_task_id = $null
        active_branch = $null
        worktree_path = $null
        last_commit = $null
        updated_at = (Get-Date).ToUniversalTime().ToString('o')
        notes = $null
        locks = $null
    }
    
    Write-StateAtomic -SolutionRoot $SolutionRoot -State $defaultState | Out-Null
    
    # Log initialization
    Append-StateEvent `
        -SolutionRoot $SolutionRoot `
        -Type "state_init" `
        -Reason "State initialized" `
        -Diff @{} `
        -CorrelationId $null | Out-Null
    
    return $defaultState
}

function Write-StateAtomic {
    <#
    .SYNOPSIS
    Write state atomically using temp file + rename
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot,
        [Parameter(Mandatory)]
        [hashtable]$State
    )
    
    $stateDir = Join-Path $SolutionRoot '.bot\state'
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    
    $statePath = Join-Path $stateDir 'state.json'
    $tempPath = Join-Path $stateDir "state.tmp.$([Guid]::NewGuid()).json"
    
    try {
        # Write to temp file
        $State | ConvertTo-Json -Depth 10 | Set-Content -Path $tempPath -Encoding UTF8
        
        # Atomic rename
        Move-Item -Path $tempPath -Destination $statePath -Force
        
        return $statePath
    }
    catch {
        # Cleanup temp file if failed
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        }
        throw "Failed to write state atomically: $_"
    }
}

#endregion

#region State Validation

function Test-StateValid {
    <#
    .SYNOPSIS
    Validate state schema and field formats
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )
    
    $issues = @()
    
    # Validate phase enum
    $validPhases = @('spec', 'tasks', 'implement', 'verify', 'deploy')
    if ($State.phase -and $State.phase -notin $validPhases) {
        $issues += "Invalid phase: $($State.phase). Must be one of: $($validPhases -join ', ')"
    }
    
    # Validate task_id format (simple check: non-empty string)
    if ($State.current_task_id -and [string]::IsNullOrWhiteSpace($State.current_task_id)) {
        $issues += "Invalid task_id: cannot be empty or whitespace"
    }
    
    # Validate commit sha format (basic: 7-40 hex chars)
    if ($State.last_commit -and $State.last_commit -notmatch '^[a-f0-9]{7,40}$') {
        $issues += "Invalid commit SHA format: $($State.last_commit)"
    }
    
    return $issues
}

function Compute-StateDiff {
    <#
    .SYNOPSIS
    Compare old and new state, return changed keys
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$OldState,
        [Parameter(Mandatory)]
        [hashtable]$NewState
    )
    
    $diff = @{}
    
    foreach ($key in $NewState.Keys) {
        $oldValue = $OldState[$key]
        $newValue = $NewState[$key]
        
        # Compare values (handle nulls)
        $changed = if ($null -eq $oldValue -and $null -eq $newValue) {
            $false
        }
        elseif ($null -eq $oldValue -or $null -eq $newValue) {
            $true
        }
        else {
            $oldValue -ne $newValue
        }
        
        if ($changed) {
            $diff[$key] = @{
                from = $oldValue
                to = $newValue
            }
        }
    }
    
    return $diff
}

#endregion

#region State History

function Append-StateEvent {
    <#
    .SYNOPSIS
    Append event to history.ndjson
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot,
        [Parameter(Mandatory)]
        [string]$Type,
        [string]$Reason = $null,
        [hashtable]$Diff = @{},
        [string]$CorrelationId = $null,
        [string]$Scope = $null
    )
    
    $stateDir = Join-Path $SolutionRoot '.bot\state'
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    
    $historyPath = Join-Path $stateDir 'history.ndjson'
    
    $event = @{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        type = $Type
    }
    
    if ($Reason) { $event.reason = $Reason }
    if ($CorrelationId) { $event.correlation_id = $CorrelationId }
    if ($Scope) { $event.scope = $Scope }
    if ($Diff.Count -gt 0) { $event.diff = $Diff }
    
    # Append as single JSON line
    $jsonLine = ($event | ConvertTo-Json -Compress -Depth 10)
    Add-Content -Path $historyPath -Value $jsonLine -Encoding UTF8
    
    return $event
}

function Read-StateHistory {
    <#
    .SYNOPSIS
    Read and filter history.ndjson
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot,
        [int]$Limit = 50,
        [string]$Since = $null,
        [array]$Types = $null,
        [string]$Feature = $null
    )
    
    $historyPath = Join-Path $SolutionRoot '.bot\state\history.ndjson'
    if (-not (Test-Path $historyPath)) {
        return @()
    }
    
    $events = @()
    $lines = Get-Content $historyPath -Encoding UTF8
    
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        try {
            $event = $line | ConvertFrom-Json
            
            # Apply filters
            if ($Since -and $event.timestamp -lt $Since) { continue }
            if ($Types -and $event.type -notin $Types) { continue }
            if ($Feature -and $event.diff.current_feature.to -ne $Feature) { continue }
            
            # Convert to hashtable
            $eventHash = @{}
            $event.PSObject.Properties | ForEach-Object {
                $eventHash[$_.Name] = $_.Value
            }
            
            $events += $eventHash
        }
        catch {
            # Skip invalid lines
            Write-Warning "Skipping invalid history line: $line"
        }
    }
    
    # Return newest first, limited
    $events = $events | Select-Object -Last $events.Count | Sort-Object { $_.timestamp } -Descending
    if ($Limit -gt 0) {
        $events = $events | Select-Object -First $Limit
    }
    
    return $events
}

#endregion

# Export all functions
Export-ModuleMember -Function @(
    'Test-StateInitialized',
    'Get-State',
    'Initialize-State',
    'Write-StateAtomic',
    'Test-StateValid',
    'Compute-StateDiff',
    'Append-StateEvent',
    'Read-StateHistory'
)

# Export error codes
Export-ModuleMember -Variable @('StateErrorCodes')
