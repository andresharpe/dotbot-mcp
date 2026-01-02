function Invoke-SolutionTechStack {
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
        
        $techStackPath = Join-Path $solutionRoot '.bot\product\tech-stack.md'
        if (-not (Test-Path $techStackPath)) {
            throw "Tech stack file not found: .bot/product/tech-stack.md"
        }
        
        $content = Get-Content $techStackPath -Raw
        $category = if ($Arguments['category']) { $Arguments['category'] } else { 'all' }
        
        # Simple parsing - return full content for now
        # Future enhancement: parse by category
        $result = @{
            tech_stack = $content
            file_references = @{
                primary_files = @('.bot\product\tech-stack.md')
                referenced_files = @()
            }
        }
        
        return $result
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}

