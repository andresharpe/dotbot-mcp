function Invoke-SolutionStructure {
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
        
        # Discover projects
        $discoveredProjects = Discover-SolutionProjects -SolutionRoot $solutionRoot
        
        # Get registry
        $registry = Get-ProjectRegistry -SolutionRoot $solutionRoot
        
        # Merge discovered projects with registry
        $enrichedProjects = @()
        foreach ($project in $discoveredProjects) {
            # Infer metadata
            $inferred = Infer-ProjectMetadata -Project $project -AllProjects $discoveredProjects
            
            # Get registry entry
            $registryEntry = $registry.projects.($project.name)
            
            # Merge
            $merged = Merge-ProjectMetadata -DiscoveredProject $project -InferredMetadata $inferred -RegistryEntry $registryEntry
            
            # Build output structure
            $projectOutput = @{
                alias = $merged.alias
                name = $merged.name
                type = $merged.type
                path = $merged.path
            }
            
            # Add framework-specific fields
            if ($merged.target_framework) {
                $projectOutput.target_framework = $merged.target_framework
            }
            if ($merged.version) {
                $projectOutput.version = $merged.version
            }
            if ($merged.framework) {
                $projectOutput.framework = $merged.framework
            }
            
            # Add dependency count if requested
            $includeDependencies = $Arguments['include_dependencies'] -eq $true
            if ($includeDependencies -and $merged.dependency_count) {
                $projectOutput.dependency_count = $merged.dependency_count
            }
            
            # Add summary and owner
            if ($merged.summary) {
                $projectOutput.summary = $merged.summary
            }
            if ($merged.owner) {
                $projectOutput.owner = $merged.owner
            }
            if ($merged.tags) {
                $projectOutput.tags = @($merged.tags)
            }
            
            $enrichedProjects += $projectOutput
        }
        
        # Sort by alias
        $enrichedProjects = $enrichedProjects | Sort-Object alias
        
        # Detect key directories
        $keyDirs = @()
        $commonDirs = @('docs', 'scripts', 'tests', 'docker', 'terraform', 'infrastructure', 'ci', '.github', 'deploy')
        foreach ($dir in $commonDirs) {
            $dirPath = Join-Path $solutionRoot $dir
            if (Test-Path $dirPath -PathType Container) {
                $purpose = switch ($dir) {
                    'docs' { 'Documentation' }
                    'scripts' { 'Automation scripts' }
                    'tests' { 'Test files' }
                    'docker' { 'Container configurations' }
                    'terraform' { 'Infrastructure as code' }
                    'infrastructure' { 'Infrastructure definitions' }
                    'ci' { 'CI/CD pipelines' }
                    '.github' { 'GitHub workflows and actions' }
                    'deploy' { 'Deployment scripts' }
                    default { '' }
                }
                if ($purpose) {
                    $keyDirs += @{
                        name = $dir
                        purpose = $purpose
                    }
                }
            }
        }
        
        # Find solution files
        $slnFiles = Get-ChildItem -Path $solutionRoot -Filter '*.sln' -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -eq $solutionRoot } |
            Select-Object -ExpandProperty Name
        
        # Build result
        $result = @{
            solution_root = $solutionRoot
            solution_name = Split-Path $solutionRoot -Leaf
            projects = $enrichedProjects
            key_directories = $keyDirs
            solution_files = @($slnFiles)
        }
        
        # Add file references for registry if it exists
        $registryPath = Join-Path $solutionRoot '.bot\solution\projects.json'
        if (Test-Path $registryPath) {
            $result.file_references = @{
                primary_files = @('.bot\solution\projects.json')
                referenced_files = @()
            }
        }
        
        return $result
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}

