function Invoke-SolutionProjectRegister {
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
        
        # Verify project exists
        $projects = Discover-SolutionProjects -SolutionRoot $solutionRoot
        $project = $projects | Where-Object { $_.name -eq $projectName } | Select-Object -First 1
        
        if (-not $project) {
            throw "Project '$projectName' not found in solution"
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
        
        # Save registry
        $savedPath = Save-ProjectRegistry -SolutionRoot $solutionRoot -Registry $registry
        
        return @{
            success = $true
            project_name = $projectName
            registered_metadata = $entry
            message = "Project registered successfully"
            registry_path = $savedPath -replace [regex]::Escape($solutionRoot + '\'), ''
        }
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}

