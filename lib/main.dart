import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class Person implements Comparable {
  final int id;
  final String firstname;
  final String lastname;

  const Person({
    required this.id,
    required this.firstname,
    required this.lastname,
  });
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

void test() async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/db.sqlite';
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRUD Application'),
        backgroundColor: Colors.blue,
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
