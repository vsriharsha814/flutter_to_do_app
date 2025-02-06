import 'package:hive_flutter/hive_flutter.dart';

class TodoDatabase {
  List toDoList = [];
  // Reference the box
  final _myBox = Hive.box('myBox');

  // Initial data
  void createInitialData() {
    toDoList = [
      ["Make Tutorial", false, DateTime.now().add(Duration(days: 1))],  // With due date
      ["Do Exercise", false, null],  // Without due date
    ];
  }

  // Load data from Hive
  void loadData() {
    final data = _myBox.get("TODOLIST");

    if (data != null) {
      toDoList = data.map((task) {
        return [
          task[0],  // Task Name
          task[1],  // Is Completed
          task[2] != null ? DateTime.tryParse(task[2]) : null,  // Parse date if it exists, else null
        ];
      }).toList();
    }
  }

  // Save data to Hive
  void updateDatabase() {
    final dataToStore = toDoList.map((task) {
      return [
        task[0],  // Task Name
        task[1],  // Is Completed
        task[2]?.toIso8601String(),  // Convert date to string if exists, else null
      ];
    }).toList();

    _myBox.put("TODOLIST", dataToStore);
  }
}