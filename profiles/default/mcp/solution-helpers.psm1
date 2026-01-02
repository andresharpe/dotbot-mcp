# Solution Helpers Module
# Provides core functionality for solution-awareness MCP tools

# Import core helpers
$coreHelpersPath = Join-Path $PSScriptRoot 'core-helpers.psm1'
Import-Module $coreHelpersPath -Force -DisableNameChecking

#region Solution Discovery

# Find-SolutionRoot is now in core-helpers.psm1

function Get-DotbotState {
    <#
    .SYNOPSIS
    Loads .bot/.dotbot-state.json
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot
    )
    
    $statePath = Join-Path $SolutionRoot '.bot\.dotbot-state.json'
    if (-not (Test-Path $statePath)) {
        throw "Dotbot state file not found: $statePath"
    }
    
    $content = Get-Content $statePath -Raw | ConvertFrom-Json
    return $content
}

#endregion

#region Project Discovery

function Discover-SolutionProjects {
    <#
    .SYNOPSIS
    Scans filesystem for projects (.csproj, package.json, .sln files)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot
    )
    
    $projects = @()
    
    # Find .NET projects
    $csprojFiles = Get-ChildItem -Path $SolutionRoot -Filter '*.csproj' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\obj\\|\\bin\\|\\node_modules\\|\\\.bot\\' }
    
    foreach ($csproj in $csprojFiles) {
        try {
            [xml]$content = Get-Content $csproj.FullName -Raw
            $project = @{
                name = $csproj.BaseName
                type = Get-DotnetProjectType -CsprojXml $content
                path = $csproj.Directory.Name
                full_path = $csproj.DirectoryName
                target_framework = $content.Project.PropertyGroup.TargetFramework | Select-Object -First 1
                file_path = $csproj.FullName
            }
            
            # Get dependency count
            $packageRefs = $content.Project.ItemGroup.PackageReference
            $project.dependency_count = if ($packageRefs) { @($packageRefs).Count } else { 0 }
            
            $projects += $project
        }
        catch {
            # Silently skip invalid project files (MCP tools must not write to stdout)
        }
    }
    
    # Find Node/frontend projects
    $packageJsonFiles = Get-ChildItem -Path $SolutionRoot -Filter 'package.json' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\node_modules\\|\\\.bot\\' }
    
    foreach ($packageJson in $packageJsonFiles) {
        try {
            $content = Get-Content $packageJson.FullName -Raw | ConvertFrom-Json
            $project = @{
                name = $content.name
                type = Get-NodeProjectType -PackageJson $content
                path = $packageJson.Directory.Name
                full_path = $packageJson.DirectoryName
                version = $content.version
                file_path = $packageJson.FullName
            }
            
            # Get dependency count
            $depCount = 0
            if ($content.dependencies) { $depCount += $content.dependencies.PSObject.Properties.Count }
            if ($content.devDependencies) { $depCount += $content.devDependencies.PSObject.Properties.Count }
            $project.dependency_count = $depCount
            
            # Detect framework
            if ($content.dependencies.next) {
                $project.framework = "Next.js $($content.dependencies.next)"
            }
            elseif ($content.dependencies.react) {
                $project.framework = "React $($content.dependencies.react)"
            }
            
            $projects += $project
        }
        catch {
            # Silently skip invalid package.json files (MCP tools must not write to stdout)
        }
    }
    
    return $projects
}

function Get-DotnetProjectType {
    param(
        [Parameter(Mandatory)]
        [xml]$CsprojXml
    )
    
    $outputType = $CsprojXml.Project.PropertyGroup.OutputType | Select-Object -First 1
    $sdk = $CsprojXml.Project.Sdk
    
    # Check for test frameworks
    $packageRefs = $CsprojXml.Project.ItemGroup.PackageReference.Include
    if ($packageRefs -match 'xUnit|NUnit|MSTest') {
        return 'dotnet-test'
    }
    
    # Check SDK type
    if ($sdk -match 'Microsoft\.NET\.Sdk\.Web') {
        return 'dotnet-web'
    }
    
    # Check output type
    if ($outputType -eq 'Exe') {
        return 'dotnet-console'
    }
    
    return 'dotnet-library'
}

