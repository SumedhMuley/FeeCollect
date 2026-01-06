import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FeeCollectApp());
}

class FeeCollectApp extends StatelessWidget {
  const FeeCollectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FeeCollect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
