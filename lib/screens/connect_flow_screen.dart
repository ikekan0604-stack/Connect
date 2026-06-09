import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/mock_data.dart';
import '../models/user.dart';
import '../models/connection.dart';
import '../app_state.dart';

// Dummy users to "discover" during mock connect
final _dummyConnectUsers = [
  User(
    id: 'new1',
    name: '新田 あおい',
    emoji: '新',
    mbti: 'ENFP',
    hobbies: const ['写真', '旅行', 'カフェ'],
    age: 22,
    job: '学生',
    nodeColor: const Color(0xFFFFB3C6),
    activityScore: 70,
    isDirect: true,
  ),
  User(
    id: 'new2',
    name: '城 廉',
    emoji: '城',
    mbti: 'INTP',
    hobbies: const ['音楽', 'プログラミング'],
    age: 25,
    job: 'エンジニア',
    nodeColor: const Color(0xFFB3D4FF),
    activityScore: 65,
    isDirect: true,
  ),
  User(
    id: 'new3',
    name: '三浦 空',
    emoji: '三',
    mbti: 'ISTP',
    hobbies: const ['アウトドア', 'サイクリング'],
    age: 27,
    job: 'フリーランサー',
    nodeColor: const Color(0xFFB3FFD4),
    activityScore: 60,
    isDirect: true,
  ),
];

class ConnectFlowScreen extends StatefulWidget {
  final Function(User newUser, Connection conn)? onConnectionMade;

  const ConnectFlowScreen({super.key, this.onConnectionMade});

  @override
  State<ConnectFlowScreen> createState() => _ConnectFlowScreenState();
}

enum _FlowState { idle, scanning, loading, success, failure }

