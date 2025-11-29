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

  String get fullname => '$firstname $lastname';

  Person.fromRow(Map<String, Object?> map)
    : id = map['ID'] as int,
      firstname = map['FIRST_NAME'] as String,
      lastname = map['LAST_NAME'] as String;

  //other.id.compareTo(id) → এটা descending order এ sort করবে (কারণ সাধারণত id.compareTo(other.id) দিলে ascending হয়)।
  @override
  int compareTo(covariant Person other) => other.id.compareTo(id);

  @override
  bool operator ==(covariant Person other) => id == other.id;

  @override
  int get hashCode => id.hashCode;

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

  Future<bool> insert(String firstname, String lastname) async {
    final db = _db;
    if (db == null) {
      return false;
    }
    try {
      final id = await db.insert('PEOPLE', {
        'FIRST_NAME': firstname,
        'LAST_NAME': lastname,
      });

      final person = Person(id: id, firstname: firstname, lastname: lastname);

      _persons.add(person);
      _streamcontorller.add(_persons);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> delete(Person person) async {
    final db = _db;
    if (db == null) {
      return false;
    }

    try {
      final deleteCount = await db.delete(
        'PEOPLE',
        where: ' ID= ? ',
        whereArgs: [person.id],
      );

      if (deleteCount == 1) {
        _persons.remove(person);
        _streamcontorller.add(_persons);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> update(Person person) async {
    final db = _db;
    if (db == null) {
      return false;
    }

    try {
      final updateCount = await db.update(
        'PEOPLE',
        {'FIRST_NAME': person.firstname, 'LAST_NAME': person.lastname},
        where: 'ID = ?',
        whereArgs: [person.id],
      );

      if (updateCount == 1) {
        _persons.removeWhere((other) => other.id == person.id);
        _persons.add(person);
        _streamcontorller.add(_persons);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
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
              return Column(
                children: [
                  ComposeWidget(
                    onCompose: (String firstname, String lastname) async {
                      await _cloudStorage.insert(firstname, lastname);
                    },
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (context, index) {
                        final person = people[index];
                        return ListTile(
                          onTap: () async {
                            final editedperson = await showUpdatedialoge(
                              context,
                              person,
                            );

                            if (editedperson != null) {
                              await _cloudStorage.update(editedperson);
                            }
                          },
                          title: Text(person.fullname),
                          subtitle: Text('ID: ${person.id}'),
                          trailing: TextButton(
                            onPressed: () async {
                              final dialoges = await showDeleteDialoge(context);
                              if (dialoges) {
                                await _cloudStorage.delete(person);
                              }
                            },
                            child: const Icon(
                              Icons.disabled_by_default_rounded,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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

final _firstnameController = TextEditingController();
final _lastnameController = TextEditingController();

Future<Person?> showUpdatedialoge(BuildContext context, Person person) async {
  _firstnameController.text = person.firstname;
  _lastnameController.text = person.lastname;

  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your updated values here: '),
            TextField(controller: _firstnameController),
            TextField(controller: _lastnameController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(null);
            },
            child: const Text('Cancel'),
          ),

          TextButton(
            onPressed: () async {
              final Editperson = Person(
                id: person.id,
                firstname: _firstnameController.text,
                lastname: _lastnameController.text,
              );
              Navigator.of(context).pop(Editperson);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  ).then((value) {
    if (value is Person) {
      return value;
    } else {
      return null;
    }
  });
}

typedef OnCompose = void Function(String firstname, String lastname);

class ComposeWidget extends StatefulWidget {
  final OnCompose onCompose;
  const ComposeWidget({super.key, required this.onCompose});

  @override
  State<ComposeWidget> createState() => _ComposeWidgetState();
}

class _ComposeWidgetState extends State<ComposeWidget> {
  late final TextEditingController _firstnameController;
  late final TextEditingController _lastnameController;

  @override
  void initState() {
    _firstnameController = TextEditingController();
    _lastnameController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _firstnameController.dispose();
    _lastnameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _firstnameController,
            decoration: const InputDecoration(hintText: 'Enter first name'),
          ),

          TextField(
            controller: _lastnameController,
            decoration: InputDecoration(hintText: 'Enter last name'),
          ),

          TextButton(
            onPressed: () {
              final firstname = _firstnameController.text;
              final lastname = _lastnameController.text;
              widget.onCompose(firstname, lastname);
              _firstnameController.text = '';
              _lastnameController.text = '';
            },
            child: const Text('Add to List', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}

Future<bool> showDeleteDialoge(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('No'),
          ),

          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('Delete'),
          ),
        ],
      );
    },
  ).then((value) {
    if (value is bool) {
      return value;
    } else {
      return false;
    }
  });
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
