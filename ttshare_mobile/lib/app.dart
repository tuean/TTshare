import 'package:flutter/material.dart';
import 'pages/home_page.dart';

class TTshareApp extends StatelessWidget {
  const TTshareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTshare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
