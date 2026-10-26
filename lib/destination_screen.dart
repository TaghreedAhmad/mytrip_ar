// lib/destination_screen.dart
import 'package:flutter/material.dart';
import 'pathfinder.dart';
import 'ar_view_screen.dart';

class DestinationScreen extends StatefulWidget {
  const DestinationScreen({super.key});

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  AirportGraph? graph;
  String? error;
  String? startId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      error = null;
      graph = null;
    });
    try {
      final g = await AirportGraph.load();
      if (!mounted) return;
      final places = g.nodes.values.where((n) => n.isDestination).toList();
      setState(() {
        graph = g;
        startId = g.nodes.containsKey('entrance')
            ? 'entrance'
            : (places.isNotEmpty ? places.first.id : null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'تعذر تحميل الخريطة:\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('وين تبي تروح؟')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _load,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
              onChanged: (v) => setState(() => startId = v),
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
                          final s = startId;
                          final path = s == null ? null : g.shortestPath(s, n.id);
                          if (path == null || path.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ما فيه مسار بين النقطتين'),
                              ),
                            );
                            return;
                          }
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
