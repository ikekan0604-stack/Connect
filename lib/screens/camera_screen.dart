import 'package:flutter/material.dart';
import '../theme.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simulated camera feed (dark gradient)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 0.9,
                  colors: [Color(0xFF0D1A0D), Color(0xFF040804)],
                ),
              ),
            ),
          ),

          // Grid overlay (camera rule-of-thirds)
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          // Corner brackets (viewfinder)
          const Positioned(
            top: 120,
            left: 30,
            right: 30,
            bottom: 160,
            child: _ViewfinderBrackets(),
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TopButton(icon: Icons.flash_off_rounded),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline,
                          color: Colors.white60, size: 14),
                      const SizedBox(width: 5),
                      const Text(
                        'ルームに追加',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _TopButton(icon: Icons.flip_camera_ios_outlined),
              ],
            ),
          ),

          // Center scanning effect
          const Positioned.fill(child: _ScanEffect()),

          // Bottom controls
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Room members chips
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: const [
                      _RoomMemberChip(emoji: '🌟', name: '自分'),
                      _RoomMemberChip(emoji: '🎸', name: '田中'),
                      _RoomMemberChip(emoji: '🌸', name: '山田'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Shutter row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Last photo placeholder
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.photo_outlined,
                          color: Colors.white38, size: 22),
                    ),
                    const SizedBox(width: 32),
                    // Shutter button
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.black87, size: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Daily limit indicator
                    Column(
                      children: [
                        const Text(
                          '残り',
                          style: TextStyle(color: Colors.white38, fontSize: 9),
                        ),
                        const Text(
                          '3',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          '枚',
                          style: TextStyle(color: Colors.white38, fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Coming soon overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(0.0),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'カメラ機能は近日実装予定',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  const _TopButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black38,
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, color: Colors.white70, size: 18),
    );
  }
}

class _RoomMemberChip extends StatelessWidget {
  final String emoji;
  final String name;
  const _RoomMemberChip({required this.emoji, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(name,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ViewfinderBrackets extends StatelessWidget {
  const _ViewfinderBrackets();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BracketPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 0.5;
    canvas.drawLine(
        Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    // Top-left
    canvas.drawPath(
        Path()
          ..moveTo(0, len)
          ..lineTo(0, 0)
          ..lineTo(len, 0),
        paint);
    // Top-right
    canvas.drawPath(
        Path()
          ..moveTo(size.width - len, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, len),
        paint);
    // Bottom-left
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - len)
          ..lineTo(0, size.height)
          ..lineTo(len, size.height),
        paint);
    // Bottom-right
    canvas.drawPath(
        Path()
          ..moveTo(size.width - len, size.height)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width, size.height - len),
        paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ScanEffect extends StatefulWidget {
  const _ScanEffect();

  @override
  State<_ScanEffect> createState() => _ScanEffectState();
}

class _ScanEffectState extends State<_ScanEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return CustomPaint(
          painter: _ScanLinePainter(_anim.value),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.15 + size.height * 0.6 * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppTheme.accent.withOpacity(0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 1, size.width, 2));
    canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}
