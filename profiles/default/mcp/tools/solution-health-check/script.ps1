function Invoke-SolutionHealthCheck {
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
        
        $checkLevel = if ($Arguments['check_level']) { $Arguments['check_level'] } else { 'standard' }
        $includeRecommendations = $Arguments['include_recommendations'] -ne $false
        
        $checks = @()
        $issues = @()
        $recommendations = @()
        
        # Basic checks
        $basicChecks = @()
        $botPath = Join-Path $solutionRoot '.bot'
        $basicChecks += @{
            name = '.bot directory exists'
            status = if (Test-Path $botPath) { 'pass' } else { 'error' }
        }
        
        $statePath = Join-Path $solutionRoot '.bot\.dotbot-state.json'
        $basicChecks += @{
            name = 'dotbot state file valid'
            status = if (Test-Path $statePath) { 'pass' } else { 'error' }
        }
        
        $agentsPath = Join-Path $solutionRoot '.bot\agents'
        $agentCount = if (Test-Path $agentsPath) { @(Get-ChildItem -Path $agentsPath -Filter '*.md' -Recurse).Count } else { 0 }
        $basicChecks += @{
            name = 'agents installed'
            status = if ($agentCount -gt 0) { 'pass' } else { 'warning' }
            count = $agentCount
        }
        
        $workflowsPath = Join-Path $solutionRoot '.bot\workflows'
        $workflowCount = if (Test-Path $workflowsPath) { @(Get-ChildItem -Path $workflowsPath -Filter '*.md' -Recurse).Count } else { 0 }
        $basicChecks += @{
            name = 'workflows installed'
            status = if ($workflowCount -gt 0) { 'pass' } else { 'warning' }
            count = $workflowCount
        }
        
        $standardsPath = Join-Path $solutionRoot '.bot\standards'
        $standardsCount = if (Test-Path $standardsPath) { @(Get-ChildItem -Path $standardsPath -Filter '*.md' -Recurse).Count } else { 0 }
        $basicChecks += @{
            name = 'standards installed'
            status = if ($standardsCount -gt 0) { 'pass' } else { 'warning' }
            count = $standardsCount
        }
        
        $checks += @{
            category = 'dotbot-installation'
            status = if ($basicChecks | Where-Object { $_.status -eq 'error' }) { 'error' } elseif ($basicChecks | Where-Object { $_.status -eq 'warning' }) { 'warning' } else { 'pass' }
            checks = $basicChecks
        }
        
        # Standard checks (product artifacts)
        if ($checkLevel -in @('standard', 'comprehensive')) {
            $productChecks = @()
            $missionPath = Join-Path $solutionRoot '.bot\product\mission.md'
            $productChecks += @{
                name = 'mission.md exists'
                status = if (Test-Path $missionPath) { 'pass' } else { 'warning' }
            }
            
            $techStackPath = Join-Path $solutionRoot '.bot\product\tech-stack.md'
            $productChecks += @{
                name = 'tech-stack.md exists'
                status = if (Test-Path $techStackPath) { 'pass' } else { 'warning' }
            }
            
            $roadmapPath = Join-Path $solutionRoot '.bot\product\roadmap.md'
            $productChecks += @{
                name = 'roadmap.md exists'
                status = if (Test-Path $roadmapPath) { 'pass' } else { 'warning' }
            }
            
            $checks += @{
                category = 'product-artifacts'
                status = if ($productChecks | Where-Object { $_.status -ne 'pass' }) { 'warning' } else { 'pass' }
                checks = $productChecks
            }
        }
        
        # Comprehensive checks (frontmatter, file references, orphans)
        if ($checkLevel -eq 'comprehensive') {
            # Frontmatter validation
            $frontmatterChecks = @()
            $workflowFiles = Get-ChildItem -Path $workflowsPath -Filter '*.md' -Recurse -ErrorAction SilentlyContinue
            $missingFrontmatter = 0
            foreach ($file in $workflowFiles) {
                $frontmatter = Parse-ArtifactFrontmatter -FilePath $file.FullName
                if (-not $frontmatter) {
                    $missingFrontmatter++
                }
            }
            $frontmatterChecks += @{
                name = 'workflows have frontmatter'
                status = if ($missingFrontmatter -eq 0) { 'pass' } elseif ($missingFrontmatter -lt 3) { 'warning' } else { 'error' }
                missing_count = $missingFrontmatter
            }
            
            $checks += @{
                category = 'frontmatter-validation'
                status = if ($frontmatterChecks | Where-Object { $_.status -eq 'error' }) { 'error' } elseif ($frontmatterChecks | Where-Object { $_.status -eq 'warning' }) { 'warning' } else { 'pass' }
                checks = $frontmatterChecks
            }
            
            # File reference integrity
            $refIssues = Test-FileReferenceIntegrity -SolutionRoot $solutionRoot
            $refChecks = @(
                @{
                    name = 'file references valid'
                    status = if ($refIssues.Count -eq 0) { 'pass' } else { 'error' }
                    broken_count = $refIssues.Count
                }
            )
            
            $checks += @{
                category = 'file-reference-integrity'
                status = if ($refIssues.Count -gt 0) { 'error' } else { 'pass' }
                checks = $refChecks
            }
            
            if ($refIssues.Count -gt 0) {
                $issues += @{
                    severity = 'error'
                    category = 'file-references'
                    message = "$($refIssues.Count) broken file references detected"
                    details = $refIssues | Select-Object -First 5
                    recommendation = 'Fix or remove broken references'
                }
            }
            
            # Orphan file detection
            $orphans = Find-OrphanFiles -SolutionRoot $solutionRoot
            $orphanChecks = @(
                @{
                    name = 'orphan files'
                    status = if ($orphans.Count -eq 0) { 'pass' } else { 'warning' }
                    count = $orphans.Count
                }
            )
            
            $checks += @{
                category = 'orphan-files'
                status = if ($orphans.Count -gt 0) { 'warning' } else { 'pass' }
                checks = $orphanChecks
            }
            
            if ($orphans.Count -gt 0) {
                $orphanDetails = $orphans | Select-Object -First 5 | ForEach-Object {
                    @{
                        file = $_
                        suggestion = 'Archive or delete if no longer used, or link from relevant workflow'
                    }
                }
                
                $issues += @{
                    severity = 'warning'
                    category = 'orphan-files'
                    message = "$($orphans.Count) orphan files detected (not referenced by any other file)"
                    details = $orphanDetails
                    recommendation = 'Review orphan files and either link them or archive'
                }
            }
        }
        
        # Overall status
        $overallStatus = 'healthy'
        if ($checks | Where-Object { $_.status -eq 'error' }) {
            $overallStatus = 'error'
        } elseif ($checks | Where-Object { $_.status -eq 'warning' }) {
            $overallStatus = 'warning'
        }
        
        $result = @{
            status = $overallStatus
            checks = $checks
            issues = $issues
        }
        
        if ($includeRecommendations) {
            $result.recommendations = $recommendations
        }
        
        return $result
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}

