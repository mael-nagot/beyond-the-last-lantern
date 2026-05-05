# Tests

Powered by [GUT (Godot Unit Test)](https://github.com/bitwes/Gut). Configuration lives in `res://.gutconfig.json`.

## Structure

```
tests/
├── README.md
├── unit/             ← pure-logic tests, fast, no scene-tree dependencies
└── integration/      ← scene-tree or multi-script tests, slower
```

A test is in **unit** if it can construct everything it needs in pure code (`Resource.new()`, `RefCounted`, etc.). It's in **integration** if it needs nodes added to the scene tree, signals, or coordinates more than one script.

## Conventions

- **Filename:** `test_<thing>.gd` (e.g. `test_item_instance.gd`).
- **Class:** every test file does `extends GutTest`.
- **Methods:** test methods start with `test_`. Name them after behaviors, not method names — e.g. `test_stack_count_capped_at_stack_max`, not `test_can_stack_with`.
- **One concept per test:** each `test_*` asserts one behavior. Multiple `assert_eq` calls are fine if they verify facets of the same concept; if you find yourself writing AND in the test name, split it.
- **No scene tree in `unit/`:** if a test needs `add_child`, it goes in `integration/`. Use GUT's `add_child_autofree(node)` to ensure cleanup between tests.
- **Translation keys in tests:** when asserting on display strings, prefer `tr("the.key")` so the test reflects what the runtime sees rather than hardcoding the English text. Hardcode the literal English only in tests of the translation system itself.
- **Determinism:** any test that depends on randomness (e.g. `LevelGenerator.generate()`) must seed the RNG: `seed(N)` at the top of `before_each()` or in the test itself.

## Running

**In Godot:** the **GUT** tab at the bottom of the editor. Click **Run All**, or right-click a test to run a single one.

**CLI / CI:**
```
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
```

CI runs this on every PR via `.github/workflows/test.yml`.

## What goes here

Per the project's CLAUDE.md Testing rule: every new pure-logic script gets unit tests in the same change. Bug fixes get a failing-test-first when the bug is reproducible in code (i.e. not a UI-only issue).

We do NOT test:
- Pure rendering / visual layout (the value of an automated test for "does the floor quad show up" is low; eyeball it)
- Scene file structure (covered by the manual scene-instructions in `scenes/README.md`)
- Godot engine behavior itself (we trust the engine)
