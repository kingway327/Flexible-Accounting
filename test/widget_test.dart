// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:local_first_finance/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const FinanceApp(
        startupConfig: StartupConfig(
          isDaytime: true,
          shouldShowSplash: false,
          markShownOnFinish: false,
        ),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
