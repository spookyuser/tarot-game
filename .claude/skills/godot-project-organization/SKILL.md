---
name: godot-project-organization
description: File and folder organization patterns for Godot Engine projects. Use when restructuring existing projects, establishing folder hierarchies, or implementing naming conventions for scripts, scenes, and assets in small indie games.
---

# Godot Project Organization

Systematic file structure for maintainable Godot projects.

## When to Apply

- Restructuring existing project with disorganized files
- Setting up folder hierarchy for better asset management
- Establishing naming conventions across team members

## Critical Rules

**Consistent Case Sensitivity**: Use same casing across platforms

```
// WRONG - Mixed casing causes cross-platform issues
res://Scenes/Player.tscn
res://scripts/player.gd

// RIGHT - Consistent snake_case
res://scenes/player.tscn
res://scripts/player.gd
```

**Logical Grouping**: Top-level folders by asset type, subfolders by feature

```
// WRONG - Everything mixed together
res://Player.tscn
res://player_texture.png
res://EnemyAI.gd
res://level1.tscn

// RIGHT - Grouped by type and feature
res://scenes/player/player.tscn
res://scripts/player/player.gd
res://assets/textures/player/player_texture.png
res://scenes/levels/level1.tscn
```

## Standard Folder Structure

```
res://
├── scenes/
│   ├── player/
│   ├── enemies/
│   ├── levels/
│   └── ui/
├── scripts/
│   ├── player/
│   ├── enemies/
│   └── systems/
├── assets/
│   ├── textures/
│   ├── sounds/
│   ├── models/
│   └── fonts/
└── plugins/
```

## Naming Conventions

### Files and Folders
- Use `snake_case` for all files and folders
- Scene files: descriptive names (`main_menu.tscn`, `player_character.tscn`)
- Script files: match scene names (`player_character.gd`)

### Node Names in Scenes
- Use `PascalCase` for node names
- Descriptive hierarchy (`Player/Body/CollisionShape2D`)

## Refactoring Existing Projects

### Safe File Moving Process

1. **Create new folder structure** while keeping original files
2. **Copy files** to new locations (don't move immediately)
3. **Update scene references** in Godot editor
4. **Test thoroughly** before deleting old files
5. **Commit changes** to version control

### Reference Updates

When moving scenes, Godot automatically updates:
- Scene instantiation paths
- Resource preload paths
- Export variable assignments

Manual updates needed for:
- String-based scene changes (`change_scene_to_file()`)
- Dynamic resource loading (`load()`)

## Common Mistakes

- **Mixed casing** — Causes issues when collaborating across Windows/Linux/Mac
- **Deep nesting** — Avoid more than 3-4 folder levels for small projects  
- **Generic names** — Use `player_idle.png` not `sprite1.png`
- **Moving files externally** — Always move files within Godot editor to preserve references