import 'dart:async';

import 'package:camera/camera.dart';
import 'package:facial_liveness_verification/facial_liveness_verification.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/analytics/analytics_events.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';

/// Full-screen face liveness check.
///
/// [facial_liveness_verification] is a headless detector (ML Kit blink/smile
/// challenges + motion anti-spoofing) — it hands us a camera controller and a
/// state stream, and we own the UI. We render an oval face guide so the driver
/// aligns easily, drive the prompt from the state stream, and on a verified
/// session grab a still ourselves (the package returns no image) to use as the
/// KYC selfie + profile photo. Backing out or a failure returns null.
class LivenessCapturePage extends StatefulWidget {
  const LivenessCapturePage({super.key});

  @override
  State<LivenessCapturePage> createState() => _LivenessCapturePageState();
}

class _LivenessCapturePageState extends State<LivenessCapturePage> {
  LivenessDetector? _detector;
  StreamSubscription<LivenessState>? _sub;
  LivenessState? _state;

  bool _popped = false;
  bool _capturing = false;

  // One-shot analytics guards. A "started" fires when the detector first
  // comes up; a single "failed" per attempt avoids double-counting (e.g.
  // an error during a session that already emitted a non-verified result).
  bool _startedTracked = false;
  bool _failedTracked = false;

  void _trackFailed(String reason) {
    if (_failedTracked) return;
    _failedTracked = true;
    locator<MixpanelService>().track(
      AnalyticsEvents.livenessCheckFailed,
      properties: <String, dynamic>{'failure_reason': reason},
    );
  }

  // Failure surfaces handled by the fallback screen.
  bool _permissionDenied = false;
  bool _permanentlyDenied = false;
  bool _hadError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _permissionDenied = false;
      _hadError = false;
      _state = null;
    });

    final PermissionStatus status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
        _permanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
      });
      return;
    }

    try {
      final LivenessDetector detector = LivenessDetector(
        const LivenessConfig(
          challenges: <ChallengeType>[ChallengeType.blink, ChallengeType.smile],
          shuffleChallenges: false,
          // Smile was the step drivers got stuck on; ML Kit's smile
          // probability for a genuine smile sits well above this, so a lower
          // gate lets the step actually complete.
          smileThreshold: 0.4,
          challengeTimeout: Duration(seconds: 30),
        ),
      );
      await detector.initialize();
      _sub = detector.stateStream.listen(_onState);
      await detector.start();
      if (!mounted) {
        await detector.dispose();
        return;
      }
      if (!_startedTracked) {
        _startedTracked = true;
        locator<MixpanelService>().track(AnalyticsEvents.livenessCheckStarted);
      }
      setState(() => _detector = detector);
    } catch (_) {
      _trackFailed('init_error');
      if (mounted) setState(() => _hadError = true);
    }
  }

  void _onState(LivenessState s) {
    if (!mounted) return;
    setState(() => _state = s);
    if (s.type == LivenessStateType.completed) {
      if (s.result?.isVerified == true) {
        _capture();
      } else {
        _trackFailed('not_verified');
        setState(() => _hadError = true);
      }
    }
  }

  Future<void> _capture() async {
    if (_capturing || _popped) return;
    _capturing = true;
    if (mounted) setState(() {});
    try {
      final CameraController? c = _detector?.cameraController;
      // The detector stops its image stream before emitting `completed`, so a
      // still capture is allowed here.
      if (c == null || !c.value.isInitialized) {
        _finish(null);
        return;
      }
      final XFile photo = await c.takePicture();
      _finish(photo.path);
    } catch (_) {
      _finish(null);
    }
  }

  void _finish(String? path) {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop(path);
  }

  void _retry() {
    _sub?.cancel();
    _sub = null;
    final LivenessDetector? old = _detector;
    _detector = null;
    old?.dispose();
    _capturing = false;
    _startedTracked = false;
    _failedTracked = false;
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _detector?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _CameraProblem(
        title: 'Camera access needed',
        body: _permanentlyDenied
            ? 'Allow camera access in Settings, then come back to finish your face check.'
            : 'Drivio needs your camera for the face check. Allow access to continue.',
        primaryLabel: _permanentlyDenied ? 'Open settings' : 'Allow camera',
        onPrimary: _permanentlyDenied ? () => openAppSettings() : _retry,
        onClose: () => _finish(null),
      );
    }
    if (_hadError) {
      return _CameraProblem(
        title: "That didn't go through",
        body:
            "We couldn't confirm a live face. Make sure you're in good light, then try again.",
        primaryLabel: 'Try again',
        onPrimary: _retry,
        onClose: () => _finish(null),
      );
    }

    final CameraController? c = _detector?.cameraController;
    final bool ready = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        elevation: 0,
        foregroundColor: context.text,
        title: Text(
          'Face check',
          style: TextStyle(
            color: context.text,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        leading: BackButton(onPressed: () => _finish(null)),
      ),
      body: ready
          ? _OvalCameraView(controller: c, state: _state, capturing: _capturing)
          : Center(child: CircularProgressIndicator(color: context.accent)),
    );
  }
}

