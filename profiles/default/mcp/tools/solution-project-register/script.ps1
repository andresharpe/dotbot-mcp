function Invoke-SolutionProjectRegister {
    param(
        [hashtable]$Arguments
    )
    
    # Import helpers
    $helpersPath = Join-Path $PSScriptRoot '..\..\solution-helpers.psm1'
    Import-Module $helpersPath -Force -DisableNameChecking
    
    # Start timer
    $timer = Start-ToolTimer
    
    try {
        # Find solution root
        $solutionRoot = Find-SolutionRoot
        if (-not $solutionRoot) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "solution.project.register" `
                -Version "1.0.0" `
                -Summary "Failed to register project: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/solution-project-register/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        $projectName = $Arguments['project_name']
        if (-not $projectName) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "solution-project-register" `
                -Version "1.0.0" `
                -Summary "Failed to register project: project_name is required." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "INVALID_PARAMETER" -Message "project_name is required")) `
                -Source ".bot/mcp/tools/solution-project-register/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Verify project exists
        $projects = Discover-SolutionProjects -SolutionRoot $solutionRoot
        $project = $projects | Where-Object { $_.name -eq $projectName } | Select-Object -First 1
        
        if (-not $project) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "solution-project-register" `
                -Version "1.0.0" `
                -Summary "Project '$projectName' not found in solution." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "PROJECT_NOT_FOUND" -Message "Project '$projectName' not found in solution")) `
                -Source ".bot/mcp/tools/solution-project-register/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Load registry
        $registry = Get-ProjectRegistry -SolutionRoot $solutionRoot
        
        # Create or update entry
        if (-not $registry.projects) {
            $registry.projects = @{}
        }
        
        $entry = if ($registry.projects.$projectName) {
            $registry.projects.$projectName
        } else {
            @{
                registered_at = [DateTime]::UtcNow.ToString('o')
            }
        }
        
        # Update fields
        if ($Arguments['alias']) { $entry.alias = $Arguments['alias'] }
        if ($Arguments['summary']) { $entry.summary = $Arguments['summary'] }
        if ($Arguments['tags']) { $entry.tags = @($Arguments['tags']) }
        if ($Arguments['owner']) { $entry.owner = $Arguments['owner'] }
        
        $registry.projects[$projectName] = $entry
        
        # Save registry (with alias conflict check)
        try {
            $savedPath = Save-ProjectRegistry -SolutionRoot $solutionRoot -Registry $registry
        }
        catch {
            $duration = Get-ToolDuration -Stopwatch $timer
            $errorCode = if ($_.Exception.Message -match 'Duplicate alias') { "ALIAS_CONFLICT" } else { "REGISTRY_PARSE_ERROR" }
            return New-EnvelopeResponse `
                -Tool "solution-project-register" `
                -Version "1.0.0" `
                -Summary "Failed to save registry: $($_.Exception.Message)" `
                -Data @{} `
                -Errors @((New-ErrorObject -Code $errorCode -Message $_.Exception.Message)) `
                -Source ".bot/mcp/tools/solution-project-register/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Build result data
        $result = @{
            success = $true
            project_name = $projectName
            registered_metadata = $entry
            message = "Project registered successfully"
            registry_path = $savedPath -replace [regex]::Escape($solutionRoot + '\'), ''
        }
        
        # Build summary
        $alias = if ($entry.alias) { $entry.alias } else { "no alias" }
        $tagCount = if ($entry.tags) { $entry.tags.Count } else { 0 }
        $summary = "Registered '$projectName' with alias '$alias' and $tagCount tags."
        
        # Build actions suggestion
        $actions = @(
            @{
                id = "view-structure"
                type = "suggestion"
                label = "View solution structure"
                reason = "See updated project metadata in context"
                tool = "solution.structure"
                parameters = @{}
            }
        )
        
        # Build envelope
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "solution-project-register" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $result `
            -Actions $actions `
            -Source ".bot/mcp/tools/solution-project-register/script.ps1" `
            -DurationMs $duration `
            -WriteTo ".bot/solution/projects.json" `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}

