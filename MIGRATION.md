# Migration Guide: dotbot v1.x to v2.0

This guide helps existing dotbot v1.x users upgrade to the unified dotbot v2.0 system.

## What Changed in v2.0?

### Repository Consolidation
- **Old:** Separate `dotbot` and `dotbot-mcp` repositories
- **New:** Unified `dotbot-mcp` repository (with `dotbot` branding)
- **Why:** Single installation provides both orchestration (MCP) and execution (workflows/agents/standards)

### Major Additions
✅ **MCP Server Integration** - Project-native orchestration tools  
✅ **Enhanced Installation** - Improved cross-platform support  
✅ **Configuration v2.0** - New config.yml with MCP settings  
✅ **State Tracking** - `.dotbot-state.json` for installation metadata  

### What Stayed the Same
✅ All CLI commands work identically  
✅ Profile system unchanged (default, dotnet)  
✅ All workflows, agents, standards preserved  
✅ Installation paths unchanged (`~/dotbot`, `.bot/`)  
✅ Warp integration unchanged  

## Should You Upgrade?

**Upgrade if:**
- ✅ You want MCP orchestration tools (state, task, feature management)
- ✅ You want the latest improvements and bug fixes
- ✅ You're starting new projects
- ✅ You want unified documentation and support

**Stay on v1.x if:**
- ⚠️ You have critical projects in active development
- ⚠️ You want to wait for Phase 3 orchestration tools to be complete

## Migration Steps

### Step 1: Backup Current Installation

```powershell
# Backup global installation
cp -r ~/dotbot ~/dotbot-v1-backup

# List your projects with dotbot installed
# (You'll need to update each one separately)
```

### Step 2: Uninstall Old Version

```powershell
# Remove from PATH (manual or using old uninstall script)
# Windows: Remove ~/dotbot/bin from User PATH in registry
# macOS/Linux: Remove dotbot export lines from shell profile

# Remove global installation
rm -rf ~/dotbot

# Verify removal
dotbot status  # Should fail or show old version
```

### Step 3: Install v2.0

```powershell
# Clone new repository
git clone https://github.com/[user]/dotbot-mcp ~/dotbot-temp
cd ~/dotbot-temp

# Run installer
pwsh init.ps1

# Verify installation
dotbot status
# Should show: dotbot v2.0.0 installed

dotbot help
# Should show all commands
```

### Step 4: Update Existing Projects

For each project with dotbot v1.x installed:

```powershell
cd ~/my-project

# Check current version
cat .bot/.dotbot-state.json
# If version < 2.0.0, update is needed

# Update project
dotbot update-project

# Verify update
cat .bot/.dotbot-state.json
# Should show version: 2.0.0

# Check MCP server installed
ls .bot/mcp/
# Should see: dotbot-mcp.ps1, metadata.yaml, tools/, etc.
```

### Step 5: Update MCP Configuration (If Using)

If you previously configured `dotbot-mcp` separately, update your MCP client config:

**Warp:**
- Settings → Features → MCP Servers
- Update server path to point to project's `.bot/mcp/dotbot-mcp.ps1`

**Claude Desktop:**
```json
{
  "mcpServers": {
    "dotbot": {
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File",
        "/absolute/path/to/project/.bot/mcp/dotbot-mcp.ps1"
      ]
    }
  }
}
```

## Breaking Changes

### None for Standard Use Cases

If you used dotbot v1.x for standard development workflows:
- ✅ All commands work the same
- ✅ All workflows unchanged
- ✅ All agents unchanged
- ✅ All standards unchanged

### If You Customized Dotbot

**Custom profiles:**
- ✅ Still work - located in `~/dotbot/profiles/[profile-name]/`
- ✅ Now can include `mcp/` subdirectory for orchestration tools

**Custom scripts:**
- ⚠️ If you modified installation scripts, review changes in `scripts/`
- ⚠️ New `Install-MCP` function in `project-install.ps1`

**Custom workflows:**
- ✅ No changes needed
- ✅ Can now reference MCP tools in workflow content

## New Features in v2.0

### 1. MCP Server Per Project

Each project now gets its own MCP orchestration server:

```
.bot/mcp/
├── dotbot-mcp.ps1           # Server entry point
├── dotbot-mcp-helpers.ps1   # Helper functions
├── metadata.yaml            # Server metadata
└── tools/                   # Orchestration tools
```

**Current tools:** Example date/time tools (demonstrating architecture)  
**Planned (Phase 3):** state.get, task.next, feature.start, intent.next, etc.

### 2. Enhanced Configuration

