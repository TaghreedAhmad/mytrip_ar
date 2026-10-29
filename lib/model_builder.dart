// lib/model_builder.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'pathfinder.dart';

class _Group {
  final List<double> pos = [];
  final List<double> nrm = [];
}

/// يبني ملف glTF (نص) لجزء من الخريطة.
/// unit = كم متر لكل وحدة في الخريطة (0.01 = ماكيت صغير).
class AirportModelBuilder {
  final double unit;
  AirportModelBuilder({this.unit = 0.01});

  void _tri(_Group g, List<double> a, List<double> b, List<double> c,
      List<double> n) {
    for (final v in [a, b, c]) {
      g.pos.addAll(v);
      g.nrm.addAll(n);
    }
  }

  void _quad(_Group g, List<double> a, List<double> b, List<double> c,
      List<double> d, List<double> n) {
    _tri(g, a, b, c, n);
    _tri(g, a, c, d, n);
  }

  // مجسّم من 4 نقاط (x,z) من y0 إلى y1
  void _prism(_Group g, List<List<double>> q, double y0, double y1) {
    _quad(
      g,
      [q[0][0], y1, q[0][1]],
      [q[1][0], y1, q[1][1]],
      [q[2][0], y1, q[2][1]],
      [q[3][0], y1, q[3][1]],
      [0, 1, 0],
    );
    final cx = q.map((p) => p[0]).reduce((a, b) => a + b) / 4;
    final cz = q.map((p) => p[1]).reduce((a, b) => a + b) / 4;
    for (int i = 0; i < 4; i++) {
      final a = q[i];
      final b = q[(i + 1) % 4];
      final ex = b[0] - a[0];
      final ez = b[1] - a[1];
      final len = sqrt(ex * ex + ez * ez);
      if (len == 0) continue;
      var nx = ez / len;
      var nz = -ex / len;
      final mx = (a[0] + b[0]) / 2 - cx;
      final mz = (a[1] + b[1]) / 2 - cz;
      if (nx * mx + nz * mz < 0) {
        nx = -nx;
        nz = -nz;
      }
      _quad(
        g,
        [a[0], y0, a[1]],
        [b[0], y0, b[1]],
        [b[0], y1, b[1]],
        [a[0], y1, a[1]],
        [nx, 0, nz],
      );
    }
  }

  void _box(_Group g, double cx, double cz, double h, double y0, double y1) {
    _prism(g, [
      [cx - h, cz - h],
      [cx + h, cz - h],
      [cx + h, cz + h],
      [cx - h, cz + h],
    ], y0, y1);
  }

  void _strip(_Group g, double ax, double az, double bx, double bz, double hw,
      double y0, double y1) {
    final dx = bx - ax;
    final dz = bz - az;
    final len = sqrt(dx * dx + dz * dz);
    if (len == 0) return;
    final px = -dz / len * hw;
    final pz = dx / len * hw;
    _prism(g, [
      [ax + px, az + pz],
      [bx + px, bz + pz],
      [bx - px, bz - pz],
      [ax - px, az - pz],
    ], y0, y1);
  }

  String build(AirportGraph g, Set<String> ids) {
    final nodes =
        ids.where(g.nodes.containsKey).map((i) => g.nodes[i]!).toList();
    if (nodes.isEmpty) throw Exception('ما لقيت أي نقطة من المنطقة المحددة');

    final minX = nodes.map((n) => n.x).reduce(min);
    final maxX = nodes.map((n) => n.x).reduce(max);
    final minY = nodes.map((n) => n.y).reduce(min);
    final maxY = nodes.map((n) => n.y).reduce(max);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    const margin = 10.0;

    double px(double x) => (x - cx) * unit;
    double pz(double y) => (y - cy) * unit;

    final base = _Group();
    final paths = _Group();
    final places = _Group();

    // الأرضية
    _prism(base, [
      [px(minX - margin), pz(minY - margin)],
      [px(maxX + margin), pz(minY - margin)],
      [px(maxX + margin), pz(maxY + margin)],
      [px(minX - margin), pz(maxY + margin)],
    ], 0, 1 * unit);

    // الممرات
    for (final n in nodes) {
      for (final nb in g.adj[n.id] ?? <String>[]) {
        if (!ids.contains(nb) || n.id.compareTo(nb) >= 0) continue;
        final m = g.nodes[nb]!;
        _strip(paths, px(n.x), pz(n.y), px(m.x), pz(m.y), 1.2 * unit,
            1 * unit, 1.5 * unit);
      }
    }

    // الأماكن
    for (final n in nodes) {
      _box(places, px(n.x), pz(n.y), 2.5 * unit, 1 * unit, 5 * unit);
    }

    final bb = BytesBuilder();
    final bufferViews = <Map<String, dynamic>>[];
    final accessors = <Map<String, dynamic>>[];
    final primitives = <Map<String, dynamic>>[];

    int addAccessor(List<double> data, {bool withBounds = false}) {
      final bytes = Float32List.fromList(data).buffer.asUint8List();
      bufferViews.add({
        'buffer': 0,
        'byteOffset': bb.length,
        'byteLength': bytes.length,
        'target': 34962,
      });
      bb.add(bytes);
      final acc = <String, dynamic>{
        'bufferView': bufferViews.length - 1,
        'componentType': 5126,
        'count': data.length ~/ 3,
        'type': 'VEC3',
      };
      if (withBounds) {
        final mn = [double.infinity, double.infinity, double.infinity];
        final mx = [-double.infinity, -double.infinity, -double.infinity];
        for (int i = 0; i < data.length; i += 3) {
          for (int k = 0; k < 3; k++) {
            mn[k] = min(mn[k], data[i + k]);
            mx[k] = max(mx[k], data[i + k]);
          }
        }
        acc['min'] = mn;
        acc['max'] = mx;
      }
      accessors.add(acc);
      return accessors.length - 1;
    }

    void addGroup(_Group gr, int material) {
      if (gr.pos.isEmpty) return;
      final p = addAccessor(gr.pos, withBounds: true);
      final n = addAccessor(gr.nrm);
      primitives.add({
        'attributes': {'POSITION': p, 'NORMAL': n},
        'material': material,
      });
    }

    addGroup(base, 0);
    addGroup(paths, 1);
    addGroup(places, 2);

    Map<String, dynamic> mat(List<double> c) => {
          'doubleSided': true,
          'pbrMetallicRoughness': {
            'baseColorFactor': [...c, 1.0],
            'metallicFactor': 0.0,
            'roughnessFactor': 0.8,
          },
        };

    final bytes = bb.toBytes();
    final gltf = {
      'asset': {'version': '2.0'},
      'scene': 0,
      'scenes': [
        {'nodes': [0]}
      ],
      'nodes': [
        {'mesh': 0}
      ],
      'meshes': [
        {'primitives': primitives}
      ],
      'materials': [
        mat([0.85, 0.85, 0.88]), // الأرضية
        mat([0.2, 0.8, 0.4]), // الممرات
        mat([0.2, 0.5, 0.9]), // الأماكن
      ],
      'buffers': [
        {
          'byteLength': bytes.length,
          'uri': 'data:application/octet-stream;base64,${base64Encode(bytes)}',
        }
      ],
      'bufferViews': bufferViews,
      'accessors': accessors,
    };
    return jsonEncode(gltf);
  }
}