class _ConnectFlowScreenState extends State<ConnectFlowScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0; // 0 = myQR, 1 = scan
  _FlowState _flowState = _FlowState.idle;
  User? _connectedUser;
  late AnimationController _successAnim;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _successAnim.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  void _startFakeScan() {
    setState(() => _flowState = _FlowState.scanning);
    _scanTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _flowState = _FlowState.loading);
      _scanTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        _onScanSuccess();
      });
    });
  }

  void _onScanSuccess() {
    final existing = extraUsersNotifier.value.map((u) => u.id).toSet();
    final available = _dummyConnectUsers
        .where((u) =>
            !existing.contains(u.id) &&
            !mockDirectFriends.any((f) => f.id == u.id))
        .toList();

    if (available.isEmpty) {
      setState(() => _flowState = _FlowState.failure);
      return;
    }

    final rng = Random();
    final newUser = available[rng.nextInt(available.length)];
    final conn = Connection(
      userId1: 'self',
      userId2: newUser.id,
      level: RelationshipLevel.acquaintance,
    );

    setState(() {
      _flowState = _FlowState.success;
      _connectedUser = newUser;
    });
    _successAnim.forward();

    widget.onConnectionMade?.call(newUser, conn);
    addMockConnection(newUser, conn);
  }

  void _reset() {
    _successAnim.reset();
    setState(() {
      _flowState = _FlowState.idle;
      _connectedUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.ink.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.ink.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  'コネクト',
                  style: AppTheme.display(TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  )),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: AppTheme.textTertiary, size: 22),
                ),
              ],
            ),
          ),

          // Tab selector
          if (_flowState == _FlowState.idle ||
              _flowState == _FlowState.scanning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _TabBtn(
                    label: '自分のQRを見せる',
                    active: _tab == 0,
                    onTap: () {
                      setState(() {
                        _tab = 0;
                        _flowState = _FlowState.idle;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _TabBtn(
                    label: 'スキャンする',
                    active: _tab == 1,
                    onTap: () {
                      setState(() {
                        _tab = 1;
                        _flowState = _FlowState.idle;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_flowState) {
      _FlowState.idle || _FlowState.scanning => _tab == 0
          ? _MyQrTab()
          : _ScanTab(
              isScanning: _flowState == _FlowState.scanning,
              onScan: _startFakeScan,
            ),
      _FlowState.loading => const _LoadingView(),
      _FlowState.success => _SuccessView(
          user: _connectedUser!,
          anim: _successAnim,
          onDone: () => Navigator.pop(context),
          onAnother: _reset,
        ),
      _FlowState.failure => _FailureView(onRetry: _reset),
    };
  }
}

// ---- My QR tab ----

class _MyQrTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '相手にスキャンしてもらう',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.ink.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // User info header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent.withValues(alpha: 0.2),
                        border: Border.all(color: AppTheme.accent),
                      ),
                      child: const Center(
                        child: Text('✦', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selfUser.name,
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        Text(selfUser.mbti,
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // QR code
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(painter: _MyQrPainter()),
                ),
                const SizedBox(height: 16),
                Text(
                  'USER-SELF-CONNECT',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '相手のカメラで読み取ってもらうと\n対面でのコネクトが成立します',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---- Scan tab ----

class _ScanTab extends StatefulWidget {
  final bool isScanning;
  final VoidCallback onScan;

  const _ScanTab({required this.isScanning, required this.onScan});

  @override
  State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanlineAnim;

  @override
  void initState() {
    super.initState();
    _scanlineAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _scanlineAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            widget.isScanning ? 'スキャン中…' : '相手のQRをカメラに向ける',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          // Viewfinder
          Center(
            child: SizedBox(
              width: 240, height: 240,
              child: Stack(
                children: [
                  // Dark background
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  // Corner brackets
                  ..._corners(),
                  // Scanline
                  if (widget.isScanning)
                    AnimatedBuilder(
                      animation: _scanlineAnim,
                      builder: (_, __) {
                        final y = 20 + _scanlineAnim.value * 200;
                        return Positioned(
                          top: y, left: 20, right: 20, height: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppTheme.accent.withValues(alpha: 0.9),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  // Centre icon
                  if (!widget.isScanning)
                    Center(
                      child: Icon(
                        Icons.qr_code_scanner,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Mock scan button
          if (!widget.isScanning)
            GestureDetector(
              onTap: widget.onScan,
              child: Container(
                width: 200, height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'テスト: スキャン成功',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (widget.isScanning)
            const SizedBox(height: 52),
          const SizedBox(height: 20),
          if (!widget.isScanning)
            Text(
              '実際のアプリではカメラが起動し\nリアルタイムでQRを読み取ります',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  List<Widget> _corners() {
    const size = 28.0;
    const thick = 2.5;
    const padding = 12.0;
    return [
      // Top-left
      Positioned(
        top: padding, left: padding,
        child: _CornerBracket(size: size, thick: thick, flip: false, flipV: false),
      ),
      // Top-right
      Positioned(
        top: padding, right: padding,
        child: _CornerBracket(size: size, thick: thick, flip: true, flipV: false),
      ),
      // Bottom-left
      Positioned(
        bottom: padding, left: padding,
        child: _CornerBracket(size: size, thick: thick, flip: false, flipV: true),
      ),
      // Bottom-right
      Positioned(
        bottom: padding, right: padding,
        child: _CornerBracket(size: size, thick: thick, flip: true, flipV: true),
      ),
    ];
  }
}

class _CornerBracket extends StatelessWidget {
  final double size;
  final double thick;
  final bool flip;
  final bool flipV;

  const _CornerBracket({
    required this.size,
    required this.thick,
    required this.flip,
    required this.flipV,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scale(flip ? -1.0 : 1.0, flipV ? -1.0 : 1.0),
      child: SizedBox(
        width: size, height: size,
        child: CustomPaint(
          painter: _BracketPainter(thick: thick),
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final double thick;
  const _BracketPainter({required this.thick});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}

// ---- Flow state views ----

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(
              color: AppTheme.accent,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'コネクト中…',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '情報を交換しています',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final User user;
  final AnimationController anim;
  final VoidCallback onDone;
  final VoidCallback onAnother;

  const _SuccessView({
    required this.user,
    required this.anim,
    required this.onDone,
    required this.onAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success burst
            ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  border: Border.all(color: AppTheme.accent, width: 2),
                ),
                child: const Center(
                  child: Text('✦', style: TextStyle(fontSize: 36)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'コネクト成功！',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            // New user info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.ink.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: user.nodeColor.withValues(alpha: 0.3),
                      border: Border.all(
                          color: user.nodeColor.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Center(
                      child: Text(user.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text('${user.mbti} · ${user.job} · ${user.age}歳',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'マップに「顔見知り」として追加されました',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onAnother,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.ink.withValues(alpha: 0.2)),
                      ),
                      alignment: Alignment.center,
                      child: Text('続けてコネクト',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onDone,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('マップに戻る',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  final VoidCallback onRetry;
  const _FailureView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_wifi_off_outlined,
              color: AppTheme.textTertiary, size: 48),
          const SizedBox(height: 16),
          Text('コネクトできませんでした',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('もう一度試してください',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('やり直す',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Tab button ----

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.12)
                : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppTheme.accent : AppTheme.ink.withValues(alpha: 0.15),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ---- My QR painter ----

class _MyQrPainter extends CustomPainter {
  static const _data = [
    '11111110110110111111110',
    '10000010010100000010100',
    '10111010101011101010100',
    '10111010110111101010100',
    '10111010001001101010100',
    '10000010010011000010110',
    '11111110101010111111100',
    '00000000110100000000000',
    '11010101100110110101110',
    '01100010011001001100100',
    '10101101010101010110110',
    '00110010101100101100010',
    '11011101101001111011010',
    '00000000110000001001000',
    '11111110010101000110110',
    '10000010101011001011000',
    '10111010010011110001100',
    '10111010101100100101010',
    '10111010010001011101110',
    '10000010110010000001000',
    '11111110010110111111010',
    '00000000000000000000000',
    '00000000000000000000000',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final n = _data[0].length;
    final cellSize = size.width / n;
    final paint = Paint()..color = const Color(0xFF2A2A3A);
    for (int r = 0; r < _data.length; r++) {
      for (int c = 0; c < min(_data[r].length, n); c++) {
        if (_data[r][c] == '1') {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cellSize + 0.5, r * cellSize + 0.5,
                  cellSize - 1, cellSize - 1),
              const Radius.circular(0.8),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MyQrPainter old) => false;
}
