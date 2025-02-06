import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:to_do_flutter_app/data/database.dart';
import 'package:to_do_flutter_app/util/alert_dialog_box.dart';
import 'package:to_do_flutter_app/util/todo_tile.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  // Hive database reference
  final _myBox = Hive.box('myBox');
  TodoDatabase db = TodoDatabase();

  // Local Notifications Plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Search and filter state variables
  String searchQuery = "";
  String filterStatus = "All";
  bool isSearchActive = false;  // Controls whether the search bar is visible

  @override
  void initState() {
    super.initState();

    if (_myBox.get("TODOLIST") == null) {
      db.createInitialData();
    } else {
      db.loadData();
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    tz.initializeTimeZones();
  }

  final _controller = TextEditingController();
  DateTime? selectedDueDate;

  void checkBoxChanged(bool? value, int index) {
    setState(() {
      db.toDoList[index][1] = !db.toDoList[index][1];
    });
    db.updateDatabase();
  }

  void saveNewTask() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        db.toDoList.add([_controller.text, false, selectedDueDate]);
        _controller.clear();
      });

      if (selectedDueDate != null) {
        scheduleNotification(_controller.text, selectedDueDate!);
      }

      Navigator.of(context).pop();
      db.updateDatabase();
      selectedDueDate = null;
    }
  }

  void cancelTask() {
    Navigator.of(context).pop();
    setState(() {
      _controller.clear();
      selectedDueDate = null;
    });
  }

  void createNewTask() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialogBox(
          controller: _controller,
          onSave: saveNewTask,
          onCancel: cancelTask,
          onDateSelected: (date) {
            selectedDueDate = date;
          },
        );
      },
    );
  }

  void deleteTask(int index) {
    if (db.toDoList[index][2] != null) {
      cancelNotification(db.toDoList[index][2]);
    }

    setState(() {
      db.toDoList.removeAt(index);
    });
    db.updateDatabase();
  }

  Future<void> scheduleNotification(String taskName, DateTime dueDate) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      dueDate.millisecondsSinceEpoch ~/ 1000,
      'Task Reminder',
      taskName,
      tz.TZDateTime.from(dueDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel',
          'Task Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> cancelNotification(DateTime dueDate) async {
    await flutterLocalNotificationsPlugin.cancel(dueDate.millisecondsSinceEpoch ~/ 1000);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = db.toDoList.where((task) {
      final taskName = task[0].toString().toLowerCase();
      final isCompleted = task[1] as bool;

      final matchesSearch = searchQuery.isEmpty || taskName.contains(searchQuery);
      final matchesStatus = filterStatus == "All" ||
          (filterStatus == "Completed" && isCompleted) ||
          (filterStatus == "Uncompleted" && !isCompleted);

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.deepPurple[100],
      appBar: AppBar(
        title: isSearchActive
            ? TextField(
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: Colors.white, fontSize: 18),
              )
            : const Text(
                'SwiftList',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Montserrat",
                ),
              ),
        actions: [
          // Search Icon
          IconButton(
            icon: Icon(
              isSearchActive ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                isSearchActive = !isSearchActive;
                if (!isSearchActive) {
                  searchQuery = "";  // Clear search when closing
                }
              });
            },
          ),
          // Filter Icon with Highlighted Option
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              _buildPopupMenuItem('All', 'All Tasks'),
              _buildPopupMenuItem('Completed', 'Completed'),
              _buildPopupMenuItem('Uncompleted', 'Uncompleted'),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: createNewTask,
        backgroundColor: const Color.fromARGB(255, 115, 74, 186),
        foregroundColor: Colors.white,
        child: const Icon(
          Icons.add,
          size: 30,
        ),
      ),
      body: ListView.builder(
        itemCount: filteredTasks.length,
        itemBuilder: (context, index) {
          return TodoTile(
            taskName: filteredTasks[index][0],
            taskCompleted: filteredTasks[index][1],
            dueDate: filteredTasks[index][2],
            onChanged: (value) =>
                checkBoxChanged(value, db.toDoList.indexOf(filteredTasks[index])),
            deleteFunction: (context) =>
                deleteTask(db.toDoList.indexOf(filteredTasks[index])),
          );
        },
      ),
    );
  }

  // Custom Popup Menu Item with Highlight for Selected Filter
  PopupMenuItem<String> _buildPopupMenuItem(String value, String text) {
    final isSelected = filterStatus == value;
    return PopupMenuItem(
      value: value,
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.deepPurple : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}