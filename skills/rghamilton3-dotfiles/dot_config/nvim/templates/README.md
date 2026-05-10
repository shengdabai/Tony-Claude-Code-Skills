# Neoconf Project Templates

This directory contains project-specific neoconf templates based on your actual workspace projects.

## Available Templates

- **fastapi/** - FastAPI Python projects (getaltair)
- **micropython/** - MicroPython embedded projects (orbit)
- **typescript-mcp/** - TypeScript MCP servers (linux-fs-mcp)
- **rust/** - Rust projects (minne)
- **python-cli/** - Python CLI tools (Skill_Seekers)
- **vue/** - Vue.js projects

## Usage

To use a template in your project:

1. Copy the desired template to your project root:
   ```bash
   cp ~/.config/nvim/templates/fastapi/.neoconf.json /path/to/your/project/
   ```

2. Customize the `.neoconf.json` file for your specific project needs

3. Restart nvim or reload the configuration

## Template Structure

Each template includes:

- **lspconfig**: LSP server settings specific to the framework
- **commands** (optional): Framework-specific commands available via `:CommandName`
- **device** (MicroPython only): Device-specific configuration

## Creating Custom Templates

1. Create a new directory in `~/.config/nvim/templates/`
2. Add a `.neoconf.json` file with your configuration
3. Use the neoconf schema for validation:
   ```json
   {
     "$schema": "https://raw.githubusercontent.com/folke/neoconf.nvim/main/schemas/neoconf.json"
   }
   ```

## Examples

### FastAPI Project (getaltair)
Framework-specific commands:
- `:FastAPIStart` - Start development server
- `:FastAPITest` - Run pytest

### MicroPython Project (orbit)
Device-specific stubs and diagnostics configured for ESP32 and RP2350.
Auto-configured for Presto and T-Embed devices.

### TypeScript MCP Server (linux-fs-mcp)
MCP-specific commands:
- `:MCPBuild` - Build server
- `:MCPWatch` - Watch and rebuild
- `:MCPInspect` - Run MCP inspector

### Rust Project (minne)
Cargo commands:
- `:CargoRun` - Run project
- `:CargoTest` - Run tests
- `:CargoBuild` - Build project
- `:CargoClippy` - Run linter
