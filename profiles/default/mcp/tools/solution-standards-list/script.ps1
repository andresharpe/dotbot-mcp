function Invoke-SolutionStandardsList {
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
        
        $standardsPath = Join-Path $solutionRoot '.bot\standards'
        if (-not (Test-Path $standardsPath)) {
            return @{
                standards = @()
                summary = @{
                    total = 0
                    by_domain = @{}
                }
            }
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
        
        return @{
            standards = $standards | Sort-Object domain, title
            summary = @{
                total = $standards.Count
                by_domain = $domainCount
            }
        }
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}

