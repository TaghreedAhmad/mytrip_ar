// lib/ar_view_screen.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'pathfinder.dart';

// وضع التجربة: المسار كله ~10 أمتار
// للمطار الحقيقي: kScale = 1.0 و kSpacing = 2.0
const double kScale = 0.1;
const double kSpacing = 0.5;
const int kMaxArrows = 40;

// حجم السهم (كبّرناه من 0.4 إلى 1.0)
const double kArrowScale = 1.0;
// كم متر تحت الكاميرا ينحط السهم
const double kFloorOffset = 1.2;

class ARViewScreen extends StatefulWidget {
  final List<MapNode> path;
  const ARViewScreen({super.key, required this.path});

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  final List<ARNode> placed = [];
  bool busy = false;
  String status = 'حرّكي الجوال ببطء على الأرض شوي، ثم اضغطي "ابدأ"';

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  void _setStatus(String s) {
    debugPrint('[AR] $s');
    if (mounted) setState(() => status = s);
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.path.last.name;
    return Scaffold(
      appBar: AppBar(title: Text('إلى: $dest')),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
          ),
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black54,
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: busy ? null : placeArrows,
                      icon: const Icon(Icons.navigation),
                      label: const Text('ابدأ'),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : () => testNode(duck: false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white70,
                      ),
                      child: const Text('اختبار سهم'),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : () => testNode(duck: true),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white70,
                      ),
                      child: const Text('اختبار بطة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: true, // يظهر محاور الأصل، مفيد للتأكد إن AR شغال
      handleTaps: false,
    );
    arObjectManager!.onInitialize();
  }

  /// اتجاه الكاميرا على الأرض (أمام / يمين)
  ({vm.Vector3 cam, vm.Vector2 fwd, vm.Vector2 right})? _basis(
      vm.Matrix4? pose) {
    if (pose == null) return null;
    final cam = pose.getTranslation();
    final zAxis = pose.getColumn(2);
    final fwd = vm.Vector2(-zAxis.x, -zAxis.z);
    if (fwd.length == 0) return null;
    fwd.normalize();
    final right = vm.Vector2(-fwd.y, fwd.x);
    return (cam: cam, fwd: fwd, right: right);
  }

  /// اختبار: ينحط سهم (أو بطة) واحد قدامك بمتر ونص
  /// لو ظهرت البطة وما ظهر السهم: المشكلة في ملف arrow.gltf
  /// لو ما ظهرت ولا وحدة: المشكلة في التتبع أو المكتبة نفسها
  Future<void> testNode({required bool duck}) async {
    setState(() => busy = true);
    try {
      final pose = await arSessionManager?.getCameraPose();
      final b = _basis(pose);
      if (b == null) {
        _setStatus('الكاميرا مو جاهزة، حرّكي الجوال شوي وجربي');
        return;
      }

      final pos = vm.Vector2(b.cam.x, b.cam.z) + b.fwd * 1.5;
      final node = duck
          ? ARNode(
              type: NodeType.webGLB,
              uri:
                  'https://github.com/KhronosGroup/glTF-Sample-Models/raw/main/2.0/Duck/glTF-Binary/Duck.glb',
              scale: vm.Vector3(0.2, 0.2, 0.2),
              position: vm.Vector3(pos.x, b.cam.y - 1.0, pos.y),
            )
          : ARNode(
              type: NodeType.localGLTF2,
              uri: 'assets/arrow.gltf',
              scale: vm.Vector3(kArrowScale, kArrowScale, kArrowScale),
              position: vm.Vector3(pos.x, b.cam.y - 1.0, pos.y),
            );

      final ok = await arObjectManager?.addNode(node);
      debugPrint('[AR] test ${duck ? "duck" : "arrow"} addNode => $ok '
          'pos=(${pos.x}, ${b.cam.y - 1.0}, ${pos.y})');
      if (ok == true) {
        placed.add(node);
        _setStatus(
            'تم إضافة ${duck ? "البطة" : "السهم"}. وجّهي الكاميرا للأرض قدامك بمتر ونص.');
      } else {
        _setStatus('addNode رجع $ok، فشل تحميل ${duck ? "البطة" : "السهم"}');
      }
    } catch (e) {
      _setStatus('خطأ في الاختبار: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> placeArrows() async {
    final p = widget.path;
    if (p.length < 2) {
      _setStatus('المسار قصير جداً');
      return;
    }
    if (busy) return;
    setState(() => busy = true);

    try {
      final pose = await arSessionManager?.getCameraPose();
      final basis = _basis(pose);
      if (basis == null) {
        _setStatus('الكاميرا مو جاهزة، حرك الجهاز شوي وجرب');
        return;
      }

      for (final n in placed) {
        await arObjectManager?.removeNode(n);
      }
      placed.clear();

      final cam = basis.cam;
      final fwd = basis.fwd;
      final right = basis.right;

      final start = vm.Vector2(p.first.x, p.first.y);
      final mapFwd = vm.Vector2(p[1].x - p[0].x, p[1].y - p[0].y)..normalize();
      final mapRight = vm.Vector2(-mapFwd.y, mapFwd.x);

      vm.Vector2 toWorld(double mx, double my) {
        final d = (vm.Vector2(mx, my) - start) * kScale;
        final a = d.dot(mapRight);
        final b = d.dot(mapFwd);
        return vm.Vector2(cam.x, cam.z) + right * a + fwd * b;
      }

      // المسافة تراكمية على طول المسار كله (مو تبدأ من الصفر عند كل مقطع)
      double travelled = 0;
      double next = kSpacing;
      int failed = 0;

      for (int i = 0; i < p.length - 1 && placed.length < kMaxArrows; i++) {
        final a = toWorld(p[i].x, p[i].y);
        final b = toWorld(p[i + 1].x, p[i + 1].y);
        final seg = b - a;
        final len = seg.length;
        if (len == 0) continue;
        final dir = seg / len;
        final yaw = atan2(-dir.x, -dir.y);

        while (next <= travelled + len && placed.length < kMaxArrows) {
          final pos = a + dir * (next - travelled);
          final node = ARNode(
            type: NodeType.localGLTF2,
            uri: 'assets/arrow.gltf',
            scale: vm.Vector3(kArrowScale, kArrowScale, kArrowScale),
            position: vm.Vector3(pos.x, cam.y - kFloorOffset, pos.y),
            eulerAngles: vm.Vector3(0, yaw, 0),
          );
          final ok = await arObjectManager?.addNode(node);
          debugPrint('[AR] arrow ${placed.length} addNode => $ok '
              'pos=(${pos.x.toStringAsFixed(2)}, '
              '${(cam.y - kFloorOffset).toStringAsFixed(2)}, '
              '${pos.y.toStringAsFixed(2)}) yaw=${yaw.toStringAsFixed(2)}');
          if (ok == true) {
            placed.add(node);
          } else {
            failed++;
          }
          next += kSpacing;
        }
        travelled += len;
      }

      if (placed.isEmpty) {
        _setStatus('ما انحطت أسهم ($failed فشلت). جربي زر "اختبار سهم".');
      } else {
        _setStatus(
            'انحط ${placed.length} سهم ($failed فشلت). انزلي بالكاميرا للأرض 👇');
      }
    } catch (e) {
      _setStatus('صار خطأ: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
