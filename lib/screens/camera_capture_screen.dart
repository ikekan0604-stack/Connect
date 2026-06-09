import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_state.dart';

class CameraCaptureScreen extends StatefulWidget {
  final List<String> participantIds;
  final List<String> participantNames;

  const CameraCaptureScreen({
    super.key,
    required this.participantIds,
    required this.participantNames,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

enum _CaptureState { viewfinder, countdown, preview, saved }

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with SingleTickerProviderStateMixin {
  _CaptureState _state = _CaptureState.viewfinder;
  int _countdown = 3;
  Timer? _countdownTimer;
  late AnimationController _savedAnim;

  final String _photo1 = 'https://picsum.photos/seed/cam-top/400/300';
  final String _photo2 = 'https://picsum.photos/seed/cam-bot/400/300';

  @override
  void initState() {
    super.initState();
    _savedAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _savedAnim.dispose();
    super.dispose();
  }

  void _pressShutter() {
    if (_state != _CaptureState.viewfinder) return;
    setState(() {
      _state = _CaptureState.countdown;
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        setState(() => _state = _CaptureState.preview);
      }
    });
  }

  void _save() {
    addMockPhotos(widget.participantIds);
    setState(() => _state = _CaptureState.saved);
    _savedAnim.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_state) {
        _CaptureState.viewfinder || _CaptureState.countdown => _buildViewfinder(),
        _CaptureState.preview => _buildPreview(),
        _CaptureState.saved => _buildSaved(),
      },
    );
  }

  Widget _buildViewfinder() {
    final h = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        // Top half — self camera
        Positioned(
          top: 0, left: 0, right: 0,
          height: h / 2,
          child: _CameraPlaceholder(
            label: '自分のカメラ',
            seed: 'cam-top-vf',
            color: Colors.grey.shade800,
          ),
        ),

        // Divider
        Positioned(
          top: h / 2 - 1, left: 0, right: 0,
          height: 2,
          child: Container(color: AppTheme.accent.withValues(alpha: 0.6)),
        ),

        // Bottom half — partner camera
        Positioned(
          top: h / 2, left: 0, right: 0,
          height: h / 2,
          child: _CameraPlaceholder(
            label: '${widget.participantNames.length > 1 ? widget.participantNames[1] : "相手"}のカメラ',
            seed: 'cam-bot-vf',
            color: Colors.grey.shade900,
          ),
        ),

        // Countdown overlay
        if (_state == _CaptureState.countdown)
          Center(
            child: Text(
              '$_countdown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 120,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

        // Shutter button
        if (_state == _CaptureState.viewfinder)
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Center(child: _ShutterButton(onPress: _pressShutter)),
          ),

        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ),

        // Participant chips
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: Row(
            children: widget.participantNames
                .take(4)
                .map((n) => _ParticipantChip(name: n))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final h = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        // Split preview
        Positioned(
          top: 0, left: 0, right: 0, height: h / 2,
          child: Image.network(_photo1, fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Container(color: Colors.grey.shade800)),
        ),
        Positioned(
          top: h / 2, left: 0, right: 0, height: h / 2,
          child: Image.network(_photo2, fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Container(color: Colors.grey.shade900)),
        ),

        // Divider line
        Positioned(
          top: h / 2 - 1, left: 0, right: 0, height: 2,
          child: Container(color: AppTheme.accent.withValues(alpha: 0.8)),
        ),

        // "1枚に合成" label at centre
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.8)),
            ),
            child: Text(
              '2枚を合成 ✦',
              style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),

        // Save / retake buttons
        Positioned(
          bottom: 40, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionBtn(
                label: '撮り直す',
                icon: Icons.replay,
                onTap: () => setState(() => _state = _CaptureState.viewfinder),
              ),
              const SizedBox(width: 24),
              _ActionBtn(
                label: '保存する',
                icon: Icons.check,
                primary: true,
                onTap: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaved() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _savedAnim, curve: Curves.elasticOut),
            child: const Text('✦', style: TextStyle(fontSize: 72, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Text(
            '保存しました',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '全員のノードに記録されました',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---- Small atoms ----

class _CameraPlaceholder extends StatelessWidget {
  final String label;
  final String seed;
  final Color color;

  const _CameraPlaceholder({
    required this.label,
    required this.seed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: color,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_outlined, color: Colors.white.withValues(alpha: 0.25), size: 48),
                const SizedBox(height: 8),
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
              ],
            ),
          ),
        ),
        // Viewfinder corner brackets
        Positioned(
          top: 20, left: 20,
          child: _Corner(flip: false),
        ),
        Positioned(
          top: 20, right: 20,
          child: _Corner(flip: true),
        ),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  final bool flip;
  const _Corner({required this.flip});

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: flip
          ? (Matrix4.identity()..scale(-1.0, 1.0))
          : Matrix4.identity(),
      child: SizedBox(
        width: 24, height: 24,
        child: CustomPaint(painter: _CornerPainter()),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback onPress;
  const _ShutterButton({required this.onPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPress,
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Center(
          child: Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  final String name;
  const _ParticipantChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(name,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    this.primary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          color: primary ? AppTheme.accent : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: primary ? AppTheme.accent : Colors.white.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: primary ? Colors.white : Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: primary ? Colors.white : Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
