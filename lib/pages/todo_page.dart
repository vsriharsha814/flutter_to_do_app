import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:to_do_flutter_app/data/database.dart';
import 'package:to_do_flutter_app/pages/settings_page.dart';
import 'package:to_do_flutter_app/util/alert_dialog_box.dart';
import 'package:to_do_flutter_app/util/todo_tile.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _myBox = Hive.box('myBox');
  TodoDatabase db = TodoDatabase();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  String searchQuery = "";
  String filterStatus = "All";
  bool isSearchActive = false;

  @override
  void initState() {
    super.initState();

    if (_myBox.get("TODOLIST") == null) {
      db.createInitialData();
    } else {
      db.loadData();
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Denver'));

    _initializeNotifications();
    _requestAllPermissions();  // Request both notification and alarm permissions on startup
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _createNotificationChannel();
  }

  void _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'task_channel',
      'Task Notifications',
      description: 'Channel for task reminders',
      importance: Importance.max,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlatform =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlatform?.createNotificationChannel(channel);
  }

  Future<void> _requestAllPermissions() async {
    // Request notification permission
    await _requestNotificationPermissions();
    
    // Request exact alarm permission
    if (await Permission.scheduleExactAlarm.isDenied) {
      await _showAlarmPermissionDialog();
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final permissionStatus = await Permission.notification.status;

    if (permissionStatus.isDenied) {
      final requestStatus = await Permission.notification.request();
      if (!requestStatus.isGranted) {
        _showPermissionDeniedDialog();
      }
    } else if (permissionStatus.isPermanentlyDenied) {
      _showPermissionSettingsDialog();
    }
  }

  Future<void> _showAlarmPermissionDialog() async {
    bool userConsent = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow Alarms & Reminders'),
        content: const Text('To schedule exact reminders, we need permission to set alarms.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (userConsent) {
      await openAppSettings();  // Redirect to system settings to enable alarm permissions
    }
  }

  final _controller = TextEditingController();
  DateTime? selectedDueDate;

  void checkBoxChanged(bool? value, int index) {
    setState(() {
      db.toDoList[index][1] = !db.toDoList[index][1];
    });
    db.updateDatabase();
  }

  Future<void> saveNewTask() async {
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
    if (dueDate.isBefore(DateTime.now())) return;

    final int notificationId = dueDate.millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
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
        iOS: IOSNotificationDetails(),
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

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('Notification permission is required to show reminders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notifications'),
        content: const Text(
          'Notifications are disabled for this app. Please enable them in the system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
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
                style: const TextStyle(color: Colors.white, fontSize: 18),
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
          IconButton(
            icon: Icon(
              isSearchActive ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                isSearchActive = !isSearchActive;
                if (!isSearchActive) {
                  searchQuery = "";
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
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
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: createNewTask,
        backgroundColor: const Color.fromARGB(255, 115, 74, 186),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 30),
      ),
      body: ListView.builder(
        itemCount: filteredTasks.length,
        itemBuilder: (context, index) {
          return TodoTile(
            taskName: filteredTasks[index][0],
            taskCompleted: filteredTasks[index][1],
            dueDate: filteredTasks[index][2],
            onChanged: (value) => checkBoxChanged(value, db.toDoList.indexOf(filteredTasks[index])),
            deleteFunction: (context) => deleteTask(db.toDoList.indexOf(filteredTasks[index])),
          );
        },
      ),
    );
  }

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