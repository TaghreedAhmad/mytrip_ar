import 'package:flutter/material.dart';
import 'arrow_plan.dart';
import 'pathfinder.dart';

/// معاينة المسار على الماك أو أي جهاز ما يدعم ARKit.
/// نفس نقاط المسار ونفس تباعد الأسهم، بدون كاميرا.
class PathPreview extends StatefulWidget {
  final List<MapNode> path;
  const PathPreview({super.key, required this.path});

  @override
  State<PathPreview> createState() => _PathPreviewState();
}

class _PathPreviewState extends State<PathPreview> {
  List<Offset> arrows = const [];
  String status = 'هالجهاز ما فيه ARKit. هذي معاينة للمسار، اضغط "ابدأ"';

  void placeArrows() {
    final planned = planArrowPositions(widget.path);
    setState(() {
      arrows = planned;
      status = planned.isEmpty
          ? 'المسار قصير جداً'
          : 'انحط ${planned.length} سهم على المسار. على الآيفون بتنحط قدام الكاميرا';
    });
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.path.last.name;
    return Scaffold(
      appBar: AppBar(title: Text('إلى: $dest')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.all(12),
            child: const Text(
              'ARKit يحتاج آيفون حقيقي موصول بالماك. هذي معاينة عشان تشوف المسار والأسهم قبل التجربة على الجوال.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: CustomPaint(
                  painter: _PathPainter(path: widget.path, arrows: arrows),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                Text(status, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: placeArrows,
                  icon: const Icon(Icons.navigation),
                  label: const Text('ابدأ'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<MapNode> path;
  final List<Offset> arrows;
  _PathPainter({required this.path, required this.arrows});

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    var minX = path.first.x;
    var maxX = path.first.x;
    var minY = path.first.y;
    var maxY = path.first.y;
    for (final n in path) {
      if (n.x < minX) minX = n.x;
      if (n.x > maxX) maxX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.y > maxY) maxY = n.y;
    }
    const pad = 36.0;
    final spanX = (maxX - minX).abs() < 1 ? 1.0 : (maxX - minX);
    final spanY = (maxY - minY).abs() < 1 ? 1.0 : (maxY - minY);
    final scale = ((size.width - pad * 2) / spanX) < ((size.height - pad * 2) / spanY)
        ? (size.width - pad * 2) / spanX
        : (size.height - pad * 2) / spanY;

    Offset map(double x, double y) => Offset(
          pad + (x - minX) * scale,
          size.height - pad - (y - minY) * scale,
        );

    final route = Path()..moveTo(map(path.first.x, path.first.y).dx, map(path.first.x, path.first.y).dy);
    for (final n in path.skip(1)) {
      final p = map(n.x, n.y);
      route.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFF1565C0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final nodePaint = Paint()..color = const Color(0xFF0D47A1);
    for (final n in path) {
      final p = map(n.x, n.y);
      canvas.drawCircle(p, 6, nodePaint);
      final tp = TextPainter(
        text: TextSpan(
          text: n.name,
          style: const TextStyle(color: Color(0xFF263238), fontSize: 11),
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 120);
      tp.paint(canvas, p + const Offset(8, -16));
    }

    final arrowPaint = Paint()..color = const Color(0xFF1B8A3E);
    for (final a in arrows) {
      canvas.drawCircle(map(a.dx, a.dy), 5, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.arrows != arrows;
}
