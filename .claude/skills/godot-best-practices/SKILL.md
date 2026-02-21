---
name: godot-best-practices
description: Godot Engine best practices for scene organization, maintainable GDScript code, and modular architecture. Use when organizing node hierarchies, structuring game code, implementing signals for communication, or establishing coding conventions in Godot projects.
---

# Godot Engine Best Practices

Modular architecture and maintainable GDScript for game development.

## When to Apply

- Structuring scene hierarchies and node organization
- Writing maintainable GDScript with proper conventions
- Implementing signal-based communication patterns
- Organizing reusable components and packed scenes

## Critical Rules

**Use queue_free() for safe node removal**

```gdscript
// WRONG - immediate deletion can cause errors
func destroy_enemy():
    enemy.free()

// RIGHT - deferred deletion at end of frame
func destroy_enemy():
    enemy.queue_free()
```

**Always type hint for performance and safety**

```gdscript
// WRONG - untyped variables bypass optimizations
var health = 100
var enemy = preload("res://Enemy.tscn").instantiate()

// RIGHT - typed variables enable compiler optimizations
var health: int = 100
var enemy: CharacterBody2D = preload("res://Enemy.tscn").instantiate()
```

**Use groups for batch operations, not individual node references**

```gdscript
// WRONG - storing individual node references
var all_enemies: Array[Node] = []

// RIGHT - use groups for scalable node management
func _ready():
    add_to_group("enemies")

func damage_all_enemies():
    get_tree().call_group("enemies", "take_damage", 10)
```

## Key Patterns

### Scene Composition

```gdscript
extends Node2D

@onready var health_component: Node = $HealthComponent
@onready var movement_component: Node = $MovementComponent

func _ready():
    # Connect component signals
    health_component.died.connect(_on_died)
    movement_component.position_changed.connect(_on_position_changed)
```

### Signal-Based Communication

```gdscript
extends Node

signal health_changed(new_health: int, max_health: int)
signal died

@export var max_health: int = 100
var current_health: int

func _ready():
    current_health = max_health

func take_damage(amount: int):
    current_health = max(0, current_health - amount)
    health_changed.emit(current_health, max_health)
    
    if current_health == 0:
        died.emit()
```

### Dynamic Scene Management

```gdscript
extends Node

const EnemyScene = preload("res://characters/Enemy.tscn")

func spawn_enemy(spawn_position: Vector2):
    var enemy: CharacterBody2D = EnemyScene.instantiate()
    add_child(enemy)
    enemy.global_position = spawn_position
    enemy.add_to_group("enemies")
```

### Node Access Patterns

```gdscript
extends Node

# Cache node references in _ready
@onready var player: CharacterBody2D = $Player
@onready var ui_manager: Control = $UIManager
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

# Use get_node() for conditional access
func find_player() -> CharacterBody2D:
    var player_node = get_tree().get_first_node_in_group("player")
    return player_node as CharacterBody2D
```

## Common Mistakes

- **Accessing nodes before _ready()** — Use @onready or check is_inside_tree()
- **Not using type hints** — Reduces performance and breaks static analysis
- **Storing hard references to nodes** — Use groups or weak references instead
- **Calling free() instead of queue_free()** — Can cause access-after-free errors
- **Connecting signals without proper cleanup** — Disconnect in _exit_tree() if needed