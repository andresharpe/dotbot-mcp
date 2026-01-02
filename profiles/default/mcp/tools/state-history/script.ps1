function Invoke-StateHistory {
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
                -Tool "state-history" `
                -Version "1.0.0" `
                -Summary "Failed: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/state-history/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Check if history file exists
        $historyPath = Join-Path $solutionRoot '.bot\state\history.ndjson'
        if (-not (Test-Path $historyPath)) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-history" `
                -Version "1.0.0" `
                -Summary "No history found (file does not exist)" `
                -Data @{ events = @(); count = 0 } `
                -Source ".bot/mcp/tools/state-history/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Parse filters
        $limit = $Arguments['limit']
        if (-not $limit -or $limit -le 0) {
            $limit = 50
        }
        if ($limit -gt 500) {
            $limit = 500
        }
        
        $since = $Arguments['since']
        $sinceDate = $null
        if ($since) {
            try {
                $sinceDate = [DateTime]::Parse($since)
            }
            catch {
                $duration = Get-ToolDuration -Stopwatch $timer
                return New-EnvelopeResponse `
                    -Tool "state-history" `
                    -Version "1.0.0" `
                    -Summary "Invalid since timestamp: $since" `
                    -Data @{} `
                    -Errors @((New-ErrorObject -Code "INVALID_PARAMETER" -Message "since must be valid ISO 8601 timestamp")) `
                    -Source ".bot/mcp/tools/state-history/script.ps1" `
                    -DurationMs $duration `
                    -Host (Get-McpHost)
            }
        }
        
        $types = $Arguments['types']
        $feature = $Arguments['feature']
        
        # Read and parse history
        $events = @()
        $invalidLineCount = 0
        
        try {
            $lines = Get-Content $historyPath -ErrorAction Stop
            
            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }
                
                try {
                    $event = $line | ConvertFrom-Json
                    
                    # Apply filters
                    $include = $true
                    
                    # Filter by since
                    if ($sinceDate -and $event.timestamp) {
                        try {
                            $eventDate = [DateTime]::Parse($event.timestamp)
                            if ($eventDate -le $sinceDate) {
                                $include = $false
                            }
                        }
                        catch {
                            # Skip events with invalid timestamps
                            $include = $false
                        }
                    }
                    
                    # Filter by types
                    if ($include -and $types -and $types.Count -gt 0) {
                        if ($event.type -notin $types) {
                            $include = $false
                        }
                    }
                    
                    # Filter by feature
                    if ($include -and $feature) {
                        $eventFeature = $null
                        if ($event.diff -and $event.diff.current_feature -and $event.diff.current_feature.to) {
                            $eventFeature = $event.diff.current_feature.to
                        }
                        if ($eventFeature -ne $feature) {
                            $include = $false
                        }
                    }
                    
                    if ($include) {
                        $events += $event
                    }
                }
                catch {
                    # Defensively skip invalid JSON lines
                    $invalidLineCount++
                }
            }
        }
        catch {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "state-history" `
                -Version "1.0.0" `
                -Summary "Failed to read history file: $_" `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "HISTORY_FILE_INVALID" -Message "Could not read history.ndjson: $_")) `
                -Source ".bot/mcp/tools/state-history/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Sort newest first and apply limit
        $events = $events | Sort-Object { [DateTime]::Parse($_.timestamp) } -Descending
        if ($events.Count -gt $limit) {
            $events = $events[0..($limit - 1)]
        }
        
        # Build summary
        $totalCount = $events.Count
        $filterDesc = @()
        if ($limit) { $filterDesc += "limit=$limit" }
        if ($since) { $filterDesc += "since=$since" }
        if ($types) { $filterDesc += "types=$($types -join ',')" }
        if ($feature) { $filterDesc += "feature=$feature" }
        
        $filterText = if ($filterDesc.Count -gt 0) { " ($($filterDesc -join ', '))" } else { "" }
        $summary = "Found $totalCount events$filterText"
        
        if ($invalidLineCount -gt 0) {
            $summary += " ($invalidLineCount invalid lines skipped)"
        }
        
        # Build result
        $result = @{
            events = $events
            count = $totalCount
            limit = $limit
        }
        
        if ($invalidLineCount -gt 0) {
            $result.invalid_lines_skipped = $invalidLineCount
        }
        
        # Build warnings if needed
        $warnings = @()
        if ($invalidLineCount -gt 0) {
            $warnings += "Skipped $invalidLineCount invalid JSON lines in history.ndjson"
        }
        
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "state-history" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $result `
            -Warnings $warnings `
            -Source ".bot/mcp/tools/state-history/script.ps1" `
            -DurationMs $duration `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module core-helpers -ErrorAction SilentlyContinue
        Remove-Module state-helpers -ErrorAction SilentlyContinue
    }
}