/// Camera preview revealed through an oval cutout with a coloured guide ring
/// and a live prompt, mirroring the oval-guide style we wanted.
class _OvalCameraView extends StatelessWidget {
  const _OvalCameraView({
    required this.controller,
    required this.state,
    required this.capturing,
  });

  final CameraController controller;
  final LivenessState? state;
  final bool capturing;

  bool get _good {
    switch (state?.type) {
      case LivenessStateType.positioned:
      case LivenessStateType.challengeInProgress:
      case LivenessStateType.challengeCompleted:
      case LivenessStateType.completed:
        return true;
      default:
        return false;
    }
  }

  String _prompt() {
    final LivenessState? s = state;
    if (s == null) return 'Bring your face into the oval';
    switch (s.type) {
      case LivenessStateType.initialized:
      case LivenessStateType.detecting:
      case LivenessStateType.noFace:
        return 'Bring your face into the oval';
      case LivenessStateType.faceDetected:
      case LivenessStateType.positioning:
        return s.message ?? 'Center your face in the oval';
      case LivenessStateType.positioned:
        return 'Hold still';
      case LivenessStateType.challengeInProgress:
        return _challengePrompt(s.currentChallenge);
      case LivenessStateType.challengeCompleted:
        return 'Nice!';
      case LivenessStateType.completed:
        return "You're verified. Saving…";
      case LivenessStateType.error:
        return s.message ?? "Let's try that again";
    }
  }

  String _challengePrompt(ChallengeType? c) {
    switch (c) {
      case ChallengeType.blink:
        return 'Blink your eyes';
      case ChallengeType.smile:
        return 'Give a little smile';
      case ChallengeType.turnLeft:
        return 'Turn your head left';
      case ChallengeType.turnRight:
        return 'Turn your head right';
      case ChallengeType.nod:
        return 'Nod your head';
      case ChallengeType.headShake:
        return 'Shake your head';
      case null:
        return 'Follow the prompt';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color ring = _good ? context.accent : Colors.white;
    final int total = state?.totalChallenges ?? 0;
    final int index = state?.challengeIndex ?? 0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final double ovalW = size.width * 0.72;
        final double ovalH = ovalW * 1.32;
        final Offset center = Offset(size.width / 2, size.height * 0.40);
        final Rect oval = Rect.fromCenter(
          center: center,
          width: ovalW,
          height: ovalH,
        );

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _coverPreview(context, size),
            IgnorePointer(
              child: CustomPaint(
                size: size,
                painter: _OvalScrimPainter(
                  oval: oval,
                  scrim: context.bg,
                  ring: ring,
                ),
              ),
            ),
            Positioned(
              top: center.dy + ovalH / 2 + 28,
              left: 24,
              right: 24,
              child: Column(
                children: <Widget>[
                  Text(
                    _prompt(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.copyWith(color: context.text),
                  ),
                  if (total > 0) ...<Widget>[
                    const SizedBox(height: 14),
                    _ProgressDots(
                      total: total,
                      done: index,
                      color: context.accent,
                      idle: context.borderStrong,
                    ),
                  ],
                ],
              ),
            ),
            if (capturing)
              Positioned.fill(
                child: ColoredBox(
                  color: context.bg.withValues(alpha: 0.4),
                  child: Center(
                    child: CircularProgressIndicator(color: context.accent),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Full-bleed, aspect-correct camera preview (BoxFit.cover equivalent).
  Widget _coverPreview(BuildContext context, Size size) {
    double scale = controller.value.aspectRatio * size.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

class _OvalScrimPainter extends CustomPainter {
  _OvalScrimPainter({
    required this.oval,
    required this.scrim,
    required this.ring,
  });

  final Rect oval;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    // Scrim everywhere except the oval, so the camera only shows inside it.
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, Paint()..color = scrim.withValues(alpha: 0.9));
    canvas.drawOval(oval, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_OvalScrimPainter old) =>
      old.oval != oval || old.ring != ring || old.scrim != scrim;
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.total,
    required this.done,
    required this.color,
    required this.idle,
  });

  final int total;
  final int done;
  final Color color;
  final Color idle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(total, (int i) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < done ? color : idle,
          ),
        );
      }),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onClose,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(DrivioIcons.camera, size: 40, color: context.textDim),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(color: context.text),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              ),
              const SizedBox(height: 20),
              DrivioButton(label: primaryLabel, onPressed: onPrimary),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onClose,
                child: Text(
                  'Not now',
                  style: TextStyle(color: context.textDim, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
