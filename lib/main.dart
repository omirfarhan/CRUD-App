import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class Person implements Comparable {
  final int id;
  final String firstname;
  final String lastname;

  const Person({
    required this.id,
    required this.firstname,
    required this.lastname,
  });

  Person.fromRow(Map<String, Object?> map)
    : id = map['ID'] as int,
      firstname = map['FIRST_NAME'] as String,
      lastname = map['LAST_NAME'] as String;

  //other.id.compareTo(id) → এটা descending order এ sort করবে (কারণ সাধারণত id.compareTo(other.id) দিলে ascending হয়)।
  @override
  int compareTo(covariant Person other) => other.id.compareTo(id);

  //অবজেক্ট equality চেক করার সময় শুধু id ব্যবহার হবে, অন্য ফিল্ড নয়
  @override
  bool operator ==(covariant Person other) => id == other.id;

  //যখন অবজেক্টকে Set বা Map এ ব্যবহার করা হবে, তখন id দিয়ে hash তৈরি হবে
  @override
  int get hashCode => id.hashCode;

  //দরকার: debugging বা লগ করার সময় সহজে বোঝা যাবে অবজেক্টে কী আছে
  @override
  String toString() =>
      'Person, ID=$id, firstname = $firstname, lastname = $lastname';
}

class PersonDb {
  final String dbname;
  Database? _db;
  PersonDb({required this.dbname});
  List<Person> _persons = [];
  final _streamcontorller = StreamController<List<Person>>.broadcast();

  Future<List<Person>> _feachingalldata() async {
    final db = _db;
    if (db == null) {
      return [];
    }

    try {
      final read = await db.query(
        'PEOPLE',
        distinct: true,
        columns: ['ID', 'FIRST_NAME', 'LAST_NAME'],
        orderBy: 'ID',
      );

      final people = read.map((read) => Person.fromRow(read)).toList();
      return people;
    } catch (e) {
      return [];
    }
  }

  Future<bool> close() async {
    final db = _db;
    if (db == null) {
      return false;
    }

    await db.close();
    return true;
  }

  Future<bool> open() async {
    if (_db != null) {
      return true;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$dbname';

    try {
      final db = await openDatabase(path);
      _db = db;

      const create = '''CREATE TABLE IF NOT EXISTS PEOPLE (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    FIRST_NAME TEXT NOT NULL,
    LAST_NAME TEXT NOT NULL
);''';

      db.execute(create);
      final persons = await _feachingalldata();
      _persons = persons;
      _streamcontorller.add(_persons);
      return true;
    } catch (e) {
      return false;
    }
  }

  Stream<List<Person>> all() =>
      _streamcontorller.stream.map((persons) => persons..sort());
}

void test() async {}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PersonDb _cloudStorage;
  @override
  void initState() {
    _cloudStorage = PersonDb(dbname: 'db.sqlite');
    _cloudStorage.open();
    super.initState();
  }

  @override
  void dispose() {
    _cloudStorage.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRUD Application'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder(
        stream: _cloudStorage.all(),
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.active:
            case ConnectionState.waiting:
              if (snapshot.data == null) {
                return const Text('data is empty');
              }
              final people = snapshot.data as List<Person>;
              return ListView.builder(
                itemCount: people.length,
                itemBuilder: (context, index) {
                  return const Text('Hello');
                },
              );

              return const Text('OK');

            default:
              return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

void main() {
  runApp(
    MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primaryColor: const Color.fromARGB(255, 58, 106, 188)),
      home: HomePage(),
    ),
  );
}
