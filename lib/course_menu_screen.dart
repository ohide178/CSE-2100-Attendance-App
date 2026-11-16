// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'attendance_screen.dart';
import 'reports_screen.dart';

class CourseMenuScreen extends StatelessWidget {
  final Map course;
  const CourseMenuScreen({super.key, required this.course});

  void addStudentDialog(BuildContext context) {
    final roll = TextEditingController();
    final name = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roll,
              decoration: InputDecoration(labelText: 'Roll Number'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: 'Student Name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final r = int.tryParse(roll.text);
              if (r == null || name.text.isEmpty) return;
              final d = await getDb();
              final check = await d.query(
                'students',
                where: 'course_id = ? AND roll = ?',
                whereArgs: [course['id'], r],
              );
              if (check.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Roll already exists!'), backgroundColor: Colors.red),
                );
                return;
              }
              await d.insert('students', {
                'course_id': course['id'],
                'roll': r,
                'name': name.text,
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Student added')),
              );
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(course['code'].toString())),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              course['name'].toString(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Teacher: ${course['teacher']} | Department: ${course['dept']}'),
            SizedBox(height: 25),
            ElevatedButton.icon(
              icon: Icon(Icons.person_add),
              onPressed: () => addStudentDialog(context),
              label: Text('1. Add Student'),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(Icons.checklist),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AttendanceScreen(course: course)),
              ),
              label: Text('2. Take Attendance & Manage Students'),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(Icons.analytics),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReportsScreen(course: course)),
              ),
              label: Text('3. View & Export Report'),
            ),
          ],
        ),
      ),
    );
  }
}