# AGENTS.md - local_first_finance
Operational guide for coding agents in this repository.

## 1) Project Scope
- App type: Flutter local-first finance app.
- Language: Dart (`>=3.3.0 <4.0.0`).
- State: `provider` + `ChangeNotifier`.
- Storage: SQLite via `sqflite`.
- Core folders: `lib/`, `test/`, `assets/`, platform folders.

## 2) Rule Sources
- Lint config is `analysis_options.yaml`.
- Lint base is `package:flutter_lints/flutter.yaml`.
- No active custom lint overrides (commented examples only).
- Cursor rules: no `.cursorrules`, no `.cursor/rules/`.
- Copilot rules: no `.github/copilot-instructions.md`.

## 3) Standard Commands
Run commands from repo root (`local_first_finance/`).

### Setup / Run
```bash
flutter pub get
flutter run
flutter clean
```

### Lint / Format
```bash
flutter analyze
flutter analyze lib/providers/finance_provider.dart
dart format .
dart format lib/pages/analysis_page.dart
```

### Tests
```bash
flutter test
flutter test test/widget_test.dart
flutter test test/models_test.dart
flutter test test/widget_test.dart --plain-name "App builds"
flutter test --coverage
flutter test -r expanded
```

### Build Examples
```bash
flutter build apk --release
flutter build ios --release
flutter build windows --release
```

## 4) Single-Test Guidance (Important)
- For focused changes, run one test file first.
- For one test case, use `--plain-name "<name>"`.
- Before handoff, run at least relevant files; prefer full `flutter test` when feasible.

## 5) Data-Layer Architecture
- Keep DB initialization/migrations in `DatabaseHelper`.
- Use DAOs for feature data access:
  - `TransactionDao`
  - `CategoryDao`
  - `AppSettingsDao`
- All DAOs must use `DatabaseHelper.instance.database` (single connection source).
- Do not create parallel DB helpers or extra DB files unless explicitly requested.

## 6) Import Organization
Use import groups in this order with one blank line between groups:
1. Dart SDK imports
2. Flutter imports
3. Third-party packages
4. Project imports (relative imports are common here)

Example:
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/transaction_dao.dart';
import '../models/models.dart';
```

## 7) Formatting Rules
- Canonical formatter: `dart format`.
- Indentation: 2 spaces.
- Prefer trailing commas in multiline widget/argument lists.
- Prefer `const` constructors/widgets where possible.
- Keep changes minimal and cohesive; avoid unrelated refactors in bugfix tasks.

## 8) Naming Conventions
- Types (classes/enums): `PascalCase`.
- Methods/fields/params: `camelCase`.
- Private symbols: leading underscore (`_name`).
- File names: `snake_case.dart`.
- Top-level constants: `kCamelCase`.
- Private static constants in classes: `_kCamelCase`.

## 9) Types and Domain Modeling
- Prefer explicit types for model and DAO interfaces.
- Use nullability intentionally and validate boundaries.
- DB map payloads should use `Map<String, Object?>`.
- Money is integer cents (`int`), never floating amount storage.
- Time is epoch milliseconds (`int`).

## 10) State Management
- App-level mutable state belongs in providers (`ChangeNotifier`).
- Call `notifyListeners()` after meaningful state updates.
- Use `context.read/watch` or `Consumer` patterns.
- Keep expensive I/O out of widget `build()`.

## 11) Async and Error Handling
- Wrap I/O and DB operations in `try/catch`.
- Keep user-facing failures graceful (existing snackbar/safe fallback patterns).
- Avoid noisy logging where current code is intentionally quiet.
- If logging is needed, use concise `debugPrint` style.
- Never throw from `build()` methods.

## 12) DAO and DB Behavior Safety
- Keep method signatures stable during refactors unless requested.
- Preserve cross-table sync semantics (custom category/filter/group behavior).
- Preserve app-settings keys and compatibility behavior unless migration is explicit.
- Prefer batch operations for bulk inserts/updates.

## 13) UI/Widget Guidelines
- Extract reusable components instead of deep inline widget trees.
- Keep callback types explicit (`ValueChanged<T>`, `VoidCallback`).
- Keep transitions/animations predictable and testable.
- Add narrow regression tests for UI behavior changes when practical.

## 14) Verification Checklist
Before final handoff:
1. Run `dart format` on changed files.
2. Run `flutter analyze`.
3. Run narrow relevant tests first.
4. Run `flutter test` when feasible.
5. Summarize what changed and how to verify.

## 15) Files to Treat Carefully
- Do not hand-edit generated files (for example `windows/flutter/ephemeral/`).
- Modify platform folders only when task requires platform-level changes.
- `lib/main.dart.backup` is not primary source unless explicitly requested.
- Migration logic in `DatabaseHelper` should be edited cautiously and verified.

Keep this document updated when architecture, tooling, or repository rules change.