function Get-NodeProjectType {
    param(
        [Parameter(Mandatory)]
        $PackageJson
    )
    
    # Check for Next.js
    if ($PackageJson.dependencies.next) {
        return 'nextjs-app'
    }
    
    # Check for React
    if ($PackageJson.dependencies.react) {
        return 'react-app'
    }
    
    # Check for test frameworks
    if ($PackageJson.devDependencies.jest -or $PackageJson.devDependencies.vitest) {
        return 'test-project'
    }
    
    return 'node-app'
}

#endregion

#region Project Metadata

function Infer-ProjectMetadata {
    <#
    .SYNOPSIS
    Generates default metadata (alias, summary, tags) from discovered project
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Project,
        [array]$AllProjects
    )
    
    $metadata = @{
        alias = $null
        summary = $null
        tags = @()
    }
    
    # Generate alias
    $metadata.alias = Get-InferredAlias -Project $Project -AllProjects $AllProjects
    
    # Generate summary
    $metadata.summary = Infer-ProjectSummary -Project $Project
    
    # Generate tags
    $metadata.tags = Get-InferredTags -Project $Project
    
    return $metadata
}

function Get-InferredAlias {
    param(
        [hashtable]$Project,
        [array]$AllProjects
    )
    
    $name = $Project.name.ToLower()
    $type = $Project.type
    
    # Frontend projects
    if ($type -match 'nextjs|react') {
        $frontendCount = @($AllProjects | Where-Object { $_.type -match 'nextjs|react' }).Count
        if ($frontendCount -le 1) {
            return 'fe'
        }
        else {
            # Add suffix based on name
            if ($name -match 'admin') { return 'fe-admin' }
            if ($name -match 'mobile') { return 'fe-mobile' }
            return 'fe'
        }
    }
    
    # Backend/API projects
    if ($type -match 'dotnet-web') {
        $backendCount = @($AllProjects | Where-Object { $_.type -eq 'dotnet-web' }).Count
        if ($backendCount -le 1) {
            return 'be'
        }
        else {
            if ($name -match 'api') { return 'be' }
            if ($name -match 'core') { return 'be-core' }
            return 'be'
        }
    }
    
    # Test projects
    if ($type -match 'test') {
        # Try to infer what it's testing
        if ($name -match 'frontend|fe') { return 'fe-test' }
        if ($name -match 'backend|api|be') { return 'be-test' }
        return 'test'
    }
    
    # Special abbreviations
    if ($name -match 'peoplesoft') { return 'psx' }
    if ($name -match 'mcp.*server|mcpserver') { return 'mcp-ps' }
    
    # Library projects - use abbreviated name
    if ($type -eq 'dotnet-library') {
        # Get last segment after dot
        $segments = $Project.name -split '\.'
        $lastSegment = $segments[-1].ToLower()
        if ($lastSegment.Length -le 4) {
            return $lastSegment
        }
        return $segments[-1].Substring(0, 3).ToLower()
    }
    
    # Default: use abbreviated project name
    if ($Project.name.Length -le 4) {
        return $Project.name.ToLower()
    }
    return $Project.name.Substring(0, 3).ToLower()
}

function Infer-ProjectSummary {
    <#
    .SYNOPSIS
    Generates smart summary based on project name and type
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Project
    )
    
    $type = $Project.type
    $name = $Project.name
    
    switch ($type) {
        'dotnet-web' { return "ASP.NET Core web API" }
        'dotnet-library' { return "Class library for $name" }
        'dotnet-console' { return "Console application" }
        'dotnet-test' { return "Unit and integration tests" }
        'nextjs-app' { return "Next.js frontend application" }
        'react-app' { return "React frontend application" }
        'test-project' { return "Test suite" }
        default { return "Project: $name" }
    }
}

function Get-InferredTags {
    param(
        [hashtable]$Project
    )
    
    $tags = @()
    
    switch ($Project.type) {
        'dotnet-web' { $tags += @('api', 'backend', 'dotnet') }
        'dotnet-library' { $tags += @('library', 'dotnet') }
        'dotnet-console' { $tags += @('console', 'dotnet') }
        'dotnet-test' { $tags += @('test', 'dotnet') }
        'nextjs-app' { $tags += @('frontend', 'nextjs', 'react') }
        'react-app' { $tags += @('frontend', 'react') }
        'test-project' { $tags += @('test', 'node') }
    }
    
    return $tags
}

