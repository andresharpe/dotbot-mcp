#!/usr/bin/env pwsh
<#
.SYNOPSIS
    MCP Server in PowerShell with accurate date/time tools
.DESCRIPTION
    A pure PowerShell implementation of an MCP server that exposes
    deterministic date and time manipulation tools via stdio transport.
    Tools are dynamically loaded from the tools/ directory.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$InformationPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# Load helpers
. "$PSScriptRoot\dotbot-mcp-helpers.ps1"

# Helper function to parse YAML (simple implementation)
function ConvertFrom-Yaml {
    param(
        [Parameter(ValueFromPipeline)]
        [string]$InputObject
    )
    
    $result = @{}
    $lines = $InputObject -split "`n"
    $currentKey = $null
    $currentObject = $result
    $stack = New-Object System.Collections.Stack
    $lastIndent = 0
    
    foreach ($line in $lines) {
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }
        
        if ($line -match '^(\s*)') {
            $indent = $matches[1].Length
        } else {
            $indent = 0
        }
        $trimmedLine = $line.Trim()
        
        # Handle indent changes
        if ($indent -lt $lastIndent) {
            $indentDiff = $lastIndent - $indent
            for ($i = 0; $i -lt ($indentDiff / 2); $i++) {
                if ($stack.Count -gt 0) {
                    $currentObject = $stack.Pop()
                }
            }
        }
        
        if ($trimmedLine -match '^([^:]+):\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            if ($value -eq '' -or $value -eq '{}') {
                # Object or empty value
                $newObject = @{}
                $currentObject[$key] = $newObject
                $stack.Push($currentObject)
                $currentObject = $newObject
            }
            elseif ($value -eq '[]') {
                # Empty array
                $currentObject[$key] = @()
            }
            elseif ($value -match '^\[(.+)\]$') {
                # Inline array
                $arrayContent = $matches[1]
                $currentObject[$key] = $arrayContent -split ',\s*' | ForEach-Object { $_.Trim() }
            }
            elseif ($value -match '^"(.+)"$' -or $value -match "^'(.+)'$") {
                # Quoted string
                $currentObject[$key] = $matches[1]
            }
            elseif ($value -eq 'true') {
                $currentObject[$key] = $true
            }
            elseif ($value -eq 'false') {
                $currentObject[$key] = $false
            }
            elseif ($value -match '^\d+$') {
                $currentObject[$key] = [int]$value
            }
            else {
                $currentObject[$key] = $value
            }
        }
        elseif ($trimmedLine -match '^-\s*(.+)$') {
            # Array item (not implemented in this simple parser)
            continue
        }
        
        $lastIndent = $indent
    }
    
    return $result
}

# Load server metadata
$metadataPath = Join-Path $PSScriptRoot "metadata.yaml"
$serverMetadata = Get-Content $metadataPath -Raw | ConvertFrom-Yaml

# Discover and load tools
$toolsPath = Join-Path $PSScriptRoot "tools"
$tools = @{}

Get-ChildItem -Path $toolsPath -Directory | ForEach-Object {
    $toolDir = $_.FullName
    $scriptPath = Join-Path $toolDir "script.ps1"
    $metadataPath = Join-Path $toolDir "metadata.yaml"
    
    if ((Test-Path $scriptPath) -and (Test-Path $metadataPath)) {
        # Load tool script
        . $scriptPath
        
        # Load tool metadata
        $toolMetadata = Get-Content $metadataPath -Raw | ConvertFrom-Yaml
        
        # Store tool info
        $tools[$toolMetadata.name] = @{
            metadata = $toolMetadata
            scriptPath = $scriptPath
        }
        
        [Console]::Error.WriteLine("Loaded tool: $($toolMetadata.name)")
    }
}

#region MCP Handlers

function Invoke-Initialize {
    param([hashtable]$Params)
    
    return @{
        protocolVersion = $serverMetadata.protocolVersion
        capabilities = $serverMetadata.capabilities
        serverInfo = $serverMetadata.serverInfo
    }
}

function Invoke-ListTools {
    $toolList = @()
    
    foreach ($toolName in $tools.Keys) {
        $tool = $tools[$toolName]
        $toolList += @{
            name = $tool.metadata.name
            description = $tool.metadata.description
            inputSchema = $tool.metadata.inputSchema
        }
    }
    
    return @{
        tools = $toolList
    }
}

function Invoke-CallTool {
    param(
        [string]$Name,
        [hashtable]$Arguments
    )
    
    if (-not $tools.ContainsKey($Name)) {
        throw "Unknown tool: $Name"
    }
    
    try {
        # Convert tool name to function name: get_current_datetime -> Invoke-GetCurrentDateTime
        $parts = $Name -split '_'
        $functionName = 'Invoke-' + (($parts | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join '')
        
        # Call the tool function
        $result = & $functionName -Arguments $Arguments
        
        $jsonText = $result | ConvertTo-Json -Depth 100 -Compress
        
        return @{
            content = @(
                @{
                    type = 'text'
                    text = $jsonText
                }
            )
        }
    }
    catch {
        throw "Tool execution failed: $_"
    }
}

#endregion

#region Main Loop

function Start-McpServerLoop {
    [Console]::Error.WriteLine("PowerShell MCP Date Server starting...")
    [Console]::Error.WriteLine("Loaded $($tools.Count) tools")
    
    while ($true) {
        try {
            $line = [Console]::ReadLine()
            
            if ([string]::IsNullOrEmpty($line)) {
                continue
            }
            
            $request = $line | ConvertFrom-Json -AsHashtable
            
            $method = $request.method
            $id = $request.id
            $params = if ($request.params) { $request.params } else { @{} }
            
            # Handle notifications (no id) separately
            if ($null -eq $id -and $method -like 'notifications/*') {
                # Notifications don't require a response
                continue
            }
            
            $result = switch ($method) {
                'initialize' { Invoke-Initialize -Params $params }
                'tools/list' { Invoke-ListTools }
                'tools/call' { 
                    Invoke-CallTool -Name $params.name -Arguments $(if ($params.arguments) { $params.arguments } else { @{} })
                }
                default {
                    if ($null -ne $id) {
                        Write-JsonRpcError -Id $id -Code -32601 -Message "Method not found: $method"
                    }
                    continue
                }
            }
            
            # Only send response for requests with an id
            if ($null -ne $id) {
                $response = @{
                    jsonrpc = '2.0'
                    id = $id
                    result = $result
                }
                
                Write-JsonRpcResponse -Response $response
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            [Console]::Error.WriteLine("Error: $errorMessage")
            
            if ($null -ne $id) {
                Write-JsonRpcError -Id $id -Code -32603 -Message $errorMessage
            }
        }
    }
}

#endregion

# Start the server
Start-McpServerLoop
