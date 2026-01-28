import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/finance_provider.dart';
import 'widgets/home/home_screen.dart';

void main() {
  runApp(const FinanceApp());
}

/// 本地优先记账应用
class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FinanceProvider()..loadInitial(),
      child: MaterialApp(
        title: '自由记账',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
