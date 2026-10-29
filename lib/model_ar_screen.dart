// lib/model_ar_screen.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
import 'model_builder.dart';

/// الجزء اللي تبين تعرضينه: ضعي هنا معرّفات (id) من airport_map.json
const Set<String> kRegionIds = {'passport', 'desk', 'e_gate', 'fast_track', 'baggage', 'security'};

class ModelARScreen extends StatefulWidget {
  const ModelARScreen({super.key});

  @override
  State<ModelARScreen> createState() => _ModelARScreenState();
}

class _ModelARScreenState extends State<ModelARScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARNode? current;
  AirportGraph? graph;
  bool busy = false;
  String status = 'حرّكي الجوال ببطء على الأرض، ثم اضغطي "ماكيت"';

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  void _setStatus(String s) {
    debugPrint('[AR-MODEL] $s');
    if (mounted) setState(() => status = s);
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
  }

  Future<void> _remove() async {
    if (current != null) {
      await arObjectManager?.removeNode(current!);
      current = null;
    }
  }

  /// scale = 1 → ماكيت صغير (~1 متر)، scale = 100 → حجم حقيقي
  Future<void> _show(double scale) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final pose = await arSessionManager?.getCameraPose();
      if (pose == null) {
        _setStatus('الكاميرا مو جاهزة، حرّكي الجوال شوي وجربي');
        return;
      }

      // بناء الموديل وحفظه في مجلد التطبيق
      graph ??= await AirportGraph.load();
      final json = AirportModelBuilder().build(graph!, kRegionIds);
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/airport_model.gltf')
          .writeAsString(json, flush: true);

      await _remove();

      final cam = pose.getTranslation();
      final z = pose.getColumn(2);
      final fwd = vm.Vector2(-z.x, -z.z)..normalize();
      final right = vm.Vector2(-fwd.y, fwd.x);

      final real = scale > 1;
      final dist = real ? 6.0 : 1.0;
      final drop = real ? 1.4 : 0.8;
      final pos = vm.Vector2(cam.x, cam.z) + fwd * dist;
      // يدوّر الموديل ليتوافق مع اتجاه الكاميرا
      final yaw = atan2(-right.y, right.x);

      final node = ARNode(
        type: NodeType.fileSystemAppFolderGLTF2,
        uri: 'airport_model.gltf',
        scale: vm.Vector3(scale, scale, scale),
        position: vm.Vector3(pos.x, cam.y - drop, pos.y),
        eulerAngles: vm.Vector3(0, yaw, 0),
      );
      final ok = await arObjectManager?.addNode(node);
      debugPrint('[AR-MODEL] addNode => $ok');
      if (ok == true) {
        current = node;
        _setStatus(real
            ? 'انحط النموذج بحجم حقيقي قدامك'
            : 'انحط الماكيت قدامك، وجّهي الكاميرا للأرض أو الطاولة');
      } else {
        _setStatus('فشل تحميل النموذج (addNode رجع $ok)');
      }
    } catch (e) {
      _setStatus('صار خطأ: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نموذج المطار')),
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
                    ElevatedButton(
                      onPressed: busy ? null : () => _show(1),
                      child: const Text('ماكيت'),
                    ),
                    ElevatedButton(
                      onPressed: busy ? null : () => _show(100),
                      child: const Text('حجم حقيقي'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              await _remove();
                              _setStatus('تمت الإزالة');
                            },
                      style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white70),
                      child: const Text('إزالة'),
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
}
