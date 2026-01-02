function Invoke-SolutionInfo {
    param(
        [hashtable]$Arguments
    )
    
    # Import helpers
    $coreHelpersPath = Join-Path $PSScriptRoot '..\..\core-helpers.psm1'
    $solutionHelpersPath = Join-Path $PSScriptRoot '..\..\solution-helpers.psm1'
    Import-Module $coreHelpersPath -Force -DisableNameChecking
    Import-Module $solutionHelpersPath -Force -DisableNameChecking
    
    $timer = Start-ToolTimer
    
    try {
        # Find solution root
        $solutionRoot = Find-SolutionRoot
        if (-not $solutionRoot) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "solution-info" `
                -Version "1.0.0" `
                -Summary "Failed to retrieve solution info: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/solution-info/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Get dotbot state
        $state = Get-DotbotState -SolutionRoot $solutionRoot
        
        # Build result
        $result = @{
            solution = @{
                name = Split-Path $solutionRoot -Leaf
                dotbot_version = $state.version
                profile = $state.profile
                installed_at = $state.installed_at
            }
            file_references = @{
                primary_files = @(
                    '.bot\.dotbot-state.json'
                )
                referenced_files = @()
                audit_trails = @()
            }
        }
        
        # Include mission if requested
        $includeMission = $Arguments['include_mission'] -ne $false
        if ($includeMission) {
            $missionPath = Join-Path $solutionRoot '.bot\product\mission.md'
            if (Test-Path $missionPath) {
                $result.file_references.primary_files += '.bot\product\mission.md'
                
                # Parse mission sections
                $missionContent = Get-Content $missionPath -Raw
                $result.mission = @{}
                
                # Extract Vision
                if ($missionContent -match '(?ms)##\s+Vision\s*\n(.+?)(?=\n##|\z)') {
                    $result.mission.vision = $Matches[1].Trim()
                }
                
                # Extract Problem Statement
                if ($missionContent -match '(?ms)##\s+Problem Statement\s*\n(.+?)(?=\n##|\z)') {
                    $result.mission.problem_statement = $Matches[1].Trim()
                }
                
                # Extract Target Users
                if ($missionContent -match '(?ms)##\s+Target Users\s*\n(.+?)(?=\n##|\z)') {
                    $targetUsersText = $Matches[1].Trim()
                    $result.mission.target_users = @($targetUsersText -split '\r?\n' | Where-Object { $_ -match '^\s*[-*]' } | ForEach-Object { $_.Trim() -replace '^\s*[-*]\s*', '' })
                }
                
                # Extract Value Proposition
                if ($missionContent -match '(?ms)##\s+Value Proposition\s*\n(.+?)(?=\n##|\z)') {
                    $result.mission.value_proposition = $Matches[1].Trim()
                }
            }
        }
        
        # Include roadmap if requested
        $includeRoadmap = $Arguments['include_roadmap'] -eq $true
        if ($includeRoadmap) {
            $roadmapPath = Join-Path $solutionRoot '.bot\product\roadmap.md'
            if (Test-Path $roadmapPath) {
                $result.file_references.primary_files += '.bot\product\roadmap.md'
                
                # Parse roadmap phases
                $roadmapContent = Get-Content $roadmapPath -Raw
                $result.roadmap = @{
                    phases = @()
                }
                
                # Extract phases (## Phase N: Title)
                $phaseMatches = [regex]::Matches($roadmapContent, '(?ms)##\s+Phase\s+(\d+):\s+(.+?)\n(.+?)(?=\n##\s+Phase|\z)')
                foreach ($match in $phaseMatches) {
                    $result.roadmap.phases += @{
                        phase = [int]$match.Groups[1].Value
                        title = $match.Groups[2].Value.Trim()
                        description = $match.Groups[3].Value.Trim().Substring(0, [Math]::Min(200, $match.Groups[3].Value.Trim().Length))
                    }
                }
            }
        }
        
        # Check for audit trails
        $auditPath = Join-Path $solutionRoot '.bot\audit\workflows\plan-product'
        if (Test-Path $auditPath) {
            $auditFiles = Get-ChildItem -Path $auditPath -Filter '*.json' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 5
            
            foreach ($audit in $auditFiles) {
                $relativePath = $audit.FullName -replace [regex]::Escape($solutionRoot + '\'), ''
                $result.file_references.audit_trails += $relativePath
            }
        }
        
        # Build summary
        $solutionName = Split-Path $solutionRoot -Leaf
        $profile = $state.profile
        $version = $state.version
        $hasMission = $result.ContainsKey('mission')
        $missionText = if ($hasMission) { "with product mission defined" } else { "(no mission)" }
        $summary = "$solutionName solution (dotbot $version, $profile profile) $missionText."
        
        # Build intent suggestion
        $intent = $null
        if ($includeRoadmap -and $result.ContainsKey('roadmap') -and $result.roadmap.phases.Count -gt 0) {
            $intent = @{
                recommended_next = "solution.structure"
                reason = "Roadmap loaded. View solution structure to see projects aligned with roadmap phases."
                parameters = @{}
            }
        }
        
        # Build envelope
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "solution-info" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $result `
            -Intent $intent `
            -Source ".bot/mcp/tools/solution-info/script.ps1" `
            -DurationMs $duration `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module core-helpers -ErrorAction SilentlyContinue
        Remove-Module core-helpers -ErrorAction SilentlyContinue
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}


