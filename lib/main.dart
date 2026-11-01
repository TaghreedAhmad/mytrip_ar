import 'package:flutter/material.dart';
import 'destination_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyTripARApp());
}

class MyTripARApp extends StatelessWidget {
  const MyTripARApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyTrip AR',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DestinationScreen(),
    );
  }
}
