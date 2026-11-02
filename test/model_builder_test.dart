import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytrip_ar/model_ar_screen.dart';
import 'package:mytrip_ar/model_builder.dart';
import 'package:mytrip_ar/pathfinder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('airport maquette for the passport region is a valid small glTF', () async {
    final graph = await AirportGraph.load();
    for (final id in kRegionIds) {
      expect(graph.nodes.containsKey(id), isTrue, reason: id);
    }

    final raw = AirportModelBuilder().build(graph, kRegionIds);
    final gltf = jsonDecode(raw) as Map<String, dynamic>;

    expect(gltf['asset']['version'], '2.0');
    final primitives = (gltf['meshes'] as List).first['primitives'] as List;
    expect(primitives, hasLength(3));

    final positions = (gltf['accessors'] as List)
        .where((accessor) => accessor['min'] != null)
        .toList();
    // أرضية، ثم ممرات المنطقة، ثم صندوق لكل مكان.
    expect(positions.map((accessor) => accessor['count']), [30, 150, 180]);

    final floor = (positions.first['max'] as List).cast<num>();
    final floorMin = (positions.first['min'] as List).cast<num>();
    for (final value in [...floor, ...floorMin]) {
      expect(value.abs(), lessThan(1));
    }
  });

  test('building a region with no known points fails', () async {
    final graph = await AirportGraph.load();
    expect(
      () => AirportModelBuilder().build(graph, {'missing'}),
      throwsA(isA<Exception>()),
    );
  });
}
