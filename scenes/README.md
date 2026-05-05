# Below the Last Lantern — Scene Structure Reference

> **⚠️ IMPORTANT: DO NOT edit scene files (.tscn) programmatically or through an AI assistant.**
> Always let the human developer manually create, modify, and restructure scenes in the Godot editor.
> When changes are needed, provide clear step-by-step instructions for the developer to follow in the editor.
> Scene files contain serialized binary references, node paths, and resource links that are fragile and easily broken by text editing.

---

## Scene File Locations

```
res://scenes/
├── Game.tscn              ← main game scene (run with F5)
├── DungeonView.tscn       ← 3D dungeon rendering
└── hud/
    ├── HUD.tscn           ← master HUD container
    ├── TopBar.tscn         ← settings + map buttons
    ├── ItemBar.tscn        ← 10-slot inventory bar
    ├── PartyPanel.tscn     ← party character display
    ├── CharacterSlot.tscn  ← single character (instanced 3× in PartyPanel)
    ├── MovementPad.tscn    ← 6 directional movement buttons
    └── MapPopup.tscn       ← full-screen map overlay
```

---

## Game.tscn — Main Scene

**Root node:** `Game` (Node3D)
**Script:** `Game.gd`
**Set as main scene** in Project → Project Settings → Application → Run → Main Scene

```
Game                          (Node3D, Game.gd)
├── DungeonView               (instanced from DungeonView.tscn)
└── HUD                       (instanced from HUD.tscn)
```

**How to add children:**
- Select `Game` → click chain link icon (Ctrl+Shift+A) → pick the .tscn file
- Both `DungeonView` and `HUD` must show the chain link icon (instanced scene)

---

## DungeonView.tscn — 3D Dungeon

**Root node:** `DungeonView` (Node3D)
**Script:** `DungeonView.gd`

```
DungeonView                   (Node3D, DungeonView.gd)
├── SubViewportContainer      (SubViewportContainer, Stretch = true)
│   └── SubViewport           (SubViewport)
│       ├── Camera            (Camera3D, FOV = 100, Current = true)
│       ├── DungeonRoot       (Node3D — holds generated wall/floor/ceiling quads)
│       └── WorldEnvironment  (WorldEnvironment — must have Environment resource assigned)
└── PlayerController          (Node, PlayerController.gd)
```

**Key settings to verify:**
- `SubViewportContainer`: Stretch must be `true`
- `Camera`: Current must be `true`, FOV set to your preferred value
- `WorldEnvironment`: must have a `New Environment` resource assigned (click the field → New Environment)
- `PlayerController` stays OUTSIDE the SubViewport — it doesn't render anything

**If the screen is black:** check that WorldEnvironment has an Environment resource and Camera has Current = true.

---

## HUD.tscn — Master HUD

**Root node:** `HUD` (CanvasLayer, Layer = 1)
**Script:** `HUD.gd`

```
HUD                           (CanvasLayer, Layer = 1, HUD.gd)
└── HUDRoot                   (Control, Layout = Full Rect, Mouse Filter = Pass)
    ├── TopBar                (instanced from TopBar.tscn)
    ├── PartyPanel            (instanced from PartyPanel.tscn)
    ├── ItemBar               (instanced from ItemBar.tscn)
    ├── MovementPad           (instanced from MovementPad.tscn)
    └── MapPopup              (instanced from MapPopup.tscn)
```

**Critical:** `HUDRoot` must be a plain `Control` (not VBoxContainer, HBoxContainer, etc.) — the layout is handled entirely by `HUD.gd` code. If HUDRoot is a container type, it will override child positions.

---

## TopBar.tscn — Settings & Map Buttons

**Root node:** `TopBar` (HBoxContainer)
**Script:** none (signals connected from HUD.gd)

```
TopBar                        (HBoxContainer)
├── BtnSettings               (Button, text = "⚙")
├── BtnMap                    (Button, text = "🗺")
└── Spacer                    (Control, Size Flags Horizontal = Expand Fill)
```

---

## CharacterSlot.tscn — Single Character Display

**Root node:** `CharacterSlot` (BoxContainer)
**Script:** `CharacterSlot.gd`

```
CharacterSlot                 (BoxContainer, CharacterSlot.gd)
├── LeftSide                  (VBoxContainer)
│   ├── PortraitFrame         (Panel, 68×68)
│   │   └── Portrait          (TextureButton, 64×64)
│   ├── HPBar                 (ProgressBar)
│   ├── MPBar                 (ProgressBar)
│   └── NameLabel             (Label)
└── ActionButtons             (VBoxContainer)
    ├── BtnAttack             (Button, text = "⚔")
    ├── BtnSpell              (Button, text = "✦")
    └── BtnDefense            (Button, text = "🛡")
```

---

## PartyPanel.tscn — Party Display (3 Characters)

**Root node:** `PartyPanel` (HBoxContainer)
**Script:** `PartyPanel.gd`

```
PartyPanel                    (HBoxContainer, PartyPanel.gd)
├── Slot0                     (instanced from CharacterSlot.tscn)
├── Slot1                     (instanced from CharacterSlot.tscn)
└── Slot2                     (instanced from CharacterSlot.tscn)
```

**How to add character slots:** select PartyPanel → chain link icon → pick CharacterSlot.tscn → name it Slot0, Slot1, Slot2.

---

## ItemBar.tscn — Inventory Slots

**Root node:** `ItemBar` (Container — NOT HBoxContainer)
**Script:** `ItemBar.gd`

```
ItemBar                       (Container, ItemBar.gd)
```

**No children in the scene** — all 10 slot panels are created programmatically in `_ready()`. The node type MUST be `Container`, not `HBoxContainer`, because ItemBar manually positions its children in a grid layout.

---

## MovementPad.tscn — Directional Buttons

**Root node:** `MovementPad` (GridContainer, columns = 3)
**Script:** `MovementPad.gd`

```
MovementPad                   (GridContainer, columns = 3, MovementPad.gd)
├── BtnTurnLeft               (Button, text = "↰")
├── BtnForward                (Button, text = "▲")
├── BtnTurnRight              (Button, text = "↱")
├── BtnStrafeLeft             (Button, text = "◀")
├── BtnBackward               (Button, text = "▼")
└── BtnStrafeRight            (Button, text = "▶")
```

**The order of children matters** — GridContainer fills left-to-right, top-to-bottom. The 6 buttons must be in this exact order to form the correct 2×3 grid.

---

## MapPopup.tscn — Full Screen Map

**Root node:** `MapPopup` (Control)
**Script:** `MapPopup.gd`

```
MapPopup                      (Control, MapPopup.gd)
├── Background                (ColorRect — yellowish parchment color)
├── CloseButton               (Button, text = "✕")
└── MapDrawArea               (Control — the map is drawn here via _draw())
```

**MapDrawArea** must be a plain `Control` — MapPopup.gd connects to its `draw` signal and uses `draw_line`, `draw_rect`, `draw_colored_polygon` to render the map.

---

## Common Issues & Solutions

**"Node not found" errors:**
- Check that the node name in the scene tree matches the `$NodeName` path exactly (case-sensitive, no trailing spaces)
- Check that the script is attached to the correct node (not a sibling or parent)
- Check that instanced scenes have the chain link icon — if not, delete and re-instance with Ctrl+Shift+A

**"null instance" errors:**
- Usually means `@onready` vars failed to resolve — check node paths
- Or the node was added as "Add Child Node" instead of "Instance Child Scene"

**Type mismatch errors:**
- The node type in the scene must match what the script extends (e.g., ItemBar must be `Container`, not `HBoxContainer`)
- To fix: right-click node → Change Type → select correct type
