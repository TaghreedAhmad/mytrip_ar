// lib/ar_view_screen.dart
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'arrow_plan.dart';
import 'path_preview.dart';
import 'pathfinder.dart';

/// ARKit و ARCore يشتغلون على جوال حقيقي فقط.
bool get deviceSupportsAr =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

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
  String status = 'اسمح بالكاميرا، حرّك الجوال ببطء، ثم اضغط "ابدأ"';

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  void _setStatus(String s) {
    if (mounted) setState(() => status = s);
  }

  @override
  Widget build(BuildContext context) {
    if (!deviceSupportsAr) {
      return PathPreview(path: widget.path);
    }
    final dest = widget.path.last.name;
    return Scaffold(
      appBar: AppBar(title: Text('إلى: $dest')),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
            permissionPromptDescription:
                'لازم تسمح للكاميرا عشان الأسهم تظهر قدامك',
            permissionPromptButtonText: 'السماح بالكاميرا',
            permissionPromptParentalRestriction:
                'الكاميرا مقفلة من إعدادات الجهاز',
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
                ElevatedButton.icon(
                  onPressed: busy ? null : placeArrows,
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
      showWorldOrigin: false,
      handleTaps: false,
    );
    arObjectManager!.onInitialize();
    _setStatus('حرّك الجوال ببطء لين تثبت الصورة، ثم اضغط "ابدأ"');
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
      if (arSessionManager == null) {
        _setStatus('اسمح بالكاميرا أولاً من الزر في وسط الشاشة');
        return;
      }

      vm.Matrix4? pose;
      for (var attempt = 0; attempt < 20; attempt++) {
        pose = await arSessionManager!.getCameraPose();
        if (pose != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (pose == null) {
        _setStatus('الكاميرا مو جاهزة، حرك الجهاز شوي وجرب');
        return;
      }

      for (final n in placed) {
        await arObjectManager?.removeNode(n);
      }
      placed.clear();

      final cam = pose.getTranslation();
      final zAxis = pose.getColumn(2);
      final fwd = vm.Vector2(-zAxis.x, -zAxis.z)..normalize();
      final right = vm.Vector2(-fwd.y, fwd.x);

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
            scale: vm.Vector3(0.4, 0.4, 0.4),
            position: vm.Vector3(pos.x, cam.y - 1.2, pos.y),
            eulerAngles: vm.Vector3(0, yaw, 0),
          );
          final ok = await arObjectManager?.addNode(node);
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
        _setStatus('ما انحطت أسهم ($failed فشلت). تأكد من ملف السهم.');
      } else {
        _setStatus('انحط ${placed.length} سهم، ماشي ورا الأسهم 👇');
      }
    } catch (e) {
      _setStatus('صار خطأ: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
