// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'database_helper.dart';

class AttendanceScreen extends StatefulWidget {
  final Map course;
  const AttendanceScreen({super.key, required this.course});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List students = [];
  Map status = {};
  String date = DateTime.now().toString().split(' ')[0];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final d = await getDb();
    final sList = await d.query(
      'students',
      where: 'course_id = ?',
      whereArgs: [widget.course['id']],
      orderBy: 'roll ASC',
    );
    final aList = await d.rawQuery(
      'SELECT a.student_id, a.status FROM attendance a JOIN students s ON a.student_id = s.id WHERE s.course_id = ? AND a.date = ?',
      [widget.course['id'], date],
    );

    Map temp = {};
    for (var row in aList) {
      temp[row['student_id']] = row['status'];
    }

    setState(() {
      students = sList;
      status.clear();
      for (var s in students) {
        var id = s['id'];
        status[id] = temp[id] ?? 'Absent';
      }
    });
  }

  void editStudentDialog(Map s) {
    final roll = TextEditingController(text: s['roll'].toString());
    final name = TextEditingController(text: s['name'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Student'),
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
                where: 'course_id = ? AND roll = ? AND id != ?',
                whereArgs: [widget.course['id'], r, s['id']],
              );
              if (check.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Roll already exists!'), backgroundColor: Colors.red),
                );
                return;
              }
              await d.update(
                'students',
                {'roll': r, 'name': name.text},
                where: 'id = ?',
                whereArgs: [s['id']],
              );
              Navigator.pop(ctx);
              loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Student updated')),
              );
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void confirmDeleteStudent(Map s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Student?'),
        content: Text('Remove ${s['name']} (Roll: ${s['roll']}) and all their attendance records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final d = await getDb();
              await d.delete('attendance', where: 'student_id = ?', whereArgs: [s['id']]);
              await d.delete('students', where: 'id = ?', whereArgs: [s['id']]);
              Navigator.pop(ctx);
              loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${s['name']} removed')),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Roll Call ($date)'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () async {
              DateTime? p = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(date),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (p != null) {
                setState(() => date = p.toString().split(' ')[0]);
                loadData();
              }
            },
          ),
        ],
      ),
      body: students.isEmpty
          ? Center(child: Text('No students enrolled yet.'))
          : ListView.builder(
              itemCount: students.length,
              itemBuilder: (ctx, i) {
                final s = students[i];
                final id = s['id'];
                return ListTile(
                  title: Text(s['name'].toString()),
                  subtitle: Text('Roll: ${s['roll']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: status[id] == 'Present',
                        onChanged: (v) => setState(() => status[id] = v ? 'Present' : 'Absent'),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue, size: 20),
                        onPressed: () => editStudentDialog(s),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => confirmDeleteStudent(s),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.save),
        onPressed: () async {
          final d = await getDb();
          for (var id in status.keys) {
            final check = await d.query(
              'attendance',
              where: 'student_id = ? AND date = ?',
              whereArgs: [id, date],
            );
            if (check.isNotEmpty) {
              await d.update(
                'attendance',
                {'status': status[id]},
                where: 'id = ?',
                whereArgs: [check.first['id']],
              );
            } else {
              await d.insert('attendance', {
                'student_id': id,
                'date': date,
                'status': status[id],
              });
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved for $date')),
          );
          Navigator.pop(context);
        },
      ),
    );
  }
}