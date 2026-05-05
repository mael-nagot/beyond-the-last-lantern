# Localization

Single source of truth: `strings.csv`.

All player-facing strings in the game are translation keys. Display code looks them up at render time via Godot's `tr()`. Non-English locales will be added in Phase 17.

## File format

`strings.csv` has one column per locale, with `keys` as the first (mandatory) column:

```
keys,en
item.health_potion.name,Health Potion
item.health_potion.description,Restores 30 HP.
ui.pickup_prompt,Pick up
```

Godot auto-imports the CSV and produces `strings.<locale>.translation` files alongside it. Don't hand-edit those — edit the CSV.

## Key naming convention

`domain.id.field`

Examples:
- `item.health_potion.name`
- `item.health_potion.description`
- `ui.pickup_prompt`
- `ui.button.attack`
- `quest.fetch_amulet.dialogue_intro`
- `enemy.shadow_wraith.name`
- `class.warrior.name`

Use lowercase, dot-separated, no spaces. The id segment matches the resource id when applicable (e.g. `health_potion` matches `res://assets/items/health_potion.tres`).

## Where keys live

- **Resource files (`.tres`):** any text-typed `@export` field on a content resource (`ItemData`, future `EnemyData`, `QuestData`, etc.) holds a key, not display text. Designers type keys in the Inspector and add a CSV row.
- **GDScript:** UI-side strings — labels, prompts, error popups shown to the player — are wrapped in `tr("ui.something")`. Internal log strings (`push_error`, `push_warning`, `print`) are NOT translated.

## Adding a new string

1. Pick a key following the naming convention.
2. Add a row to `strings.csv` with the key and English translation.
3. Use the key wherever it's needed (resource field or `tr()` call).
4. Re-open the project (or trigger a re-import) so Godot regenerates the `.translation` files.

## Phase 17 scope (future)

This scaffolding only defines the discipline + the English column. Phase 17 will:
- Add `fr`, `es`, `zh`, `ja`, `ko`, `de`, `it` columns
- Add a language switcher in the Options screen
- Set up font fallbacks for CJK scripts
- Test layouts with longest translations (German tends to win)
