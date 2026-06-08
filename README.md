# Monster Garden

モンスター育成 × ガーデニングシミュレーター for Roblox

## Overview

| Item | Detail |
|------|--------|
| Genre | Monster Breeding × Gardening Simulator |
| Platform | Roblox (PC / Mobile / PS / Xbox) |
| Target | All ages (8-14 core) |
| Players | 50 per server |
| Languages | 日本語, English |

## Core Loop

```
Plant Seed → Water & Care → Monster Hatches → Raise & Evolve → Display in Garden
```

## Features (α版)

- 3×3 Garden Grid with planting, watering, and growth
- 20 Monster species across 5 attributes (Fire/Water/Grass/Light/Dark)
- Rarity system (Normal → Rare → Epic → Legend → Mythic)
- Dynamic weather & season system affecting spawns
- Shop skeleton (GamePass + DevProduct ready)
- DataStore persistence with offline growth
- Japanese + English localization

## Tech Stack

| Tool | Version |
|------|---------|
| Roblox Studio | Latest |
| Rojo | 7.4.4 |
| Selene | 0.27.1 |
| StyLua | 0.20.0 |
| Aftman | Latest |

## Setup

```bash
aftman install
rojo serve
# Open Roblox Studio → Connect to Rojo
```

## Project Structure

```
src/
├── server/Services/     — DataService, GardenService, MonsterService, WeatherService, ShopService
├── client/Controllers/  — UIController, GardenController, ShopController, CollectionController
├── shared/Config/       — GameConfig, MonsterDatabase, SeedDatabase, ShopPrices
└── replicated-first/    — LoadingScreen
```

## License

Proprietary — Tokio-Partner
