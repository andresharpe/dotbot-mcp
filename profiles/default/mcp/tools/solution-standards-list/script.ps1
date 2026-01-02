function Invoke-SolutionStandardsList {
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
                -Tool "solution.standards.list" `
                -Version "1.0.0" `
                -Summary "Failed to list standards: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory (no .bot folder found)")) `
                -Source ".bot/mcp/tools/solution-standards-list/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        $standardsPath = Join-Path $solutionRoot '.bot\standards'
        if (-not (Test-Path $standardsPath)) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "solution.standards.list" `
                -Version "1.0.0" `
                -Summary "No standards directory found." `
                -Data @{
                    standards = @()
                    summary = @{
                        total = 0
                        by_domain = @{}
                    }
                } `
                -Warnings @("Standards directory does not exist: .bot/standards") `
                -Source ".bot/mcp/tools/solution-standards-list/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        $domain = if ($Arguments['domain']) { $Arguments['domain'] } else { 'all' }
        $includeSummaries = $Arguments['include_summaries'] -ne $false
        
        # Scan for standard files
        $standardFiles = Get-ChildItem -Path $standardsPath -Filter '*.md' -Recurse -ErrorAction SilentlyContinue
        
        $standards = @()
        $domainCount = @{}
        
        foreach ($file in $standardFiles) {
            # Infer domain from directory structure
            $relativePath = $file.FullName -replace [regex]::Escape($standardsPath + '\'), ''
            $fileDomain = if ($relativePath -match '^([^\\]+)\\') { $Matches[1] } else { 'global' }
            
            # Filter by domain if specified
            if ($domain -ne 'all' -and $fileDomain -ne $domain) {
                continue
            }
            
            # Extract title from first heading
            $content = Get-Content $file.FullName -Raw
            $title = if ($content -match '^\s*#\s+(.+)$') { $Matches[1].Trim() } else { $file.BaseName }
            
            # Extract summary (first paragraph after heading)
            $summary = ''
            if ($includeSummaries -and $content -match '^\s*#\s+.+?\n\n(.+?)(?:\n\n|\z)') {
                $summary = $Matches[1].Trim().Substring(0, [Math]::Min(150, $Matches[1].Trim().Length))
            }
            
            $relativeFile = $file.FullName -replace [regex]::Escape($solutionRoot + '\'), ''
            
            $standard = @{
                file = $relativeFile
                domain = $fileDomain
                title = $title
            }
            
            if ($summary) {
                $standard.summary = $summary
            }
            
            # Infer applicability based on domain
            $appliesTo = @()
            switch ($fileDomain) {
                'global' { $appliesTo = @('all-projects') }
                'backend' { $appliesTo = @('dotnet-web', 'dotnet-library', 'dotnet-console') }
                'frontend' { $appliesTo = @('nextjs-app', 'react-app') }
                'testing' { $appliesTo = @('dotnet-test', 'test-project') }
                default { $appliesTo = @('all-projects') }
            }
            $standard.applies_to = $appliesTo
            
            $standards += $standard
            
            # Count by domain
            if (-not $domainCount[$fileDomain]) {
                $domainCount[$fileDomain] = 0
            }
            $domainCount[$fileDomain]++
        }
        
        # Build result data
        $result = @{
            standards = $standards | Sort-Object domain, title
            summary = @{
                total = $standards.Count
                by_domain = $domainCount
            }
        }
        
        # Build summary
        $totalCount = $standards.Count
        $domainCount = $domainCount.Count
        $globalCount = if ($domainCount['global']) { $domainCount['global'] } else { 0 }
        $backendCount = if ($domainCount['backend']) { $domainCount['backend'] } else { 0 }
        $frontendCount = if ($domainCount['frontend']) { $domainCount['frontend'] } else { 0 }
        $summary = "Found $totalCount standards across $domainCount domains (global: $globalCount, backend: $backendCount, frontend: $frontendCount)."
        
        # Build envelope
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "solution.standards.list" `
            -Version "1.0.0" `
            -Summary $summary `
            -Data $result `
            -Source ".bot/mcp/tools/solution-standards-list/script.ps1" `
            -DurationMs $duration `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}

