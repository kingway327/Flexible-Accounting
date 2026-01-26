# AGENTS.md - Local First Finance App

> Guidelines for AI agents working on this Flutter codebase.

## Project Overview

A local-first personal finance app for importing and analyzing WeChat Pay and Alipay transaction records from CSV/Excel files. Built with Flutter, using SQLite for local persistence and Provider for state management.

## Build & Run Commands

```bash
# Navigate to project directory
cd local_first_finance

# Get dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Build release APK
flutter build apk --release

# Build iOS (requires macOS)
flutter build ios --release
```

## Lint & Analyze

```bash
# Run static analysis (uses flutter_lints/flutter.yaml)
flutter analyze

# Run analysis with specific file
flutter analyze lib/pages/analysis_page.dart

# Format code
dart format .

# Format specific file
dart format lib/main.dart
```

## Test Commands

```bash
# Run all tests
flutter test

# Run single test file
flutter test test/widget_test.dart

# Run specific test by name
flutter test --name "App builds"

# Run tests with coverage
flutter test --coverage

# Run tests in verbose mode
flutter test -v
```

## Project Structure

```
lib/
├── main.dart                    # App entry, FinanceProvider, HomeScreen
├── models/
│   └── models.dart              # TransactionRecord, CustomCategory, TransactionType
├── data/
│   ├── database_helper.dart     # SQLite operations (singleton pattern)
│   ├── parsers.dart             # WeChat/Alipay CSV/Excel parsers
│   ├── analysis_helpers.dart    # Data aggregation (weekly/monthly/yearly)
│   └── export_service.dart      # CSV export functionality
├── widgets/
│   └── month_picker.dart        # Reusable month/year picker component
└── pages/
    ├── analysis_page.dart       # Analysis dashboard with tabs
    ├── transaction_detail_page.dart
    └── category_manage_page.dart
```

## Code Style Guidelines

### Imports

Order imports in this sequence:
1. Dart SDK (`dart:async`, `dart:convert`, etc.)
2. Flutter SDK (`package:flutter/material.dart`)
3. External packages (alphabetically)
4. Project imports (relative paths preferred)

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../models/models.dart';
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `TransactionRecord`, `DatabaseHelper` |
| Variables/Functions | camelCase | `_selectedYear`, `fetchTransactions()` |
| Constants | kCamelCase or SCREAMING_SNAKE | `kCategoryColors`, `kLightBlue` |
| Private members | Leading underscore | `_db`, `_loading`, `_loadData()` |
| Files | snake_case | `database_helper.dart`, `analysis_page.dart` |

### Widget Patterns

- Use `const` constructors wherever possible
- Private widgets use underscore prefix: `_FilterChip`, `_TransactionTile`
- Prefer `StatelessWidget` unless state is needed
- Named parameters with `required` keyword

```dart
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  // ...
}
```

### State Management

- Use `Provider` + `ChangeNotifier` for app-wide state
- Local widget state uses `StatefulWidget`
- Access provider with `Consumer<T>` or `context.read<T>()`

### Database Patterns

- `DatabaseHelper` uses singleton pattern
- All DB methods are async
- Money stored as integers (cents): `amount * 100`
- Timestamps as milliseconds since epoch

### Error Handling

- Use `try-catch` for async operations
- Empty catch blocks acceptable for user-facing operations (silently fail)
- Never throw in UI code - handle gracefully

```dart
try {
  final content = await decodeCsvBytes(bytes);
  // process...
} catch (_) {
  _setLoading(false);
  // Silently fail or show snackbar
}
```

### Type Safety

- Always specify types for class fields
- Use `Object?` for nullable Map values: `Map<String, Object?>`
- Prefer `final` for immutable fields
- Use enums for fixed sets: `TransactionType`, `SourceFilter`

### Formatting

- 2-space indentation (Dart default)
- Max line length: 80-100 characters
- Trailing commas for multi-line parameter lists
- Single blank line between methods

### Color Constants

Define colors as package-level constants:

```dart
const Color kLightBlue = Color(0xFF90CAF9);
const Color kDarkBlue = Color(0xFF1976D2);
const Color kTodayBg = Color(0xFFE3F2FD);
```

### Documentation

- Use `///` for public API documentation
- Simple `//` for implementation notes
- Document complex business logic

## Key Dependencies

| Package | Purpose |
|---------|---------|
| provider | State management |
| sqflite | SQLite database |
| file_picker | File selection |
| csv | CSV parsing |
| excel | Excel file parsing |
| charset_converter | GBK encoding support |
| intl | Date/number formatting |
| fl_chart | Charts and graphs |
| share_plus | Share functionality |

## Testing Guidelines

- Widget tests use `flutter_test` package
- Use `WidgetTester` for interaction tests
- Test files mirror lib structure: `lib/foo.dart` -> `test/foo_test.dart`

```dart
testWidgets('description', (WidgetTester tester) async {
  await tester.pumpWidget(const MyWidget());
  expect(find.byType(SomeWidget), findsOneWidget);
});
```

## Common Patterns

### Singleton Services

```dart
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
}
```

### Model Serialization

```dart
Map<String, Object?> toMap() { /* ... */ }
static MyModel fromMap(Map<String, Object?> map) { /* ... */ }
```

### Currency Formatting

```dart
final formatter = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
String formatted = formatter.format(cents / 100);
```

## Environment

- Dart SDK: >=3.3.0 <4.0.0
- Flutter: Latest stable
- Linting: `flutter_lints` package (recommended rules)
