import 'dart:math';
import 'dart:ui';

import 'pathfinder.dart';

// وضع التجربة: المسار كله ~10 أمتار
// للمطار الحقيقي: kScale = 1.0 و kSpacing = 2.0
const double kScale = 0.1;
const double kSpacing = 0.5;
const int kMaxArrows = 40;

// طول نموذج السهم 1م. الإضافة على iOS تصغّر النماذج المحلية ×0.01،
// فالقيمة 30 تعطيه طولاً 30سم وعرضاً 18سم: واضح من الجوال وأقصر من المسافة بين الأسهم.
const double kArrowScale = 30;

/// مواقع الأسهم على خريطة المطار، بنفس تباعد شاشة الواقع المعزز.
List<Offset> planArrowPositions(List<MapNode> path) {
  final arrows = <Offset>[];
  if (path.length < 2) return arrows;

  double travelled = 0;
  double next = kSpacing;
  for (var i = 0; i < path.length - 1 && arrows.length < kMaxArrows; i++) {
    final dx = (path[i + 1].x - path[i].x) * kScale;
    final dy = (path[i + 1].y - path[i].y) * kScale;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) continue;
    while (next <= travelled + len && arrows.length < kMaxArrows) {
      final t = (next - travelled) / len;
      arrows.add(Offset(
        path[i].x + (path[i + 1].x - path[i].x) * t,
        path[i].y + (path[i + 1].y - path[i].y) * t,
      ));
      next += kSpacing;
    }
    travelled += len;
  }
  return arrows;
}
