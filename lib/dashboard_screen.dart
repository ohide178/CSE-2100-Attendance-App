// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'course_menu_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List courses = [];

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> loadCourses() async {
    final d = await getDb();
    final data = await d.query('courses', orderBy: 'id DESC');
    setState(() => courses = data);
  }

  void showCourseDialog({Map? existingCourse}) {
    final isEdit = existingCourse != null;
    final code = TextEditingController(text: isEdit ? existingCourse['code'].toString() : '');
    final name = TextEditingController(text: isEdit ? existingCourse['name'].toString() : '');
    final teacher = TextEditingController(text: isEdit ? existingCourse['teacher'].toString() : '');
    final dept = TextEditingController(text: isEdit ? existingCourse['dept'].toString() : '');
    double credits = isEdit ? (existingCourse['credits'] as num).toDouble() : 3.00;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Course' : 'Add Course'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: code, decoration: InputDecoration(labelText: 'Course Code')),
                TextField(controller: name, decoration: InputDecoration(labelText: 'Course Name')),
                TextField(controller: teacher, decoration: InputDecoration(labelText: 'Teacher')),
                TextField(controller: dept, decoration: InputDecoration(labelText: 'Department')),
                DropdownButton(
                  value: [3.00, 1.50, 0.75].contains(credits) ? credits : 3.00,
                  isExpanded: true,
                  items: [3.00, 1.50, 0.75]
                      .map((c) => DropdownMenuItem(value: c, child: Text('$c Credits')))
                      .toList(),
                  onChanged: (v) => setDialogState(() => credits = (v as num).toDouble()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (code.text.isEmpty || name.text.isEmpty) return;
                final d = await getDb();
                final row = {
                  'code': code.text,
                  'name': name.text,
                  'teacher': teacher.text,
                  'dept': dept.text,
                  'credits': credits,
                };
                if (isEdit) {
                  await d.update('courses', row, where: 'id = ?', whereArgs: [existingCourse['id']]);
                } else {
                  await d.insert('courses', row);
                }
                Navigator.pop(ctx);
                loadCourses();
              },
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void confirmDeleteCourse(Map c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Course?'),
        content: Text('Delete ${c['code']} and all its student attendance records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final d = await getDb();
              await d.execute(
                'DELETE FROM attendance WHERE student_id IN (SELECT id FROM students WHERE course_id = ?)',
                [c['id']],
              );
              await d.delete('students', where: 'course_id = ?', whereArgs: [c['id']]);
              await d.delete('courses', where: 'id = ?', whereArgs: [c['id']]);
              Navigator.pop(ctx);
              loadCourses();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${c['code']} deleted')),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('App Instructions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Add & Manage Courses:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Tap "+ Add Course" to create a course. Use the Pencil icon to edit course details or the Trash icon to delete a course.\n'),
              Text('2. Enroll & Edit Students:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Open a course and tap "1. Add Student". Inside the Roll Call screen, you can also edit or delete any student using the Pencil and Trash icons.\n'),
              Text('3. Take & Edit Attendance:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Open "2. Take Attendance", toggle switches for Present/Absent, and tap Save. Use the Calendar icon at the top right to view or edit past dates.\n'),
              Text('4. Exam Eligibility & CSV:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Students with 50% or higher attendance are marked Eligible. Tap "Download CSV" in Reports to save the file to your phone\'s Downloads folder.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text('Got It')),
        ],
      ),
    );
  }

  void showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Settings & Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.school, color: Colors.blue),
              title: Text('My Attendance App'),
              subtitle: Text('CSE 2100 Lab Project\nEramOhid'),
            ),
            Divider(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              icon: Icon(Icons.delete_forever, color: Colors.white),
              label: Text('Reset All App Data', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final d = await getDb();
                await d.delete('attendance');
                await d.delete('students');
                await d.delete('courses');
                Navigator.pop(ctx);
                loadCourses();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('All app data cleared!')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.fact_check),
        title: Text('My Attendance App'),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            tooltip: 'Instructions',
            onPressed: showInstructionsDialog,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: showSettingsDialog,
          ),
        ],
      ),
      body: courses.isEmpty
          ? Center(child: Text('No courses yet. Tap + to add.'))
          : ListView.builder(
              itemCount: courses.length,
              itemBuilder: (ctx, i) {
                final c = courses[i];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text('${c['code']} - ${c['name']}'),
                    subtitle: Text('${c['dept']} | ${c['credits']} Cr | ${c['teacher']}'),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CourseMenuScreen(course: c)),
                      );
                      loadCourses();
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => showCourseDialog(existingCourse: c),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => confirmDeleteCourse(c),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCourseDialog(),
        icon: Icon(Icons.add),
        label: Text('Add Course'),
      ),
    );
  }
}