#endregion

#region Project Registry

function Get-ProjectRegistry {
    <#
    .SYNOPSIS
    Loads .bot/solution/projects.json (returns empty if missing)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot
    )
    
    $registryPath = Join-Path $SolutionRoot '.bot\solution\projects.json'
    
    if (-not (Test-Path $registryPath)) {
        return @{
            registry_version = '1.0'
            last_updated = $null
            projects = @{}
        }
    }
    
    try {
        $content = Get-Content $registryPath -Raw | ConvertFrom-Json
        return $content
    }
    catch {
        # Silently return empty registry if parse fails (MCP tools must not write to stdout)
        return @{
            registry_version = '1.0'
            last_updated = $null
            projects = @{}
        }
    }
}

function Merge-ProjectMetadata {
    <#
    .SYNOPSIS
    Combines inferred + registry (registry takes precedence for all fields)
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$DiscoveredProject,
        [Parameter(Mandatory)]
        [hashtable]$InferredMetadata,
        [object]$RegistryEntry
    )
    
    $merged = $DiscoveredProject.Clone()
    
    # Start with inferred metadata
    $merged.alias = $InferredMetadata.alias
    $merged.summary = $InferredMetadata.summary
    $merged.tags = $InferredMetadata.tags
    $merged.owner = $null
    
    # Registry overrides (AI-enriched data wins)
    if ($RegistryEntry) {
        if ($RegistryEntry.alias) { $merged.alias = $RegistryEntry.alias }
        if ($RegistryEntry.summary) { $merged.summary = $RegistryEntry.summary }
        if ($RegistryEntry.tags) { $merged.tags = @($RegistryEntry.tags) }
        if ($RegistryEntry.owner) { $merged.owner = $RegistryEntry.owner }
    }
    
    return $merged
}

function Get-ProjectAlias {
    <#
    .SYNOPSIS
    Retrieves alias (from registry first, then inferred)
    #>
    param(
        [string]$ProjectName,
        [string]$SolutionRoot
    )
    
    $registry = Get-ProjectRegistry -SolutionRoot $SolutionRoot
    
    if ($registry.projects.$ProjectName -and $registry.projects.$ProjectName.alias) {
        return $registry.projects.$ProjectName.alias
    }
    
    # Fallback: discover and infer
    $projects = Discover-SolutionProjects -SolutionRoot $SolutionRoot
    $project = $projects | Where-Object { $_.name -eq $ProjectName } | Select-Object -First 1
    
    if ($project) {
        $inferred = Infer-ProjectMetadata -Project $project -AllProjects $projects
        return $inferred.alias
    }
    
    return $null
}

function Save-ProjectRegistry {
    <#
    .SYNOPSIS
    Atomically saves registry with validation
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot,
        [Parameter(Mandatory)]
        [hashtable]$Registry
    )
    
    # Validate unique aliases
    $aliases = @{}
    foreach ($projectName in $Registry.projects.Keys) {
        $entry = $Registry.projects.$projectName
        if ($entry.alias) {
            $existing = $aliases[$entry.alias]
            if ($existing -and $existing -ne $projectName) {
                throw "Duplicate alias '$($entry.alias)' for projects '$existing' and '$projectName'"
            }
            $aliases[$entry.alias] = $projectName
        }
    }
    
    # Ensure directory exists
    $solutionDir = Join-Path $SolutionRoot '.bot\solution'
    if (-not (Test-Path $solutionDir)) {
        New-Item -ItemType Directory -Path $solutionDir -Force | Out-Null
    }
    
    # Update timestamp
    $Registry.last_updated = [DateTime]::UtcNow.ToString('o')
    
    # Save atomically
    $registryPath = Join-Path $SolutionRoot '.bot\solution\projects.json'
    $tempPath = "$registryPath.tmp"
    
    $json = $Registry | ConvertTo-Json -Depth 10
    Set-Content -Path $tempPath -Value $json -Force
    Move-Item -Path $tempPath -Destination $registryPath -Force
    
    return $registryPath
}

