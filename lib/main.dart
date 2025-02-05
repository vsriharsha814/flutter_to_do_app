import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:to_do_flutter_app/pages/todo_page.dart';

void main() async {
  // Init Hive for storage
  await Hive.initFlutter();

  // Open a box
  var box = await Hive.openBox('myBox');

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const TodoPage(),
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.deepPurple[600], // Set AppBar color explicitly
          foregroundColor: Colors.white, // Set text/icon color
        ),
      ),
    );
  }
}
