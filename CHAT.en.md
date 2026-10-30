# Using Stata MCP in the chat surface

The **chat** surface of Claude Desktop does not use plugins. To use the Stata tools and slash commands there as well, install the two items below. If you only use cowork or Claude Code, skip this — the plugin in [README.en.md](README.en.md) section 4 is enough.

## 1. Install the extension (MCP connection)

1. Download the **one** file matching your OS:
   - Mac: [`stata-mcp-mac.mcpb`](https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/claude-plugins/chat/stata-mcp-mac.mcpb)
   - Windows: [`stata-mcp-win.mcpb`](https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/claude-plugins/chat/stata-mcp-win.mcpb)
2. In Claude Desktop, click your **name** at the bottom left → **Settings** → open **Desktop app → Extensions** in the left list.

   <img src="images/claude-ext-1.png" alt="Claude Settings - Extensions" width="640">

3. **Drag** the downloaded `.mcpb` file onto this screen. If drag-and-drop does not work, click **Advanced settings** at the bottom → **Install Extension**, select the downloaded file, and confirm (on Mac the button may read **Preview**).

   <img src="images/claude-ext-2.png" alt="Advanced settings - Install Extension button" width="640">

   <img src="images/claude-ext-3.png" alt="Select the downloaded .mcpb file" width="640">

4. In the confirmation dialog, check that the name is **Stata MCP (Mac)** (Windows: **Stata MCP (Windows)**) and click **Install** at the top right.

   <img src="images/claude-ext-4.png" alt="Install confirmation dialog" width="640">

5. Restart Claude Desktop

> Screenshots are from the Korean UI on Mac; button positions are the same. The server (`mcp_connect`) must be running for the tools to work. To update, install the new `.mcpb` file the same way.

## 2. Register the skills (slash commands)

1. [Download `stata-skills-all-en.zip`](https://raw.githubusercontent.com/mhjung0822/stata_mcp-releases/main/claude-plugins/chat/stata-skills-all-en.zip)
2. **Unzip it** — you get 12 per-skill zips
3. Claude Desktop → **Settings → Skills** → Upload → upload the extracted **per-skill zips** (do not upload the bundle zip itself)
4. Upload once and it applies automatically to every device on the same account

> A Korean edition also exists (`stata-skills-all.zip`). The skills share names across the two packs, so install only one language pack per account.

For the skill lineup and usage, see [USAGE.en.md](USAGE.en.md).

## 3. Check

In a new chat, ask "What Stata version is this?" — if a tool call appears, you are connected. Otherwise see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) (Korean).
