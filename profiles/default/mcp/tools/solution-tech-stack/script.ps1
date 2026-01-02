function Invoke-SolutionTechStack {
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
                -Tool "solution.tech_stack" `
                -Version "1.0.0" `
                -Summary "Failed to load tech stack: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/solution-tech-stack/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        $techStackPath = Join-Path $solutionRoot '.bot\product\tech-stack.md'
        if (-not (Test-Path $techStackPath)) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "solution.tech_stack" `
                -Version "1.0.0" `
                -Summary "Tech stack file not found." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "TECH_STACK_MISSING" -Message "Tech stack file not found: .bot/product/tech-stack.md")) `
                -Source ".bot/mcp/tools/solution-tech-stack/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        $content = Get-Content $techStackPath -Raw
        $category = if ($Arguments['category']) { $Arguments['category'] } else { 'all' }
        
        # Parse key frameworks from content
        $backend = if ($content -match '(?ms)##\s+Backend.*?(?:Framework|Language).*?:\s*\*\*(.+?)\*\*') { $Matches[1].Trim() } else { "unknown" }
        $frontend = if ($content -match '(?ms)##\s+Frontend.*?Framework.*?:\s*\*\*(.+?)\*\*') { $Matches[1].Trim() } else { "unknown" }
        $database = if ($content -match '(?ms)##\s+(?:Backend|Database).*?Database.*?:\s*\*\*(.+?)\*\*') { $Matches[1].Trim() } else { "unknown" }
        
        # Count key libraries (rough estimate)
        $libraryCount = ([regex]::Matches($content, '\*\*[^*]+\*\*')).Count
        
        # Build result
        $result = @{
            tech_stack = $content
            file_references = @{
                primary_files = @('.bot\product\tech-stack.md')
                referenced_files = @()
            }
        }
        
        # Build summary
        $summary = "Tech stack loaded: $backend, $frontend, $database, $libraryCount key libraries."
        
        # Build envelope
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "solution.tech_stack" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $result `
            -Source ".bot/mcp/tools/solution-tech-stack/script.ps1" `
            -DurationMs $duration `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}

