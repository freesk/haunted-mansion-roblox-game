# Horror Mansion Escape

A multiplayer Roblox horror game for kids 10-14 where players must work together to escape procedurally generated haunted mansions while avoiding ghosts, monsters, and other supernatural threats.

**🎮 [Play on Roblox](https://www.roblox.com/games/105167692541036/Horror-Mansion-Escape)**

## 🎮 Game Features

### Core Gameplay

- **Cooperative Multiplayer**: 1-8 players work together to escape haunted mansions
- **Procedural Mansion Generation**: Each round features a unique mansion layout with randomly placed rooms and furniture
- **Proximity-Based Gameplay**: Stay close to teammates to survive - separation leads to danger
- **Round-Based System**: Competitive rounds with leaderboards and scoring
- **Progressive Difficulty**: Multiple mansion types with increasing challenges

### Spooky Elements

- **Ghost NPCs**: Animated ghosts that haunt the mansion corridors
- **Monster AI**: Intelligent monster pathfinding that hunts players
- **Butler Character**: Mysterious NPC that adds to the atmospheric tension
- **Ambient Sound System**: Dynamic audio that responds to gameplay events
- **Atmospheric Lighting**: Dynamic lighting with controllable lamps and ceiling lights

### Persistence & Progression

- **Player Data System**: ProfileService integration for persistent player data
- **Leaderboards**: Track and display top players across rounds
- **Results Screen**: Post-round statistics and performance metrics

### Performance Optimized

- **Mobile-Friendly**: Targeted 30 FPS on mobile devices
- **Efficient Part Budget**: <10,000 parts total, <500 parts per mansion
- **Network Optimization**: <50 KB/s per player bandwidth usage
- **Security**: Rate limiting and anti-exploit measures built-in

## 🛠 Development Setup

This project uses [Rojo](https://rojo.space/) for version control and local development with Roblox Studio.

### Prerequisites

- [Roblox Studio](https://www.roblox.com/create)
- [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (v7.0+)
  - Install via [aftman](https://github.com/LPGhatguy/aftman) (recommended)
  - Or install standalone from [releases](https://github.com/rojo-rbx/rojo/releases)

### Getting Started

1. **Install Rojo Plugin in Studio**
   - Open Roblox Studio
   - Open the plugins folder: `%LOCALAPPDATA%\Roblox\Plugins` (Windows) or `~/Documents/Roblox/Plugins` (macOS)
   - Download the latest Rojo plugin from [GitHub releases](https://github.com/rojo-rbx/rojo/releases)
   - Or use the plugin installer: run `rojo plugin install` in this directory

2. **Start Local Development Server**

   ```bash
   rojo serve
   ```

   - Server will start on `http://localhost:34872`
   - Leave this terminal running while developing
   - You should see: `Rojo server listening on 0.0.0.0:34872`

3. **Connect Studio to Rojo**
   - Open Roblox Studio with an empty baseplate or the published game
   - Click the Rojo plugin button in the toolbar
   - Click "Connect" (it should auto-detect `localhost:34872`)
   - Click "Sync In" to sync the project into your Studio session

4. **Development Workflow**
   - Edit `.lua` files in your preferred code editor (VS Code recommended)
   - Changes automatically sync to Studio in real-time via the Rojo plugin
   - Test changes immediately using Studio's playtest mode (F5 for client, F7 for server)
   - Use the Debug UI (enabled in-game) to inspect game state

### Project Structure

```
src/
├── server/                 # Server-side code (ServerScriptService)
│   └── ServerScriptService/
│       ├── Services/       # Core game services
│       │   ├── GameStateService.lua      # Game state management
│       │   ├── RoundService.lua          # Round logic and timers
│       │   ├── LobbyService.lua          # Lobby and ready system
│       │   ├── MansionService.lua        # Mansion lifecycle
│       │   ├── ProximityService.lua      # Player proximity tracking
│       │   ├── PlayerService.lua         # Player management
│       │   ├── DataService.lua           # Data persistence (ProfileService)
│       │   ├── ResultsService.lua        # Post-round results
│       │   ├── DebugService.lua          # Debug utilities
│       │   └── SecurityService.lua       # Anti-exploit & rate limiting
│       ├── Modules/        # Server modules
│       │   ├── MansionGenerator.lua      # Procedural generation
│       │   ├── FurnitureSpawner.lua      # Furniture placement
│       │   ├── RoomFurnitureSpawner.lua  # Room-specific furniture
│       │   ├── AmbientSoundManager.lua   # Audio management
│       │   ├── PathValidator.lua         # Pathfinding validation
│       │   ├── Ghost/                    # Ghost NPC system
│       │   ├── Monster/                  # Monster NPC system
│       │   └── Butler/                   # Butler NPC system
│       └── ServerInit.server.lua         # Server entry point
│
├── client/                 # Client-side code (StarterPlayer)
│   └── StarterPlayer/
│       └── StarterPlayerScripts/
│           ├── Controllers/              # Client controllers
│           │   ├── LeaderboardUIController.lua
│           │   └── RoundUIController.lua
│           ├── ClientInit.client.lua     # Client entry point
│           ├── ClientSoundManager.client.lua
│           ├── ProximityUINew.client.lua
│           └── DebugUI.client.lua        # Debug overlay
│
├── shared/                 # Shared code (ReplicatedStorage)
│   └── ReplicatedStorage/
│       ├── Shared/         # Shared utilities
│       │   ├── Constants.lua             # Game constants
│       │   ├── GameConfig.lua            # Configuration values
│       │   ├── MansionConfig.lua         # Mansion settings
│       │   └── Types/                    # Type definitions
│       ├── Remotes/        # RemoteEvents/RemoteFunctions
│       │   ├── RoundEvents.lua
│       │   ├── LeaderboardEvents.lua
│       │   ├── ProximityEvents.lua
│       │   └── SoundEvents.lua
│       └── Packages/       # Third-party packages
│           └── ProfileService.lua        # Data persistence library
│
└── storage/                # Server-only assets (ServerStorage)
    └── ServerStorage/
        └── Mansions/       # Mansion models and prefabs
```

### Rojo Configuration

The `default.project.json` file maps the local folder structure to Roblox services:

- `src/server/ServerScriptService` → ServerScriptService
- `src/client/StarterPlayer` → StarterPlayer
- `src/shared/ReplicatedStorage` → ReplicatedStorage
- `src/storage/ServerStorage` → ServerStorage

### Testing

- **Solo Testing**: Set `MIN_PLAYERS_TO_START = 1` in `GameConfig.lua` for solo testing
- **Multiplayer Testing**: Publish to Roblox and use Team Test in Studio
- **Debug Mode**: Use the in-game debug UI to inspect:
  - Round state and timers
  - Player positions and proximity
  - NPC behavior and pathfinding
  - Performance metrics

## 📖 Game Design

**Core Mechanic:** Players must stay together or face death timers when separated. Random separation events create tension while cooperative scoring rewards keeping the team alive.

**Target Audience:** Kids aged 10-14 playing in groups with friends.

**Content Rating:** Mild (Roblox standards) - Spooky atmosphere without gore or intense violence.

### Scoring System

- 100 points per surviving teammate
- 500 point bonus for completing the mansion
- Up to 200 bonus points for fast completion times

### Performance Budget

- Max 10,000 total parts in workspace
- Max 500 parts per mansion
- Target 30 FPS on mobile devices
- Max 500 MB memory usage
- Network: <50 KB/s per player

## 🚀 Publishing

To publish changes to Roblox:

1. Build the place file:

   ```bash
   rojo build -o HorrorMansion.rbxl
   ```

2. Open the `.rbxl` file in Roblox Studio

3. Publish to Roblox via File → Publish to Roblox

## 📄 License

MIT License

Copyright (c) 2025 Haunted Mansion Escape Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

**Made with ❤️ for the Roblox community. Free to use, modify, and share!**