#endregion

#region Markdown Parsing

function Parse-MarkdownSection {
    <#
    .SYNOPSIS
    Extracts sections from markdown files
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string]$SectionHeading
    )
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    $content = Get-Content $FilePath -Raw
    
    if ($SectionHeading) {
        # Extract specific section
        $pattern = "(?ms)^#{1,3}\s+$SectionHeading\s*$(.+?)(?=^#{1,3}\s+|\z)"
        if ($content -match $pattern) {
            return $Matches[1].Trim()
        }
        return $null
    }
    
    return $content
}

#endregion

#region File References

function Resolve-FileReferences {
    <#
    .SYNOPSIS
    Recursively resolves @file, workflow, agent references
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string]$SolutionRoot,
        [hashtable]$Visited = @{}
    )
    
    if ($Visited[$FilePath]) {
        return @()  # Avoid circular references
    }
    
    $Visited[$FilePath] = $true
    $references = @()
    
    if (-not (Test-Path $FilePath)) {
        return $references
    }
    
    # Get direct references from this file
    $directRefs = Get-FileReferences -FilePath $FilePath -SolutionRoot $SolutionRoot
    $references += $directRefs
    
    # Recursively resolve references
    foreach ($ref in $directRefs) {
        $refPath = if ([System.IO.Path]::IsPathRooted($ref)) {
            $ref
        }
        else {
            Join-Path $SolutionRoot $ref
        }
        
        $nested = Resolve-FileReferences -FilePath $refPath -SolutionRoot $SolutionRoot -Visited $Visited
        $references += $nested
    }
    
    return $references | Select-Object -Unique
}

function Get-FileReferences {
    <#
    .SYNOPSIS
    Extracts all references from a file using regex patterns
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string]$SolutionRoot
    )
    
    if (-not (Test-Path $FilePath)) {
        return @()
    }
    
    $references = @()
    $content = Get-Content $FilePath -Raw
    
    # Pattern 1: @.bot/path/to/file.md
    $matches = [regex]::Matches($content, '@(\.bot/[^\s\)]+\.md)')
    foreach ($match in $matches) {
        $references += $match.Groups[1].Value
    }
    
    # Pattern 2: YAML frontmatter dependencies
    $frontmatter = Parse-ArtifactFrontmatter -FilePath $FilePath
    if ($frontmatter -and $frontmatter.dependencies) {
        foreach ($dep in $frontmatter.dependencies) {
            if ($dep.file) {
                $references += $dep.file
            }
        }
    }
    
    return $references | Select-Object -Unique
}

