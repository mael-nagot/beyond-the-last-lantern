# Object Sounds

`interact_sound` for `ObjectData` — fires when an object is first triggered (chest open, door open, lever flipped, …).

## Naming Convention

```
[category]_[id]_[event].ogg

Examples:
chest_wooden_open.ogg
chest_iron_open.ogg
door_wooden_open.ogg    (future)
lever_flip.ogg          (future)
```

## Format

`.ogg`, ~0.3–0.8 seconds. Loop = false in import settings.

## Reuse across objects

Like items, sounds can be referenced by multiple `ObjectData` `.tres` files. Two iron chests of different sizes can share one `chest_iron_open.ogg`; only the visuals differ.
