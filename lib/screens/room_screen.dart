import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/mock_data.dart';
import '../models/user.dart';
import 'camera_capture_screen.dart';

class RoomScreen extends StatefulWidget {
  final User creator;

  const RoomScreen({super.key, required this.creator});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late List<User> _members;
  bool _showRoomQr = false;

  @override
  void initState() {
    super.initState();
    _members = [selfUser, widget.creator];
  }

  void _addMockMember() {
    final available = mockDirectFriends
        .where((u) => !_members.any((m) => m.id == u.id))
        .toList();
    if (available.isEmpty) return;
    final rng = Random();
    setState(() => _members.add(available[rng.nextInt(available.length)]));
  }

  void _startCapture() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(
          participantIds: _members.map((u) => u.id).toList(),
          participantNames: _members.map((u) => u.name).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: top),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios, color: AppTheme.ink, size: 18),
                    ),
                    Expanded(
                      child: Text(
                        'ルーム',
                        style: AppTheme.display(TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        )),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Room QR toggle
                    GestureDetector(
                      onTap: () => setState(() => _showRoomQr = !_showRoomQr),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _showRoomQr
                              ? AppTheme.accent.withValues(alpha: 0.15)
                              : AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _showRoomQr
                                ? AppTheme.accent
                                : AppTheme.ink.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(Icons.qr_code,
                            size: 18,
                            color: _showRoomQr ? AppTheme.accent : AppTheme.ink),
                      ),
                    ),
                  ],
                ),
              ),

              // Room QR panel (expandable)
              if (_showRoomQr)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.ink.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'このQRをスキャンしてルームに参加',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CustomPaint(painter: _QrPainter()),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ROOM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Members header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Text(
                      '参加者 ${_members.length}人',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (_members.length < 2)
                      Text(
                        '最初の2人がカメラ担当',
                        style: TextStyle(
                          color: AppTheme.accent.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),

              // Member list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _members.length,
                  itemBuilder: (_, i) => _MemberTile(
                    user: _members[i],
                    isCameraHolder: i < 2,
                    isCreator: i == 0,
                  ),
                ),
              ),

              // Bottom action bar
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Add member button
                      Expanded(
                        child: GestureDetector(
                          onTap: _addMockMember,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.ink.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add_outlined,
                                    size: 18, color: AppTheme.ink),
                                const SizedBox(width: 8),
                                Text('追加 (テスト)',
                                    style: TextStyle(
                                        color: AppTheme.ink, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Start capture button
                      GestureDetector(
                        onTap: _startCapture,
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.camera_alt, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('撮影開始',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final User user;
  final bool isCameraHolder;
  final bool isCreator;

  const _MemberTile({
    required this.user,
    this.isCameraHolder = false,
    this.isCreator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCameraHolder
              ? AppTheme.accent.withValues(alpha: 0.3)
              : AppTheme.ink.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: user.nodeColor.withValues(alpha: 0.35),
              border: Border.all(
                color: user.nodeColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              user.emoji,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user.mbti,
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isCreator)
            _Badge(label: 'ホスト', color: AppTheme.accent),
          if (isCameraHolder && !isCreator)
            _Badge(label: 'カメラ', color: AppTheme.ink.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

/// Simple QR-code-like pattern drawn with CustomPainter.
class _QrPainter extends CustomPainter {
  // Hard-coded 21×21 bit pattern (simplified QR-like, not a real QR).
  static const _pattern = [
    '1111111011001011111111',
    '1000001001010100000101',
    '1011101010101101110101',
    '1011101011011101110101',
    '1011101000100101110101',
    '1000001001001100000101',
    '1111111010101011111101',
    '0000000011010000000000',
    '1101010110011011010111',
    '0110001001100100110010',
    '1010110101010101011011',
    '0011001010110010110001',
    '1101110110100111101101',
    '0000000011000000100100',
    '1111111001010100011011',
    '1000001010101100101100',
    '1011101001001111000110',
    '1011101010110010010101',
    '1011101001000101110111',
    '1000001011001000000100',
    '1111111001011011111101',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / _pattern[0].length;
    final paint = Paint()..color = const Color(0xFF2C2C2C);
    for (int row = 0; row < _pattern.length; row++) {
      for (int col = 0; col < _pattern[row].length; col++) {
        if (_pattern[row][col] == '1') {
          canvas.drawRect(
            Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => false;
}
