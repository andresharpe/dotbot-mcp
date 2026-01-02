function Invoke-SolutionProjectUpdate {
    param(
        [hashtable]$Arguments
    )
    
    # Import helpers
    $helpersPath = Join-Path $PSScriptRoot '..\..\solution-helpers.psm1'
    Import-Module $helpersPath -Force -DisableNameChecking
    
    try {
        # Find solution root
        $solutionRoot = Find-SolutionRoot
        if (-not $solutionRoot) {
            throw "Not in a dotbot solution directory (no .bot folder found)"
        }
        
        $projectName = $Arguments['project_name']
        if (-not $projectName) {
            throw "project_name is required"
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
            throw "Project '$projectName' not found in registry. Use solution.project.register first."
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
        
        # Save registry
        $savedPath = Save-ProjectRegistry -SolutionRoot $solutionRoot -Registry $registry
        
        return @{
            success = $true
            project_name = $actualProjectName
            updated_fields = $updatedFields
            current_metadata = $entry
        }
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}
