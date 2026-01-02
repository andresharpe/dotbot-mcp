# Validate Frontmatter
# Scans all dotbot artifacts and validates YAML frontmatter

# Import solution helpers
$helpersPath = Join-Path $PSScriptRoot 'solution-helpers.psm1'
Import-Module $helpersPath -Force -DisableNameChecking

Write-Host "`n=== Frontmatter Validation ===" -ForegroundColor Cyan

$validation = @{
    total = 0
    with_frontmatter = 0
    without_frontmatter = 0
    invalid_frontmatter = 0
    schema_errors = 0
    files = @{
        missing = @()
        invalid = @()
        valid = @()
    }
}

function Test-ArtifactFrontmatter {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string]$ExpectedType,
        [string]$Category
    )
    
    $validation.total++
    $relativePath = $FilePath -replace [regex]::Escape($PSScriptRoot + '\..\..\'), ''
    
    Write-Host "`nChecking $relativePath..." -NoNewline
    
    # Parse frontmatter
    $frontmatter = Parse-ArtifactFrontmatter -FilePath $FilePath
    
    if (-not $frontmatter) {
        Write-Host " MISSING" -ForegroundColor Yellow
        $validation.without_frontmatter++
        $validation.files.missing += @{
            file = $relativePath
            category = $Category
            expected_type = $ExpectedType
        }
        return
    }
    
    $validation.with_frontmatter++
    
    # Validate schema
    $issues = Validate-FrontmatterSchema -Frontmatter $frontmatter -ExpectedType $ExpectedType
    
    if ($issues.Count -gt 0) {
        Write-Host " INVALID" -ForegroundColor Red
        $validation.invalid_frontmatter++
        $validation.schema_errors += $issues.Count
        
        $validation.files.invalid += @{
            file = $relativePath
            category = $Category
            issues = $issues
        }
        
        foreach ($issue in $issues) {
            Write-Host "  ✗ $issue" -ForegroundColor Red
        }
    }
    else {
        Write-Host " VALID" -ForegroundColor Green
        $validation.files.valid += $relativePath
        Write-Host "  ✓ type=$($frontmatter.type), id=$($frontmatter.id), version=$($frontmatter.version)" -ForegroundColor Gray
    }
}

# Scan Commands
Write-Host "`n[1/3] Validating Commands" -ForegroundColor Cyan
$commandsPath = Join-Path $PSScriptRoot '..\..\commands'
if (Test-Path $commandsPath) {
    $commandFiles = Get-ChildItem -Path $commandsPath -Filter '*.md' -File
    Write-Host "Found $($commandFiles.Count) command files"
    
    foreach ($file in $commandFiles) {
        Test-ArtifactFrontmatter `
            -FilePath $file.FullName `
            -ExpectedType 'command' `
            -Category 'command'
    }
}
else {
    Write-Host "Commands directory not found: $commandsPath" -ForegroundColor Yellow
}

# Scan Workflows
Write-Host "`n[2/3] Validating Workflows" -ForegroundColor Cyan
$workflowsPath = Join-Path $PSScriptRoot '..\..\workflows'
if (Test-Path $workflowsPath) {
    $workflowFiles = Get-ChildItem -Path $workflowsPath -Filter '*.md' -File -Recurse
    Write-Host "Found $($workflowFiles.Count) workflow files"
    
    foreach ($file in $workflowFiles) {
        $subcategory = $file.DirectoryName -replace [regex]::Escape($workflowsPath + '\'), ''
        Test-ArtifactFrontmatter `
            -FilePath $file.FullName `
            -ExpectedType 'workflow' `
            -Category "workflow/$subcategory"
    }
}
else {
    Write-Host "Workflows directory not found: $workflowsPath" -ForegroundColor Yellow
}

# Scan Agents
Write-Host "`n[3/3] Validating Agents" -ForegroundColor Cyan
$agentsPath = Join-Path $PSScriptRoot '..\..\agents'
if (Test-Path $agentsPath) {
    $agentFiles = Get-ChildItem -Path $agentsPath -Filter '*.md' -File
    Write-Host "Found $($agentFiles.Count) agent files"
    
    foreach ($file in $agentFiles) {
        Test-ArtifactFrontmatter `
            -FilePath $file.FullName `
            -ExpectedType 'agent' `
            -Category 'agent'
    }
}
else {
    Write-Host "Agents directory not found: $agentsPath" -ForegroundColor Yellow
}

# Summary Report
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total files scanned: $($validation.total)"
Write-Host "With frontmatter: $($validation.with_frontmatter)" -ForegroundColor Green
Write-Host "Missing frontmatter: $($validation.without_frontmatter)" -ForegroundColor $(if ($validation.without_frontmatter -gt 0) { 'Yellow' } else { 'Gray' })
Write-Host "Invalid frontmatter: $($validation.invalid_frontmatter)" -ForegroundColor $(if ($validation.invalid_frontmatter -gt 0) { 'Red' } else { 'Gray' })
Write-Host "Total schema errors: $($validation.schema_errors)" -ForegroundColor $(if ($validation.schema_errors -gt 0) { 'Red' } else { 'Gray' })

# Missing Frontmatter Report
if ($validation.without_frontmatter -gt 0) {
    Write-Host "`n=== Files Missing Frontmatter ===" -ForegroundColor Yellow
    
    $byCategory = $validation.files.missing | Group-Object -Property category
    foreach ($group in $byCategory) {
        Write-Host "`n$($group.Name):" -ForegroundColor Cyan
        foreach ($file in $group.Group) {
            Write-Host "  • $($file.file)" -ForegroundColor Yellow
            Write-Host "    Expected type: $($file.expected_type)" -ForegroundColor Gray
        }
    }
}

# Invalid Frontmatter Report
if ($validation.invalid_frontmatter -gt 0) {
    Write-Host "`n=== Files with Invalid Frontmatter ===" -ForegroundColor Red
    
    foreach ($file in $validation.files.invalid) {
        Write-Host "`n$($file.file):" -ForegroundColor Red
        foreach ($issue in $file.issues) {
            Write-Host "  ✗ $issue" -ForegroundColor Red
        }
    }
}

# Validation Pass/Fail
Write-Host "`n=== Result ===" -ForegroundColor Cyan
if ($validation.without_frontmatter -eq 0 -and $validation.invalid_frontmatter -eq 0) {
    Write-Host "✓ All artifacts have valid frontmatter!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Validation failed" -ForegroundColor Red
    if ($validation.without_frontmatter -gt 0) {
        Write-Host "  $($validation.without_frontmatter) file(s) missing frontmatter" -ForegroundColor Yellow
    }
    if ($validation.invalid_frontmatter -gt 0) {
        Write-Host "  $($validation.invalid_frontmatter) file(s) with invalid frontmatter" -ForegroundColor Red
    }
    exit 1
}

# Cleanup
Remove-Module solution-helpers -ErrorAction SilentlyContinue
