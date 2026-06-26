import 'package:flutter/material.dart';
import 'pages/home_page.dart';

class TTshareDesktopApp extends StatelessWidget {
  const TTshareDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTshare Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