New `config.yml` settings:

```yaml
version: 2.0.0
mcp_enabled: true
mcp_protocol_version: "2024-11-05"
standards_as_warp_rules: true
profile: default
```

### 3. Installation State Tracking

New `.bot/.dotbot-state.json` in projects:

```json
{
  "version": "2.0.0",
  "profile": "default",
  "installed_at": "2026-01-02T08:00:00Z",
  "standards_as_warp_rules": true,
  "mcp_enabled": true,
  "mcp_tools_version": "1.0.0"
}
```

### 4. Improved Documentation

- Unified README.md covering both orchestration and execution
- Updated QUICKSTART.md with MCP setup
- New MIGRATION.md (this file)
- Enhanced WARP.md with architecture details

## Troubleshooting Migration

### "dotbot command not found" After Installation

```powershell
# Check installation
ls ~/dotbot

# Verify PATH includes ~/dotbot/bin
$env:PATH -split (';')  # Windows
echo $PATH | tr ':' '\n'  # macOS/Linux

# Re-run installer
cd ~/dotbot-temp
pwsh init.ps1
```

### Project Update Fails

```powershell
# Remove existing installation
dotbot remove-project

# Reinitialize
dotbot init

# Or manually update
# 1. Backup .bot/ directory
cp -r .bot .bot-backup

# 2. Remove .bot/
rm -rf .bot

# 3. Reinitialize
dotbot init

# 4. Restore any custom files
# (workflows, agents, standards you modified)
```

### MCP Server Won't Start

```powershell
# Test server manually
pwsh -NoProfile -ExecutionPolicy Bypass -File .bot/mcp/dotbot-mcp.ps1

# Check PowerShell version (need 7.0+)
pwsh --version

# Verify file exists
ls .bot/mcp/dotbot-mcp.ps1
```

### Missing Files After Update

```powershell
# Check what was installed
cat .bot/.dotbot-state.json

# Verify all components
ls .bot/agents/
ls .bot/workflows/
ls .bot/standards/
ls .bot/mcp/

# If missing, reinitialize
dotbot update-project
```

## Rollback Instructions

If you need to rollback to v1.x:

### Step 1: Uninstall v2.0

```powershell
cd ~/dotbot
pwsh scripts/uninstall.ps1
```

### Step 2: Restore v1.x Backup

```powershell
# Restore global installation
cp -r ~/dotbot-v1-backup ~/dotbot

# Add to PATH (if removed)
# Follow PATH setup for your platform
```

### Step 3: Restore Project Installations

For each project:

```powershell
cd ~/my-project

# If you backed up .bot/
rm -rf .bot
cp -r .bot-backup .bot

# Or remove and reinstall with v1.x
dotbot remove-project
dotbot init  # Using v1.x CLI
```

## Getting Help

### Common Questions

**Q: Can I use v1.x and v2.0 simultaneously?**  
A: No. Only one global installation can be active at a time.

**Q: Will my existing projects break?**  
A: No. After running `dotbot update-project`, everything continues working.

**Q: Do I need to use the MCP server?**  
A: No. It's installed but optional. All workflows/agents/standards work standalone.

**Q: Can I customize the MCP tools?**  
A: Yes. See `profiles/default/mcp/README-NEWTOOL.md` for creating custom tools.

**Q: What happened to the old dotbot repository?**  
A: It will be archived with a notice pointing to the unified repository.

### Support Channels

- **Documentation:** [README.md](README.md), [QUICKSTART.md](QUICKSTART.md), [WARP.md](WARP.md)
- **Issues:** GitHub Issues on dotbot-mcp repository
- **Discussions:** GitHub Discussions

## What's Next?

After migrating to v2.0:

1. **Explore MCP Integration** - Connect Warp or Claude to use orchestration tools
2. **Try New Workflows** - All existing workflows enhanced with state tracking (Phase 3)
3. **Customize Tools** - Create project-specific MCP tools
4. **Stay Updated** - Watch repository for Phase 2 and Phase 3 releases

### Roadmap

- **Phase 1 (Current):** Repository merge, basic integration ✅
- **Phase 2 (Next):** Cross-platform testing, documentation refinement
- **Phase 3 (Planned):** Full orchestration tools (state, task, feature, intent management)

## Feedback

Encountered issues during migration? Have suggestions for improvement?

- Open an issue: [GitHub Issues](https://github.com/[user]/dotbot-mcp/issues)
- Share feedback: [GitHub Discussions](https://github.com/[user]/dotbot-mcp/discussions)

**Thank you for upgrading to dotbot v2.0!** 🚀
