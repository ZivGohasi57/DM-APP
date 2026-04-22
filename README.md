# DM Battle Tracker — macOS D&D 5e DM Tool

[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue.svg)](https://developer.apple.com/swiftui/)
[![SwiftData](https://img.shields.io/badge/Persistence-SwiftData-purple.svg)](https://developer.apple.com/xcode/swiftdata/)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![License: Personal](https://img.shields.io/badge/License-Personal-green.svg)](#license)

A native **macOS application** built for Dungeon Masters running D&D 5e campaigns.
Designed as a complete session toolkit — from pre-session prep (encounters, shops, world-building) to live combat tracking.

---

## 🧠 Core Features

### ⚔️ Combat Engine
* **Initiative Tracker**: Roll initiative per-session via a dedicated sheet; initiative is never stored permanently.
* **Live HP Management**: Cumulative delta input (type `-15` to subtract); damage hits Temp HP first, then main HP.
* **First Striker**: A combatant can act first in Round 1 — their normal slot is automatically skipped.
* **Conditions**: Full D&D 5e condition tracking per combatant with visual badges.
* **Monster & NPC Templates**: Reusable stat blocks with damage immunities, resistances, vulnerabilities, and save proficiencies.

### 🧙 Player Character Library
* Full PC profiles: HP, AC, speed variants (fly/swim/climb/burrow), passive scores, darkvision, size.
* **Resources**: Spell slots, Ki points, and custom resource pools tracked per combat.
* **Inventory**: Per-character item tracking linked to the catalog.
* **Wishlist**: Players can wishlist catalog items with priority and notes.

### 🗺️ World & Campaign Management
* **Countries → Cities** hierarchy with custom map images and city symbols.
* **Interactive City Maps**: Place story pins and shop pins directly on city maps.
* **Stories / Quest Log**: Main and side quest tracking with NPC links, encounter links, item rewards, and prerequisites.
* **World Map**: Full campaign world map with image upload.

### 🏪 Shops & Economy
* **Three shop types**: Weapons & Armor, Apothecary, Library (Scrolls).
* **Quality Tiers**: Low / Medium / High — controls weighted rarity distribution for generated inventory.
* **Randomize Inventory**: One-click shop generation using DMG pricing rules with consumable halving.
* **Sell Flow**: Sell catalog items to shops with auto-suggested pricing (including spell scroll pricing by level).
* **Gold Ledger**: Track starting gold and total earnings per shop.

### 📖 Catalog
* **4 item types**: Weapons, Armor, Magic Items, Spells — loaded from bundled JSON exports.
* **500+ items** including full spell data (components, material, higher-level, concentration, ritual).
* **Custom Items**: Create campaign-specific items with full stat editing.
* **Hide Items**: Remove catalog entries per-installation via UserDefaults (non-destructive).
* **Detail View**: Stat boxes, rarity badge, source badge, material component card, formatted description.

### 🖼️ Gallery
* Image gallery organized in folders with presentation mode (full-screen slideshow for players).
* Built-in folders + custom folders per campaign.

### 📊 XP Index & Bestiary
* XP thresholds by party level for quick encounter difficulty reference.
* Monster bestiary for on-the-fly lookups.

### 💾 Campaign Export / Import
* Full campaign bundle export to a single `.json` file.
* Import remaps all UUIDs to avoid conflicts — safe to import multiple times.
* Includes: players, NPCs, monsters, encounters, world data, stories, shops (with inventory + quality), custom catalog items, wishlists, gallery.

---

## 🛠 Tech Stack

* **Language**: Swift 5.9
* **UI Framework**: SwiftUI (declarative, AppKit bridge where needed)
* **Persistence**: SwiftData (`@Model` classes, CloudKit-free local store)
* **Project Generation**: XcodeGen (`project.yml`)
* **Data**: Bundled JSON catalogs (spells, weapons, armor, magic items)
* **Platform**: macOS 14 Sonoma+

---

## 📁 Project Structure

```text
DM-APP/
├── DMBattleTracker/
│   ├── Models/             # SwiftData @Model classes (Campaign, PlayerCharacter, Shop, …)
│   ├── Services/           # CatalogService, CampaignExportImport
│   ├── Views/
│   │   ├── ActiveCombat/   # Live combat tracker
│   │   ├── PCLibrary/      # Player character management
│   │   ├── Bestiary/       # Monster stat blocks
│   │   ├── EncounterBuilder/
│   │   ├── Stories/        # Quest log
│   │   ├── World/          # Countries, cities, map pins
│   │   ├── Shops/          # Shop management & inventory
│   │   ├── Catalog/        # Item browser
│   │   ├── Gallery/        # Image gallery & presentation
│   │   ├── XPIndex/        # XP threshold reference
│   │   └── Shared/         # CatalogBrowserView, CatalogItemBody, reusable components
│   ├── Assets.xcassets/    # App icon + assets
│   └── *.json              # Bundled catalog data (spells, weapons, armor, magic items)
├── project.yml             # XcodeGen project definition
└── README.md
```

---

## 🏗️ Architecture Notes

* **`@Model` (SwiftData)**: `PlayerCharacter`, `MonsterTemplate`, `NPCTemplate`, `SavedEncounter`, `Shop`, `Story`, `City`, `Country`, `GalleryImage`, …
* **`@Observable` (in-combat only)**: `Combatant` is a transient runtime copy — never persisted. `CombatEngine` orchestrates round/turn logic.
* **`CatalogService`**: `@MainActor` singleton, loads all JSON catalogs once on launch. Hidden items are stored in `UserDefaults` (slug-based).
* **`ShopRandomizer`**: Weighted rarity selection → DMG price generation → consumable halving rule.
* **`CampaignExportImport`**: UUID remapping on import ensures no collisions between campaigns.

---

## 🗺️ Roadmap

- [x] Initiative tracker with First Striker support
- [x] Full PC resource management (spell slots, ki, custom pools)
- [x] Monster / NPC template library
- [x] World map + city maps with interactive pins
- [x] Quest / story log with prerequisites and rewards
- [x] Shop system with randomized inventory generation
- [x] D&D 5e item catalog (500+ weapons, armor, spells, magic items)
- [x] Custom catalog items per campaign
- [x] Campaign export / import (full bundle)
- [x] Gallery with presentation mode
- [ ] Combat log / damage history
- [ ] Encounter difficulty calculator (XP budget)
- [ ] Player-facing display window (initiative order + current HP)

---

## ⚙️ Development Setup

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate the Xcode project
cd DM-APP
xcodegen generate

# Open in Xcode
open DMBattleTracker.xcodeproj
```

> **Schema reset**: If SwiftData model changes cause a crash on launch, delete:
> `~/Library/Application Support/com.dmbattletracker.app/`

---

## 📄 License

**Personal Initiative Project**

Copyright © 2025 Ziv Gohasi.
