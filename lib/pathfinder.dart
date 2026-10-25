import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class MapNode {
  final String id;
  final String name;
  final double x;
  final double y;
  final bool isDestination;

  MapNode(this.id, this.name, this.x, this.y, this.isDestination);
}

class AirportGraph {
  final Map<String, MapNode> nodes = {};
  final Map<String, List<String>> adj = {};

  static Future<AirportGraph> load() async {
    final g = AirportGraph();
    final data = jsonDecode(await rootBundle.loadString('assets/airport_map.json'));
    for (final n in data['nodes']) {
      g.nodes[n['id']] = MapNode(
        n['id'],
        n['name'],
        (n['x'] as num).toDouble(),
        (n['y'] as num).toDouble(),
        n['dest'] ?? true,
      );
      g.adj[n['id']] = [];
    }
    for (final e in data['edges']) {
      g.adj[e[0]]!.add(e[1]);
      g.adj[e[1]]!.add(e[0]);
    }
    return g;
  }

  double _dist(MapNode a, MapNode b) =>
      sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));

  List<MapNode>? shortestPath(String from, String to) {
    final dist = <String, double>{for (final k in nodes.keys) k: double.infinity};
    final prev = <String, String>{};
    final todo = nodes.keys.toSet();
    dist[from] = 0;

    while (todo.isNotEmpty) {
      final u = todo.reduce((a, b) => dist[a]! <= dist[b]! ? a : b);
      if (dist[u] == double.infinity) break;
      todo.remove(u);
      if (u == to) break;
      for (final v in adj[u]!) {
        final alt = dist[u]! + _dist(nodes[u]!, nodes[v]!);
        if (alt < dist[v]!) {
          dist[v] = alt;
          prev[v] = u;
        }
      }
    }

    if (dist[to] == double.infinity) return null;
    final path = <MapNode>[];
    String? cur = to;
    while (cur != null) {
      path.insert(0, nodes[cur]!);
      cur = prev[cur];
    }
    return path;
  }
}
