import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/fittech_theme.dart';

class ExercisePoseMonitorMobileScreen extends StatefulWidget {
  final String exerciseName;
  final String bodyPart;
  final String target;

  const ExercisePoseMonitorMobileScreen({
    super.key,
    required this.exerciseName,
    required this.bodyPart,
    required this.target,
  });

  @override
  State<ExercisePoseMonitorMobileScreen> createState() =>
      _ExercisePoseMonitorMobileScreenState();
}

class _ExercisePoseMonitorMobileScreenState
    extends State<ExercisePoseMonitorMobileScreen> {
  CameraController? _cameraController;
  late final PoseDetector _poseDetector;
  bool _isInitializing = true;
  bool _isProcessing = false;
  String? _errorMessage;
  Pose? _currentPose;
  Size? _inputImageSize;
  bool _isFrontCamera = true;
  int _repCount = 0;
  _RepPhase _repPhase = _RepPhase.start;
  String _feedback = 'Position your full body inside the frame.';

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    unawaited(_cameraController?.dispose());
    _poseDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'Camera pose monitoring is available on Android and iPhone only.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'No camera was found on this device.';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _isFrontCamera =
          selectedCamera.lensDirection == CameraLensDirection.front;

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await controller.startImageStream(_processCameraImage);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'Could not start pose monitoring. Please allow camera access and try again.';
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || !mounted || _cameraController == null) return;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;

    _isProcessing = true;

    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (!mounted) return;

      final pose = poses.isEmpty ? null : poses.first;
      final result = _buildFeedback(pose);

      setState(() {
        _currentPose = pose;
        _inputImageSize = Size(image.width.toDouble(), image.height.toDouble());
        _feedback = result.feedback;
        _repPhase = result.phase;
        if (result.incrementRep) {
          _repCount += 1;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedback = 'Pose could not be processed. Adjust lighting and framing.';
      });
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) return null;

    final camera = controller.description;
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid && format != InputImageFormat.nv21) {
      return null;
    }
    if (Platform.isIOS && format != InputImageFormat.bgra8888) {
      return null;
    }

    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  _PoseFeedback _buildFeedback(Pose? pose) {
    if (pose == null) {
      return _PoseFeedback(
        feedback:
            'No person detected. Step back so your whole body is visible.',
        phase: _repPhase,
      );
    }

    final bodyPart = widget.bodyPart.toLowerCase();

    if (bodyPart.contains('legs')) {
      return _analyzeLowerBody(pose);
    }

    if (bodyPart.contains('back')) {
      return _analyzeUpperBody(pose, focus: 'back');
    }

    return _analyzeUpperBody(pose, focus: 'upper');
  }

  _PoseFeedback _analyzeLowerBody(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if ([leftHip, leftKnee, leftAnkle, rightHip, rightKnee, rightAnkle]
        .contains(null)) {
      return _PoseFeedback(
        feedback: 'Keep your hips, knees, and ankles visible to track the rep.',
        phase: _repPhase,
      );
    }

    final leftAngle = _angle(leftHip!, leftKnee!, leftAnkle!);
    final rightAngle = _angle(rightHip!, rightKnee!, rightAnkle!);
    final kneeAngle = (leftAngle + rightAngle) / 2;

    var nextPhase = _repPhase;
    var incrementRep = false;
    String feedback;

    if (kneeAngle < 105) {
      nextPhase = _RepPhase.down;
      feedback = 'Great depth. Drive through your heels to stand up.';
    } else if (kneeAngle > 155) {
      incrementRep = _repPhase == _RepPhase.down;
      nextPhase = _RepPhase.up;
      feedback = incrementRep
          ? 'Rep counted. Nice lockout.'
          : 'Stand tall, then lower into the next rep.';
    } else {
      feedback = 'Lower a bit more until your knees are bent deeply.';
    }

    return _PoseFeedback(
      feedback: feedback,
      phase: nextPhase,
      incrementRep: incrementRep,
    );
  }

  _PoseFeedback _analyzeUpperBody(Pose pose, {required String focus}) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if ([
      leftShoulder,
      leftElbow,
      leftWrist,
      rightShoulder,
      rightElbow,
      rightWrist,
    ].contains(null)) {
      return _PoseFeedback(
        feedback: 'Keep both shoulders, elbows, and wrists visible.',
        phase: _repPhase,
      );
    }

    final leftAngle = _angle(leftShoulder!, leftElbow!, leftWrist!);
    final rightAngle = _angle(rightShoulder!, rightElbow!, rightWrist!);
    final elbowAngle = (leftAngle + rightAngle) / 2;

    var nextPhase = _repPhase;
    var incrementRep = false;
    String feedback;

    if (elbowAngle < 85) {
      nextPhase = _RepPhase.down;
      feedback = focus == 'back'
          ? 'Strong pull. Squeeze your shoulder blades together.'
          : 'Nice depth. Keep your core tight and chest proud.';
    } else if (elbowAngle > 155) {
      incrementRep = _repPhase == _RepPhase.down;
      nextPhase = _RepPhase.up;
      feedback = incrementRep
          ? 'Rep counted. Reset and go again.'
          : 'Extend fully, then start the next rep.';
    } else {
      feedback = focus == 'back'
          ? 'Pull farther until your elbows bend more.'
          : 'Lower with control until your elbows bend more.';
    }

    return _PoseFeedback(
      feedback: feedback,
      phase: nextPhase,
      incrementRep: incrementRep,
    );
  }

  double _angle(PoseLandmark first, PoseLandmark mid, PoseLandmark last) {
    final radians = math.atan2(last.y - mid.y, last.x - mid.x) -
        math.atan2(first.y - mid.y, first.x - mid.x);
    final degrees = radians.abs() * 180 / math.pi;
    return degrees > 180 ? 360 - degrees : degrees;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.exerciseName),
      ),
      body: _isInitializing
          ? const Center(
              child: CircularProgressIndicator(color: FitColors.green),
            )
          : _errorMessage != null
              ? _PoseMonitorMessage(
                  icon: Icons.videocam_off_rounded,
                  title: 'Pose monitoring unavailable',
                  message: _errorMessage!,
                )
              : _cameraController == null ||
                      !_cameraController!.value.isInitialized
                  ? const _PoseMonitorMessage(
                      icon: Icons.camera_alt_outlined,
                      title: 'Camera not ready',
                      message: 'The camera could not be initialized.',
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(_cameraController!),
                                  if (_currentPose != null &&
                                      _inputImageSize != null)
                                    CustomPaint(
                                      painter: _PosePainter(
                                        pose: _currentPose!,
                                        imageSize: _inputImageSize!,
                                        isFrontCamera: _isFrontCamera,
                                      ),
                                    ),
                                  Positioned(
                                    top: 14,
                                    left: 14,
                                    right: 14,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _PoseMetricCard(
                                            label: 'Reps',
                                            value: '$_repCount',
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _PoseMetricCard(
                                            label: 'Target',
                                            value: _capitalize(widget.target),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    left: 14,
                                    right: 14,
                                    bottom: 14,
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.12),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _capitalize(widget.bodyPart),
                                            style: const TextStyle(
                                              color: FitColors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _feedback,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161E32),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How it works',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'The camera tracks your joints live, draws your pose skeleton, and estimates basic rep phases from elbow or knee angles. Keep your whole body visible for the best feedback.',
                                  style: TextStyle(
                                    color: FitColors.label,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _PoseMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _PoseMetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseMonitorMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PoseMonitorMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161E32),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: FitColors.green),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FitColors.label,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final bool isFrontCamera;

  const _PosePainter({
    required this.pose,
    required this.imageSize,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = FitColors.green
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0x88FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final joints = _jointPairs;
    for (final pair in joints) {
      final start = pose.landmarks[pair.$1];
      final end = pose.landmarks[pair.$2];
      if (start == null || end == null) continue;
      canvas.drawLine(
        _translate(start, size),
        _translate(end, size),
        linePaint,
      );
    }

    for (final landmark in pose.landmarks.values) {
      canvas.drawCircle(_translate(landmark, size), 4, pointPaint);
    }
  }

  Offset _translate(PoseLandmark landmark, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.height;
    final scaleY = canvasSize.height / imageSize.width;

    final translatedX = isFrontCamera
        ? canvasSize.width - landmark.y * scaleX
        : landmark.y * scaleX;
    final translatedY = landmark.x * scaleY;
    return Offset(translatedX, translatedY);
  }

  static final List<(PoseLandmarkType, PoseLandmarkType)> _jointPairs = [
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
  ];

  @override
  bool shouldRepaint(covariant _PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}

enum _RepPhase { start, down, up }

class _PoseFeedback {
  final String feedback;
  final _RepPhase phase;
  final bool incrementRep;

  const _PoseFeedback({
    required this.feedback,
    required this.phase,
    this.incrementRep = false,
  });
}

String _capitalize(String text) {
  if (text.isEmpty) return text;
  final value = text.replaceAll('-', ' ');
  return value[0].toUpperCase() + value.substring(1);
}
