// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database_helper.dart';

class ReportsScreen extends StatefulWidget {
  final Map course;
  const ReportsScreen({super.key, required this.course});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List report = [];

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    final d = await getDb();
    final data = await d.rawQuery('''
      SELECT s.roll, s.name, COUNT(a.id) as total,
      SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) as attended
      FROM students s LEFT JOIN attendance a ON s.id = a.student_id
      WHERE s.course_id = ? GROUP BY s.id ORDER BY s.roll ASC
    ''', [widget.course['id']]);
    setState(() => report = data);
  }

  Future<void> exportCsv() async {
    String csvText = 'Course,${widget.course['code']},Credits,${widget.course['credits']}\n\n';
    csvText += 'Roll,Name,Total,Attended,Percentage,Status\n';

    for (var r in report) {
      int tot = (r['total'] as int?) ?? 0;
      int att = (r['attended'] as int?) ?? 0;
      double pct = tot == 0 ? 0 : (att / tot) * 100;
      String status = pct >= 50.0 ? 'Eligible' : 'Not Eligible';

      csvText += '${r['roll']},${r['name']},$tot,$att,${pct.toStringAsFixed(1)}%,$status\n';
    }

    await Clipboard.setData(ClipboardData(text: csvText));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('CSV Report Ready'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Copied to Clipboard! You can paste this into Excel or Notepad:', style: TextStyle(fontSize: 12, color: Colors.green[700])),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                color: Colors.grey[200],
                child: Text(csvText, style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('CSV copied to clipboard!')),
              );
            },
            child: Text('Copy Again'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.course['code']} Report'),
        actions: [
          TextButton.icon(
            onPressed: exportCsv,
            icon: Icon(Icons.download, color: Colors.white),
            label: Text('Export CSV', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: report.length,
        itemBuilder: (ctx, i) {
          final r = report[i];
          int tot = (r['total'] as int?) ?? 0;
          int att = (r['attended'] as int?) ?? 0;
          double pct = tot == 0 ? 0 : (att / tot) * 100;
          bool ok = pct >= 50.0;

          return ListTile(
            title: Text('${r['name']} (Roll: ${r['roll']})'),
            subtitle: Text(
              'Attended: $att/$tot (${pct.toStringAsFixed(1)}%) - ${ok ? "Eligible" : "Not Eligible"}',
            ),
            trailing: Icon(
              ok ? Icons.check_circle : Icons.cancel,
              color: ok ? Colors.green : Colors.red,
            ),
          );
        },
      ),
    );
  }
}