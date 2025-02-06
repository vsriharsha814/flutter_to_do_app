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
  String searchQuery = "";  // Stores the search input
  String filterStatus = "All";  // "All", "Completed", or "Uncompleted"

  @override
  void initState() {
    super.initState();

    // Initialize Hive data
    if (_myBox.get("TODOLIST") == null) {
      db.createInitialData();
    } else {
      db.loadData();
    }

    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Initialize timezone data for scheduling
    tz.initializeTimeZones();
  }

  final _controller = TextEditingController();
  DateTime? selectedDueDate;  // Nullable due date for tasks

  // Toggle task completion
  void checkBoxChanged(bool? value, int index) {
    setState(() {
      db.toDoList[index][1] = !db.toDoList[index][1];
    });
    db.updateDatabase();
  }

  // Save new task, optionally with due date and notification
  void saveNewTask() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        db.toDoList.add([_controller.text, false, selectedDueDate]);
        _controller.clear();
      });

      if (selectedDueDate != null) {
        scheduleNotification(_controller.text, selectedDueDate!);  // Schedule notification only if due date exists
      }

      Navigator.of(context).pop();
      db.updateDatabase();
      selectedDueDate = null;  // Reset after saving
    }
  }

  // Cancel task creation and reset fields
  void cancelTask() {
    Navigator.of(context).pop();
    setState(() {
      _controller.clear();
      selectedDueDate = null;
    });
  }

  // Show dialog to create a new task
  void createNewTask() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialogBox(
          controller: _controller,
          onSave: saveNewTask,
          onCancel: cancelTask,
          onDateSelected: (date) {
            selectedDueDate = date;  // Capture the selected due date
          },
        );
      },
    );
  }

  // Delete task and cancel notification if a due date was set
  void deleteTask(int index) {
    if (db.toDoList[index][2] != null) {
      cancelNotification(db.toDoList[index][2]);
    }

    setState(() {
      db.toDoList.removeAt(index);
    });
    db.updateDatabase();
  }

  // Schedule a local notification for tasks with due dates
  Future<void> scheduleNotification(String taskName, DateTime dueDate) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      dueDate.millisecondsSinceEpoch ~/ 1000,  // Unique ID based on due date
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

  // Cancel a scheduled notification when a task is deleted
  Future<void> cancelNotification(DateTime dueDate) async {
    await flutterLocalNotificationsPlugin.cancel(dueDate.millisecondsSinceEpoch ~/ 1000);
  }

  @override
  Widget build(BuildContext context) {
    // Filter tasks based on search query and filter status
    final filteredTasks = db.toDoList.where((task) {
      final taskName = task[0].toString().toLowerCase();
      final isCompleted = task[1] as bool;

      // Apply search filter
      final matchesSearch = searchQuery.isEmpty || taskName.contains(searchQuery);

      // Apply completion status filter
      final matchesStatus = filterStatus == "All" ||
          (filterStatus == "Completed" && isCompleted) ||
          (filterStatus == "Uncompleted" && !isCompleted);

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.deepPurple[100],
      appBar: AppBar(
        title: const Text(
          'SwiftList',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.bold,
            fontFamily: "Montserrat",
          ),
        ),
        actions: [
          // Filter Icon with Popup Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'All', child: Text('All Tasks')),
              PopupMenuItem(value: 'Completed', child: Text('Completed')),
              PopupMenuItem(value: 'Uncompleted', child: Text('Uncompleted')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();  // Update the search query
                });
              },
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
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
            dueDate: filteredTasks[index][2],  // Pass due date to TodoTile
            onChanged: (value) => checkBoxChanged(value, db.toDoList.indexOf(filteredTasks[index])),
            deleteFunction: (context) => deleteTask(db.toDoList.indexOf(filteredTasks[index])),
          );
        },
      ),
    );
  }
}