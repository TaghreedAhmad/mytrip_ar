// lib/destination_screen.dart
import 'package:flutter/material.dart';
import 'pathfinder.dart';
import 'ar_view_screen.dart';
import 'qr_scan_screen.dart';
import 'model_ar_screen.dart';

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

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // يمسح الباركود ويحدد مكانك الحالي
  Future<void> _scan() async {
    final g = graph;
    if (g == null) return;

    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw == null || !mounted) return;

    final text = raw.trim();
    final id = text.startsWith('mytrip:') ? text.substring(7) : text;

    if (!g.nodes.containsKey(id)) {
      _msg('باركود غير معروف: $text');
      return;
    }
    setState(() => startId = id);
    _msg('أنت الحين عند ${g.nodes[id]!.name}');
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

    // لو الباركود لنقطة مو وجهة (مثل الممر)، نضيفها للقائمة عشان ما يصير خطأ
    final startItems = [...places];
    final cur = startId == null ? null : g.nodes[startId!];
    if (cur != null && !startItems.any((n) => n.id == cur.id)) {
      startItems.add(cur);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('وين تبي تروح؟')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButtonFormField<String>(
              value: startId,
              decoration: const InputDecoration(labelText: 'أنت الحين عند'),
              items: startItems
                  .map((n) =>
                      DropdownMenuItem(value: n.id, child: Text(n.name)))
                  .toList(),
              onChanged: (v) => setState(() => startId = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('امسحي الباركود لتحديد مكانك'),
              ),
            ),
          ),
                    Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ModelARScreen()),
                ),
                icon: const Icon(Icons.view_in_ar),
                label: const Text('عرض نموذج المطار'),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                          final path =
                              s == null ? null : g.shortestPath(s, n.id);
                          if (path == null || path.length < 2) {
                            _msg('ما فيه مسار بين النقطتين');
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
