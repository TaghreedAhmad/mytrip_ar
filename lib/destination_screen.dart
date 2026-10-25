import 'package:flutter/material.dart';
import 'pathfinder.dart';
import 'ar_view_screen.dart';

class DestinationScreen extends StatefulWidget {
  const DestinationScreen({Key? key}) : super(key: key);

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  AirportGraph? graph;
  String startId = 'entrance';

  @override
  void initState() {
    super.initState();
    AirportGraph.load().then((g) => setState(() => graph = g));
  }

  @override
  Widget build(BuildContext context) {
    final g = graph;
    if (g == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final places = g.nodes.values.where((n) => n.isDestination).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('وين تبي تروح؟')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: startId,
              decoration: const InputDecoration(labelText: 'أنت الحين عند'),
              items: places
                  .map((n) => DropdownMenuItem(value: n.id, child: Text(n.name)))
                  .toList(),
              onChanged: (v) => setState(() => startId = v!),
            ),
          ),
          Expanded(
            child: ListView(
              children: places
                  .where((n) => n.id != startId)
                  .map((n) => ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(n.name),
                        trailing: const Icon(Icons.navigation),
                        onTap: () {
                          final path = g.shortestPath(startId, n.id);
                          if (path == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ARViewScreen(path: path),
                            ),
                          );
                        },
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
