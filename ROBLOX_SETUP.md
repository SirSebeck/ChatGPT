# Urban Plant Tycoon Berlin – Prototype Setup

## 1) Folder structure (in Roblox Studio)

```text
ReplicatedStorage
└── Remotes
    ├── RequestState (RemoteEvent)
    ├── TimeUpdate (RemoteEvent)
    ├── Toast (RemoteEvent)
    ├── SleepRequest (RemoteEvent)
    ├── BuySeedRequest (RemoteEvent)
    ├── SellHarvestRequest (RemoteEvent)
    ├── PlantSeedRequest (RemoteEvent)
    ├── HarvestRequest (RemoteEvent)
    └── OpenShop (RemoteEvent)
└── Shared
    ├── PlantDefinitions (ModuleScript)
    └── FieldDefinitions (ModuleScript)

ServerScriptService
├── Main.server.lua
└── Services
    ├── PlayerDataService.lua
    ├── TimeService.lua
    ├── FarmingService.lua
    └── EconomyService.lua

StarterPlayer
└── StarterPlayerScripts
    └── Client
        └── MainHUD.client.lua

StarterGui
└── MainHUD
    └── BuildHUD.client.lua
```

## 2) World objects (Workspace)

Create these objects:
- `Folder` named `TycoonFields`
  - Add a few `Part`s as fields. For each field set attributes:
    - `FieldType` = `SUN_WET | SUN_DRY | SHADE_WET | SHADE_DRY`
    - `OwnerUserId` = your user id (optional)
- `Part` named `SeedShopPart`
- `Part` named `SellShopPart`
- `Part` named `SleepPart`

`Main.server.lua` auto-adds `ProximityPrompt`s on those 3 shop/sleep parts.

## 3) Rules implemented

- 1 month = 20 real-time minutes.
- Sleep button/prompt requests next month (server-authoritative, includes cooldown + cost).
- Matching ideal month and ideal field gives high growth/yield multipliers.
- One match gives small bonus; no match gives malus but still grows.
- Harvest possible at growth completion or in harvest window.
- Buy/sell/plant/harvest validated server-side.
- DataStore persistence with retries and sanitization.

## 4) Notes

- Weather event hook already prepared in `FarmingService.lua` (`weatherEventState`) for later expansion.
- If you already built your own HUD, keep object names expected by `MainHUD.client.lua`.
