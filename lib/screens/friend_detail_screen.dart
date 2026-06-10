import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/connection.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../color_profiles.dart';
import '../app_state.dart';
import 'photo_collage_screen.dart';

/// Full-screen profile for DIRECT friends: the existing profile layout on
/// top, and a static collage preview below. Tapping the preview opens the
/// full collage screen (view + edit).
class FriendDetailScreen extends StatefulWidget {
  final User user;

  const FriendDetailScreen({super.key, required this.user});

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  void _openCollage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoCollageScreen(user: widget.user),
      ),
    );
    // Re-render the preview with any edits made in the collage
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = activeProfile;
    final conn = selfConnection(widget.user.id);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Paper backdrop with static dot grid
          Positioned.fill(
            child: CustomPaint(painter: _DetailBackdropPainter(palette)),
          ),

          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topPad + 56, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Profile header (same構成 as the profile sheet) ──
                Center(child: _ProfileHeader(user: widget.user, conn: conn)),
                const SizedBox(height: 18),
                Divider(color: AppTheme.ink.withValues(alpha: 0.06), height: 1),
                const SizedBox(height: 16),
                _StatsRow(user: widget.user),
                const SizedBox(height: 18),
                Text(
                  'INTERESTS',
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: 0.40),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.user.hobbies
                      .map((h) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.ink.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      AppTheme.ink.withValues(alpha: 0.10)),
                            ),
                            child: Text(
                              h,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),

                // ── Collage preview ──
                Row(
                  children: [
                    Text(
                      'COLLAGE',
                      style: TextStyle(
                        color: AppTheme.ink.withValues(alpha: 0.40),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('✦',
                        style: TextStyle(
                            color: AppTheme.accent.withValues(alpha: 0.7),
                            fontSize: 10)),
                    const Spacer(),
                    Text(
                      'タップで全画面',
                      style: TextStyle(
                        color: AppTheme.ink.withValues(alpha: 0.35),
                        fontSize: 10,
                        fontFamily: AppTheme.bodyFamily,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openCollage,
                  child: _CollagePreviewCard(user: widget.user),
                ),
              ],
            ),
          ),

          // ── Back button ──
          Positioned(
            top: topPad + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppTheme.ink.withValues(alpha: 0.2)),
                ),
                child: Icon(Icons.arrow_back_ios_new,
                    size: 16, color: AppTheme.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======= Profile header (mirrors ProfileBottomSheet's _Header) =======

class _ProfileHeader extends StatelessWidget {
  final User user;
  final Connection? conn;

  const _ProfileHeader({required this.user, required this.conn});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: user.nodeColor.withValues(alpha: 0.55),
            border: Border.all(
              color: AppTheme.ink.withValues(alpha: 0.55),
              width: 1.6,
            ),
          ),
          alignment: Alignment.center,
          child: user.imageUrl != null && user.imageUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    user.imageUrl!,
                    width: 64, height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(
                      user.emoji,
                      style: TextStyle(fontSize: 28, color: AppTheme.ink),
                    ),
                  ),
                )
              : Text(
                  user.emoji,
                  style: TextStyle(fontSize: 28, color: AppTheme.ink),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          user.name,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        if (conn != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(5, (i) {
                final filled = i < conn!.level.numericLevel;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? AppTheme.accent
                          : AppTheme.ink.withValues(alpha: 0.18),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                conn!.level.label,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final User user;
  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.ink.withValues(alpha: 0.35),
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
    Widget sep() => Container(
          width: 1, height: 18,
          color: AppTheme.ink.withValues(alpha: 0.08),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        cell('MBTI', user.mbti),
        sep(),
        cell('age', '${user.age}'),
        sep(),
        cell('job', user.job),
      ],
    );
  }
}

// ======= Static collage preview =======

class _CollagePreviewCard extends StatelessWidget {
  final User user;
  const _CollagePreviewCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final palette = activeProfile;
    final design = collageDesigns[user.id];
    final photos = buildCollagePhotoItems(user);

    return AspectRatio(
      aspectRatio: 0.74,
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        // The clustered layout spans roughly ±260 incl. photo halves
        final k = w / 520.0;
        final center = Offset(w / 2, h / 2);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: palette.inkLine.withValues(alpha: 0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Background tint or paper
                Positioned.fill(
                  child: Container(
                    color: design?.bgColor ?? palette.background,
                  ),
                ),
                // Mini dot grid
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MiniGridPainter(palette: palette, gap: 14),
                  ),
                ),
                // Photos (static minis)
                ...photos.map((p) {
                  final pos = center + p.pos * k;
                  final s = p.size * k;
                  return Positioned(
                    left: pos.dx - s / 2,
                    top: pos.dy - s / 2,
                    width: s,
                    height: s,
                    child: Transform.rotate(
                      angle: p.rotation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: palette.inkLine.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        padding: const EdgeInsets.all(1.5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: p.photo.thumbnailUrl != null
                              ? Image.network(
                                  p.photo.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: palette.paperLow),
                                )
                              : Container(color: palette.paperLow),
                        ),
                      ),
                    ),
                  );
                }),
                // Strokes
                if (design != null && design.strokes.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MiniStrokesPainter(
                          strokes: design.strokes, k: k, center: center),
                    ),
                  ),
                // Texts
                if (design != null)
                  ...design.texts.map((t) {
                    final pos = center + t.pos * k;
                    return Positioned(
                      left: pos.dx - 60,
                      top: pos.dy - 10,
                      width: 120,
                      height: 20,
                      child: Center(
                        child: Text(
                          t.text,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.display(TextStyle(
                            color: t.color,
                            fontSize: (17.0 * k * 2.2).clamp(6.0, 14.0),
                            fontWeight: FontWeight.w700,
                          )),
                        ),
                      ),
                    );
                  }),
                // Expand icon bottom-right
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: palette.inkLine.withValues(alpha: 0.35)),
                    ),
                    child: Icon(Icons.open_in_full,
                        size: 12, color: AppTheme.ink.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  final ColorProfile palette;
  final double gap;

  const _MiniGridPainter({required this.palette, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.ink.withValues(alpha: 0.07)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[];
    for (double y = gap / 2; y < size.height; y += gap) {
      for (double x = gap / 2; x < size.width; x += gap) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_MiniGridPainter old) => old.palette != palette;
}

class _MiniStrokesPainter extends CustomPainter {
  final List<CollageStroke> strokes;
  final double k;
  final Offset center;

  const _MiniStrokesPainter({
    required this.strokes,
    required this.k,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.length < 2) continue;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s.width * k * 2).clamp(0.6, 2.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(center.dx + s.points.first.dx * k,
            center.dy + s.points.first.dy * k);
      for (final p in s.points.skip(1)) {
        path.lineTo(center.dx + p.dx * k, center.dy + p.dy * k);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MiniStrokesPainter old) => true;
}

class _DetailBackdropPainter extends CustomPainter {
  final ColorProfile palette;

  const _DetailBackdropPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.background, palette.paperLow],
        ).createShader(full),
    );
    final paint = Paint()
      ..color = palette.ink.withValues(alpha: 0.06)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const gap = 26.0;
    final points = <Offset>[];
    for (double y = 0; y < size.height; y += gap) {
      for (double x = 0; x < size.width; x += gap) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_DetailBackdropPainter old) => old.palette != palette;
}
