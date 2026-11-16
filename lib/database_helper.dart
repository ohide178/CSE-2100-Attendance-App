import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

dynamic _db;

Future getDb() async {
  if (_db != null) return _db!;

  if (kIsWeb) {
    _db = WebDb();
    return _db!;
  }

  String path = p.join(await getDatabasesPath(), 'attendance_v3.db');
  _db = await openDatabase(
    path,
    version: 1,
    onCreate: (d, v) async {
      await d.execute(
        'CREATE TABLE courses (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT, name TEXT, teacher TEXT, dept TEXT, credits REAL)',
      );
      await d.execute(
        'CREATE TABLE students (id INTEGER PRIMARY KEY AUTOINCREMENT, course_id INTEGER, roll INTEGER, name TEXT)',
      );
      await d.execute(
        'CREATE TABLE attendance (id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER, date TEXT, status TEXT)',
      );
    },
  );
  return _db!;
}

class WebDb {
  int _cId = 1;
  int _sId = 1;
  int _aId = 1;
  List courses = [];
  List students = [];
  List attendance = [];

  Future query(
    String table, {
    String? where,
    List? whereArgs,
    String? orderBy,
  }) async {
    if (table == 'courses') {
      return List.from(courses.reversed);
    }
    if (table == 'students') {
      if (where == 'course_id = ?') {
        List list = students.where((s) => s['course_id'] == whereArgs![0]).toList();
        list.sort((a, b) => (a['roll'] as int).compareTo(b['roll'] as int));
        return list;
      }
      if (where == 'course_id = ? AND roll = ?') {
        return students
            .where((s) => s['course_id'] == whereArgs![0] && s['roll'] == whereArgs[1])
            .toList();
      }
      if (where == 'course_id = ? AND roll = ? AND id != ?') {
        return students
            .where((s) =>
                s['course_id'] == whereArgs![0] &&
                s['roll'] == whereArgs[1] &&
                s['id'] != whereArgs[2])
            .toList();
      }
    }
    if (table == 'attendance') {
      if (where == 'student_id = ? AND date = ?') {
        return attendance
            .where((a) => a['student_id'] == whereArgs![0] && a['date'] == whereArgs[1])
            .toList();
      }
    }
    return [];
  }

  Future insert(String table, Map values) async {
    Map row = Map.from(values);
    if (table == 'courses') {
      row['id'] = _cId++;
      courses.add(row);
      return row['id'];
    }
    if (table == 'students') {
      row['id'] = _sId++;
      students.add(row);
      return row['id'];
    }
    if (table == 'attendance') {
      row['id'] = _aId++;
      attendance.add(row);
      return row['id'];
    }
    return 0;
  }

  Future update(
    String table,
    Map values, {
    String? where,
    List? whereArgs,
  }) async {
    var id = whereArgs![0];
    List list = table == 'courses'
        ? courses
        : table == 'students'
            ? students
            : attendance;
    for (var row in list) {
      if (row['id'] == id) {
        row.addAll(Map.from(values));
      }
    }
    return 1;
  }

  Future delete(
    String table, {
    String? where,
    List? whereArgs,
  }) async {
    List list = table == 'courses'
        ? courses
        : table == 'students'
            ? students
            : attendance;
    if (where == null) {
      list.clear();
    } else if (where == 'id = ?') {
      list.removeWhere((r) => r['id'] == whereArgs![0]);
    } else if (where == 'course_id = ?') {
      list.removeWhere((r) => r['course_id'] == whereArgs![0]);
    } else if (where == 'student_id = ?') {
      list.removeWhere((r) => r['student_id'] == whereArgs![0]);
    }
    return 1;
  }

  Future execute(String sql, [List? arguments]) async {
    if (arguments != null && arguments.isNotEmpty) {
      var courseId = arguments[0];
      Set sIds = students
          .where((s) => s['course_id'] == courseId)
          .map((s) => s['id'])
          .toSet();
      attendance.removeWhere((a) => sIds.contains(a['student_id']));
    }
  }

  Future rawQuery(String sql, [List? arguments]) async {
    if (sql.contains('JOIN students s') && arguments!.length == 2) {
      var courseId = arguments[0];
      var date = arguments[1];
      Set sIds = students
          .where((s) => s['course_id'] == courseId)
          .map((s) => s['id'])
          .toSet();
      return attendance
          .where((a) => sIds.contains(a['student_id']) && a['date'] == date)
          .map((a) => {'student_id': a['student_id'], 'status': a['status']})
          .toList();
    }
    if (sql.contains('GROUP BY s.id')) {
      var courseId = arguments![0];
      List cStudents = students.where((s) => s['course_id'] == courseId).toList();
      cStudents.sort((a, b) => (a['roll'] as int).compareTo(b['roll'] as int));

      List result = [];
      for (var s in cStudents) {
        List sAtt = attendance.where((a) => a['student_id'] == s['id']).toList();
        int tot = sAtt.length;
        int att = sAtt.where((a) => a['status'] == 'Present').length;
        result.add({
          'roll': s['roll'],
          'name': s['name'],
          'total': tot,
          'attended': att,
        });
      }
      return result;
    }
    return [];
  }
}