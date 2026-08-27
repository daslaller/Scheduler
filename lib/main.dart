import 'package:flutter/material.dart';

import 'theme.dart';
import 'workbench_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NorthlineApp());
}

class NorthlineApp extends StatelessWidget {
  const NorthlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Northline Schedule',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Wb.page,
        colorScheme: const ColorScheme.light(
          primary: Wb.ink,
          onPrimary: Wb.page,
          surface: Wb.cream,
          onSurface: Wb.ink,
        ),
        fontFamily: Wb.sans,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Wb.ink,
          contentTextStyle: Wb.ui(size: 13, color: Wb.page),
        ),
      ),
      home: const WorkbenchPage(),
    );
  }
}
