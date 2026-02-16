# AGENTS.md - local_first_finance

Guidelines for coding agents working in this Flutter/Dart repository.

## 1) Scope and Tech Stack

- Project type: Flutter app (`pubspec.yaml`) with Android/iOS/macOS/Linux/Windows targets.
- Language: Dart (SDK `>=3.3.0 <4.0.0`).
- State management: `provider` + `ChangeNotifier`.
- Persistence: `sqflite` (SQLite), local-first data model.
- Key folders: `lib/`, `test/`, `android/`, `ios/`, `macos/`, `linux/`, `windows/`.

## 2) Source of Truth for Rules

- Lint config: `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`.
- There are no custom enabled lint overrides; commented examples only.
- No `.cursorrules` found.
- No `.cursor/rules/` found.
- No `.github/copilot-instructions.md` found.

## 3) Build / Run / Analyze Commands

Run from repository root (`local_first_finance/`).

```bash
flutter pub get
flutter run
flutter analyze
dart format .
```

Useful targeted commands:

```bash
flutter analyze lib/providers/finance_provider.dart
dart format lib/main.dart
flutter clean
```

Platform builds (when needed):

```bash
flutter build apk --release
flutter build ios --release
flutter build windows --release
```

## 4) Test Commands (including single-test)

```bash
flutter test
flutter test test/widget_test.dart
flutter test test/widget_test.dart --plain-name "App builds"
flutter test --coverage
flutter test -r expanded
```

Notes:
- Prefer running the most local test scope first (single file or single case).
- Current test suite is minimal; avoid assuming broad coverage.

## 5) Import and File Organization

Follow observed import grouping pattern:
1. Dart SDK imports
2. Flutter imports
3. Third-party package imports
4. Project imports (relative paths are common)

Example pattern:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../models/models.dart';
```

Keep one blank line between groups.

## 6) Naming Conventions

- Classes/enums: `PascalCase` (`TransactionRecord`, `FinanceProvider`).
- Methods/variables/params: `camelCase`.
- Private members/types: leading underscore (`_records`, `_StartupHost`).
- File names: `snake_case.dart`.
- Top-level constants: `kCamelCase` (`kLightBlue`, `kWechatTransactionTypes`).

## 7) Types and Data Modeling

- Avoid implicit dynamic for model fields; use explicit types.
- Use nullable types intentionally (`String?`, `int?`).
- Prefer `final` unless mutation is required.
- For DB maps, use `Map<String, Object?>`.
- Encode money in integer cents, not floating currency.
- Store time as epoch milliseconds (`int`).

## 8) State Management and UI Patterns

- App-wide state lives in provider classes extending `ChangeNotifier`.
- Trigger updates via `notifyListeners()` after state changes.
- Access providers via `context.read<T>()`, `context.watch<T>()`, or `Consumer<T>`.
- Prefer `const` widgets/constructors wherever possible.
- Use `StatefulWidget` only when local mutable UI state is needed.

## 9) Database and Service Patterns

- `DatabaseHelper` is a singleton (`DatabaseHelper._()` + `instance`).
- DB/service methods are asynchronous and return typed results.
- Use batch operations for multi-row writes when possible.
- Keep conversion boundaries explicit (`toMap`/`fromMap`).

## 10) Error Handling Expectations

- Wrap I/O and DB calls in `try/catch`.
- In user-facing flows, graceful failure with UI feedback is preferred.
- Silent catches exist in current code; do not add noisy logging by default.
- Do not throw from widget build paths.

When adding new error handling:
- Preserve app responsiveness first.
- Return safe defaults when behavior already follows that pattern.
- Log only where the surrounding code already logs.

## 11) Formatting and Style

- Use `dart format` output as canonical formatting.
- 2-space indentation.
- Trailing commas in multiline widget/argument lists.
- Keep methods focused and cohesive; avoid unrelated refactors in bug fixes.

## 12) Testing Guidance for Agents

- Add/adjust widget tests when changing UI behavior.
- Keep test names behavior-focused.
- Use `pumpWidget`, finders, and explicit expectations.
- For fixes, prefer adding a narrow regression test when practical.

## 13) Files Agents Should Treat Carefully

- Generated/ephemeral Flutter files (for example under `windows/flutter/ephemeral/`) should not be hand-edited.
- Platform build files (`android/`, `ios/`, `macos/`, `windows/`, `linux/`) should be touched only when task-relevant.
- `lib/main.dart.backup` exists; do not treat it as primary source unless task explicitly references it.

## 14) Practical Workflow for Agentic Edits

1. Read `analysis_options.yaml`, `pubspec.yaml`, and nearby feature files first.
2. Make minimal, surgical changes aligned with existing patterns.
3. Run `dart format` on changed files.
4. Run `flutter analyze`.
5. Run the narrowest relevant tests, then broader tests as needed.

This document is evidence-based from the current repository state and should be updated when tooling or conventions change.
