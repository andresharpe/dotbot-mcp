function Invoke-SolutionProjectUpdate {
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
                -Tool "solution.project.update" `
                -Version "1.0.0" `
                -Summary "Failed to update project: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/solution-project-update/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        $projectName = $Arguments['project_name']
        if (-not $projectName) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "solution.project.update" `
                -Version "1.0.0" `
                -Summary "Failed to update project: project_name is required." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "INVALID_PARAMETER" -Message "project_name is required")) `
                -Source ".bot/mcp/tools/solution-project-update/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Load registry
        $registry = Get-ProjectRegistry -SolutionRoot $solutionRoot
        
        # Find project (by name or alias)
        $entry = $null
        $actualProjectName = $null
        
        # Try direct match first
        if ($registry.projects.$projectName) {
            $entry = $registry.projects.$projectName
            $actualProjectName = $projectName
        }
        else {
            # Try alias match
            foreach ($name in $registry.projects.Keys) {
                if ($registry.projects.$name.alias -eq $projectName) {
                    $entry = $registry.projects.$name
                    $actualProjectName = $name
                    break
                }
            }
        }
        
        if (-not $entry) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "solution.project.update" `
                -Version "1.0.0" `
                -Summary "Project '$projectName' not found in registry." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "PROJECT_NOT_FOUND" -Message "Project '$projectName' not found in registry. Use solution.project.register first.")) `
                -Source ".bot/mcp/tools/solution-project-update/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Track updated fields
        $updatedFields = @()
        
        # Update fields
        if ($Arguments.ContainsKey('alias')) {
            $entry.alias = $Arguments['alias']
            $updatedFields += 'alias'
        }
        if ($Arguments.ContainsKey('summary')) {
            $entry.summary = $Arguments['summary']
            $updatedFields += 'summary'
        }
        if ($Arguments.ContainsKey('tags')) {
            $entry.tags = @($Arguments['tags'])
            $updatedFields += 'tags'
        }
        if ($Arguments.ContainsKey('owner')) {
            $entry.owner = $Arguments['owner']
            $updatedFields += 'owner'
        }
        
        $registry.projects[$actualProjectName] = $entry
        
        # Save registry (with alias conflict check)
        try {
            $savedPath = Save-ProjectRegistry -SolutionRoot $solutionRoot -Registry $registry
        }
        catch {
            $duration = Get-ToolDuration -Stopwatch $timer
            $errorCode = if ($_.Exception.Message -match 'Duplicate alias') { "ALIAS_CONFLICT" } else { "REGISTRY_PARSE_ERROR" }
            return New-EnvelopeResponse `
                -Tool "solution.project.update" `
                -Version "1.0.0" `
                -Summary "Failed to save registry: $($_.Exception.Message)" `
                -Data @{} `
                -Errors @((New-ErrorObject -Code $errorCode -Message $_.Exception.Message)) `
                -Source ".bot/mcp/tools/solution-project-update/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Build result data
        $result = @{
            success = $true
            project_name = $actualProjectName
            updated_fields = $updatedFields
            current_metadata = $entry
        }
        
        # Build summary
        $fieldCount = $updatedFields.Count
        $fieldsList = if ($fieldCount -gt 0) { $updatedFields -join ", " } else { "no fields" }
        $summary = "Updated $fieldCount fields for '$actualProjectName': $fieldsList."
        
        # Build envelope
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "solution.project.update" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $result `
            -Source ".bot/mcp/tools/solution-project-update/script.ps1" `
            -DurationMs $duration `
            -WriteTo ".bot/solution/projects.json" `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}