function Build-FileDependencyGraph {
    <#
    .SYNOPSIS
    Creates dependency chain for output
    #>
    param(
        [Parameter(Mandatory)]
        [array]$FilePaths,
        [string]$SolutionRoot
    )
    
    $graph = @()
    
    foreach ($filePath in $FilePaths) {
        $refs = Get-FileReferences -FilePath $filePath -SolutionRoot $SolutionRoot
        if ($refs.Count -gt 0) {
            $graph += @{
                file = $filePath -replace [regex]::Escape($SolutionRoot + '\'), ''
                references = @($refs)
            }
        }
    }
    
    return $graph
}

function Test-FileReferenceIntegrity {
    <#
    .SYNOPSIS
    Validates all file references exist
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot
    )
    
    $botPath = Join-Path $SolutionRoot '.bot'
    $issues = @()
    
    # Scan all .md files in .bot directory
    $mdFiles = Get-ChildItem -Path $botPath -Filter '*.md' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\node_modules\\' }
    
    foreach ($file in $mdFiles) {
        $refs = Get-FileReferences -FilePath $file.FullName -SolutionRoot $SolutionRoot
        
        foreach ($ref in $refs) {
            $refPath = Join-Path $SolutionRoot $ref
            if (-not (Test-Path $refPath)) {
                $relativePath = $file.FullName -replace [regex]::Escape($SolutionRoot + '\'), ''
                $issues += @{
                    source = $relativePath
                    reference = $ref
                    issue = 'Referenced file does not exist'
                }
            }
        }
    }
    
    return $issues | Sort-Object -Property source
}

function Find-OrphanFiles {
    <#
    .SYNOPSIS
    Identifies files with no incoming references
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SolutionRoot,
        [array]$EntryPoints = @('.bot\commands\', '.bot\specs\', '.bot\rules\', '.bot\product\')
    )
    
    $botPath = Join-Path $SolutionRoot '.bot'
    
    # Get all files
    $allFiles = Get-ChildItem -Path $botPath -Filter '*.md' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\node_modules\\' } |
        ForEach-Object { $_.FullName -replace [regex]::Escape($SolutionRoot + '\'), '' }
    
    # Build reference map
    $referencedFiles = @{}
    foreach ($filePath in $allFiles) {
        $fullPath = Join-Path $SolutionRoot $filePath
        $refs = Get-FileReferences -FilePath $fullPath -SolutionRoot $SolutionRoot
        
        foreach ($ref in $refs) {
            $referencedFiles[$ref] = $true
        }
        
        # Also check frontmatter used_by
        $frontmatter = Parse-ArtifactFrontmatter -FilePath $fullPath
        if ($frontmatter -and $frontmatter.used_by) {
            foreach ($usedBy in $frontmatter.used_by) {
                $referencedFiles[$usedBy] = $true
            }
        }
    }
    
    # Find orphans (not referenced, not entry points)
    $orphans = @()
    foreach ($filePath in $allFiles) {
        $isReferenced = $referencedFiles[$filePath]
        $isEntryPoint = $false
        
        foreach ($entryPattern in $EntryPoints) {
            if ($filePath -like "$entryPattern*") {
                $isEntryPoint = $true
                break
            }
        }
        
        if (-not $isReferenced -and -not $isEntryPoint) {
            $orphans += $filePath
        }
    }
    
    return $orphans | Sort-Object
}

#endregion

#region YAML Frontmatter

function Parse-ArtifactFrontmatter {
    <#
    .SYNOPSIS
    Extracts and validates YAML frontmatter from artifacts
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    $content = Get-Content $FilePath -Raw
    
    # Match YAML frontmatter (--- at start, --- at end)
    if ($content -match '(?ms)^---\s*\r?\n(.+?)\r?\n---\s*\r?\n') {
        $yamlContent = $Matches[1]
        
        try {
            # Simple YAML parsing (handles common cases)
            $frontmatter = @{}
            $lines = $yamlContent -split '\r?\n'
            $currentKey = $null
            $currentList = $null
            
            foreach ($line in $lines) {
                # Skip comments
                if ($line -match '^\s*#') { continue }
                
                # Key-value pair
                if ($line -match '^\s*([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)$') {
                    $key = $Matches[1]
                    $value = $Matches[2].Trim()
                    
                    if ($value -eq '') {
                        # This is a list or object key
                        $currentKey = $key
                        $currentList = @()
                    }
                    elseif ($value -match '^[0-9]+(\.[0-9]+)?$') {
                        # Number
                        $frontmatter[$key] = [double]$value
                    }
                    elseif ($value -match '^(true|false)$') {
                        # Boolean
                        $frontmatter[$key] = $value -eq 'true'
                    }
                    else {
                        # String
                        $frontmatter[$key] = $value
                    }
                    $currentKey = $key
                }
                # List item
                elseif ($line -match '^\s*-\s+(.+)$' -and $currentKey) {
                    $value = $Matches[1].Trim()
                    
                    if (-not $frontmatter[$currentKey]) {
                        $frontmatter[$currentKey] = @()
                    }
                    
                    # Check if it's a nested object
                    if ($value -match '^([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)$') {
                        $nestedKey = $Matches[1]
                        $nestedValue = $Matches[2].Trim()
                        $currentList = @{ $nestedKey = $nestedValue }
                    }
                    else {
                        if ($currentList) {
                            $frontmatter[$currentKey] += $currentList
                            $currentList = $null
                        }
                        $frontmatter[$currentKey] += $value
                    }
                }
                # Nested object property
                elseif ($line -match '^\s{2,}([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)$' -and $currentList) {
                    $nestedKey = $Matches[1]
                    $nestedValue = $Matches[2].Trim()
                    $currentList[$nestedKey] = $nestedValue
                }
            }
            
            # Add last list item if exists
            if ($currentList -and $currentKey) {
                $frontmatter[$currentKey] += $currentList
            }
            
            return $frontmatter
        }
        catch {
            # Silently return null if YAML parse fails (MCP tools must not write to stdout)
            return $null
        }
    }
    
    return $null
}

function Get-ArtifactDependencies {
    <#
    .SYNOPSIS
    Reads dependencies from frontmatter
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    $frontmatter = Parse-ArtifactFrontmatter -FilePath $FilePath
    
    if ($frontmatter -and $frontmatter.dependencies) {
        return @($frontmatter.dependencies)
    }
    
    return @()
}

function Validate-FrontmatterSchema {
    <#
    .SYNOPSIS
    Ensures frontmatter matches expected schema
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,
        [Parameter(Mandatory)]
        [string]$ExpectedType
    )
    
    $issues = @()
    
    # Required fields for all types
    if (-not $Frontmatter.type) {
        $issues += 'Missing required field: type'
    }
    elseif ($Frontmatter.type -ne $ExpectedType) {
        $issues += "Type mismatch: expected '$ExpectedType', got '$($Frontmatter.type)'"
    }
    
    if (-not $Frontmatter.id) {
        $issues += 'Missing required field: id'
    }
    
    if (-not $Frontmatter.version) {
        $issues += 'Missing required field: version'
    }
    
    # Type-specific validation
    switch ($ExpectedType) {
        'workflow' {
            if (-not $Frontmatter.category) { $issues += 'Missing required field: category' }
            if (-not $Frontmatter.agent) { $issues += 'Missing required field: agent' }
        }
        'agent' {
            if (-not $Frontmatter.role) { $issues += 'Missing required field: role' }
        }
        'standard' {
            if (-not $Frontmatter.domain) { $issues += 'Missing required field: domain' }
        }
    }
    
    return $issues
}

#endregion

#region State Management

# State management functions have been moved to state-helpers.psm1
# Import state-helpers.psm1 to use state management functions

#endregion

#region Envelope Response

# Envelope response functions are now in core-helpers.psm1

# Solution-specific error codes
$script:SolutionErrorCodes = @{
    STATE_FILE_INVALID = "STATE_FILE_INVALID"
    REGISTRY_PARSE_ERROR = "REGISTRY_PARSE_ERROR"
    FRONTMATTER_MISSING = "FRONTMATTER_MISSING"
    FRONTMATTER_INVALID = "FRONTMATTER_INVALID"
    BROKEN_FILE_REFERENCE = "BROKEN_FILE_REFERENCE"
    CIRCULAR_DEPENDENCY = "CIRCULAR_DEPENDENCY"
    PROJECT_NOT_FOUND = "PROJECT_NOT_FOUND"
    ALIAS_CONFLICT = "ALIAS_CONFLICT"
    TECH_STACK_MISSING = "TECH_STACK_MISSING"
    STANDARDS_NOT_FOUND = "STANDARDS_NOT_FOUND"
    UNAUTHORIZED_OPERATION = "UNAUTHORIZED_OPERATION"
}

#endregion

# Export functions (including re-exported core-helpers functions)
Export-ModuleMember -Function @(
    # Core functions (from core-helpers.psm1)
    'Find-SolutionRoot',
    'New-ErrorObject',
    'Start-ToolTimer',
    'Get-ToolDuration',
    'Get-McpHost',
    'New-EnvelopeResponse',
    'Assert-EnvelopeSchema',
    # Solution-specific functions
    'Get-DotbotState',
    'Discover-SolutionProjects',
    'Infer-ProjectMetadata',
    'Get-ProjectRegistry',
    'Merge-ProjectMetadata',
    'Get-ProjectAlias',
    'Save-ProjectRegistry',
    'Parse-MarkdownSection',
    'Infer-ProjectSummary',
    'Resolve-FileReferences',
    'Build-FileDependencyGraph',
    'Test-FileReferenceIntegrity',
    'Find-OrphanFiles',
    'Get-FileReferences',
    'Parse-ArtifactFrontmatter',
    'Get-ArtifactDependencies',
    'Validate-FrontmatterSchema'
)

# Export error codes
Export-ModuleMember -Variable @('SolutionErrorCodes', 'CoreErrorCodes')
