import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/photo.dart';
import '../theme.dart';
import '../app_state.dart';

class PhotoCollageScreen extends StatefulWidget {
  final User user;

  const PhotoCollageScreen({super.key, required this.user});

  @override
  State<PhotoCollageScreen> createState() => _PhotoCollageScreenState();
}

class _PhotoCollageScreenState extends State<PhotoCollageScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterAnim;
  int? _expandedIdx;

  @override
  void initState() {
    super.initState();
    _enterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _enterAnim.dispose();
    super.dispose();
  }

  List<MockPhoto> _getPhotos() {
    final saved = userPhotosNotifier.value[widget.user.id] ?? [];
    if (saved.isNotEmpty) return saved.reversed.toList();
    // Generate deterministic dummy photos for this user
    return List.generate(8, (i) {
      final seed = '${widget.user.id}-photo-$i';
      return MockPhoto(
        id: seed,
        thumbnailUrl: 'https://picsum.photos/seed/$seed/300/300',
        participantIds: ['self', widget.user.id],
        takenAt: DateTime.now().subtract(Duration(days: i * 14 + 3)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final photos = _getPhotos();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Collage canvas
          GestureDetector(
            onTap: () => setState(() => _expandedIdx = null),
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _enterAnim,
                builder: (_, __) => CustomPaint(
                  painter: _CollagePainter(
                    user: widget.user,
                    photos: photos,
                    t: _enterAnim.value,
                    centerX: size.width / 2,
                    centerY: size.height / 2,
                  ),
                ),
              ),
            ),
          ),

          // Photo tiles (interactive layer)
          ..._buildPhotoTiles(photos, size),

          // Expanded photo overlay
          if (_expandedIdx != null && _expandedIdx! < photos.length)
            _ExpandedPhoto(
              photo: photos[_expandedIdx!],
              onClose: () => setState(() => _expandedIdx = null),
            ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.ink.withValues(alpha: 0.2)),
                ),
                child: Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.ink),
              ),
            ),
          ),

          // User name header
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0, right: 0,
            child: Center(
              child: Text(
                widget.user.name,
                style: AppTheme.display(TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
              ),
            ),
          ),

          // Hint text at bottom
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0, right: 0,
            child: Center(
              child: Text(
                '写真をタップで拡大 · 新しいほど中心近く',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPhotoTiles(List<MockPhoto> photos, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final tiles = <Widget>[];

    for (int i = 0; i < photos.length; i++) {
      final result = _photoPosition(i, photos.length, cx, cy);
      final x = result.$1;
      final y = result.$2;
      final photoSize = result.$3;
      final rotation = result.$4;

      tiles.add(
        AnimatedBuilder(
          animation: _enterAnim,
          builder: (_, __) {
            final t = (_enterAnim.value - i * 0.08).clamp(0.0, 1.0);
            final eased = Curves.easeOutBack.transform(t);
            return Positioned(
              left: x - photoSize / 2,
              top: y - photoSize / 2,
              width: photoSize,
              height: photoSize,
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: eased,
                  child: GestureDetector(
                    onTap: () => setState(() => _expandedIdx = i),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.surface,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.ink.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: photos[i].thumbnailUrl != null
                            ? Image.network(
                                photos[i].thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _PhotoPlaceholder(index: i),
                              )
                            : _PhotoPlaceholder(index: i),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return tiles;
  }

  static (double, double, double, double) _photoPosition(
      int i, int total, double cx, double cy) {
    // Spiral layout: newer (lower i) = closer to center
    final angle = i * 2.4 + 0.5; // golden-ish angle
    final baseRadius = 90.0 + i * 32.0;
    final x = cx + cos(angle) * baseRadius;
    final y = cy + sin(angle) * baseRadius * 0.85;
    final photoSize = (80.0 - i * 3.0).clamp(48.0, 80.0);
    final rotation = (i % 3 - 1) * 0.08;
    return (x, y, photoSize, rotation);
  }
}

class _CollagePainter extends CustomPainter {
  final User user;
  final List<MockPhoto> photos;
  final double t;
  final double centerX;
  final double centerY;

  const _CollagePainter({
    required this.user,
    required this.photos,
    required this.t,
    required this.centerX,
    required this.centerY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle spiral guide lines
    final guidePaint = Paint()
      ..color = const Color(0x0F3B4FE8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int ring = 1; ring <= 4; ring++) {
      final r = 70.0 + ring * 40.0;
      canvas.drawCircle(Offset(centerX, centerY), r * t, guidePaint);
    }

    // Center node circle
    final nodePaint = Paint()
      ..color = user.nodeColor.withValues(alpha: 0.35 * t);
    canvas.drawCircle(Offset(centerX, centerY), 36 * t, nodePaint);

    final rimPaint = Paint()
      ..color = user.nodeColor.withValues(alpha: 0.7 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(centerX, centerY), 36 * t, rimPaint);

    // User emoji/name at center
    final tp = TextPainter(
      text: TextSpan(
        text: user.emoji,
        style: TextStyle(
          fontSize: 28 * t,
          color: const Color(0xFF3B4FE8).withValues(alpha: t),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, centerY - tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(_CollagePainter old) =>
      old.t != t || old.user != user;
}

class _PhotoPlaceholder extends StatelessWidget {
  final int index;
  const _PhotoPlaceholder({required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFE8D5C4),
      const Color(0xFFD4E8D5),
      const Color(0xFFD5D4E8),
      const Color(0xFFE8D5D4),
    ];
    return Container(
      color: colors[index % colors.length],
      child: Center(
        child: Icon(Icons.image_outlined,
            color: Colors.grey.shade500, size: 24),
      ),
    );
  }
}

class _ExpandedPhoto extends StatelessWidget {
  final MockPhoto photo;
  final VoidCallback onClose;

  const _ExpandedPhoto({required this.photo, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photo.thumbnailUrl != null
                  ? Image.network(
                      photo.thumbnailUrl!,
                      width: 280, height: 280,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 280, height: 280,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.image, color: Colors.white, size: 48),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              _formatDate(photo.takenAt),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}年${dt.month}月${dt.day}日';
  }
}
