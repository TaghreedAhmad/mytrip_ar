import 'package:flutter_test/flutter_test.dart';
import 'package:mytrip_ar/main.dart';
import 'package:mytrip_ar/pathfinder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shortest path reaches gate A8 from the entrance', () async {
    final graph = await AirportGraph.load();
    final path = graph.shortestPath('entrance', 'a8');

    expect(path, isNotNull);
    expect(path!.first.id, 'entrance');
    expect(path.last.id, 'a8');
    expect(path.length, greaterThan(2));
  });

  testWidgets('picking a destination opens the route preview', (tester) async {
    await tester.pumpWidget(const MyTripARApp());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('وين تبي تروح؟'), findsOneWidget);
    await tester.tap(find.text('Pick Up'));
    await tester.pumpAndSettle();

    expect(find.text('إلى: Pick Up'), findsOneWidget);
    await tester.tap(find.text('ابدأ'));
    await tester.pump();

    expect(find.textContaining('انحط 5 سهم'), findsOneWidget);
  });
}
