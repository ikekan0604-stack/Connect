import 'dart:math';
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/photo.dart';
import '../theme.dart';
import '../color_profiles.dart';
import '../app_state.dart';

// Kawaii pen / text colour palette (works across colour themes)
const kCollagePenColors = [
  Color(0xFF201D33), // indigo ink
  Color(0xFFE86B9A), // pink
  Color(0xFF6BC4A0), // mint
  Color(0xFF6B9BE8), // sky
  Color(0xFFE8B96B), // butter
];

// Cute paper tints for the collage background (null = default paper)
const kCollageBgTints = <Color?>[
  null,
  Color(0xFFFFF0F5), // sakura pink
  Color(0xFFEFF7EF), // mint cream
  Color(0xFFEFF3FB), // baby sky
  Color(0xFFFBF4E4), // butter paper
];

// Kawaii sticker set for the stamp tool
const kCollageStamps = ['💖', '✨', '🌸', '⭐', '🎀', '🍓', '🫧', '🌙'];

// Pen stroke widths (細 / 中 / 太)
const kCollagePenWidths = [1.8, 2.8, 4.6];

class CollagePhotoItem {
  final MockPhoto photo;
  Offset pos; // canvas coords, origin = screen center
  double size;
  final double rotation;

  CollagePhotoItem({
    required this.photo,
    required this.pos,
    required this.size,
    required this.rotation,
  });
}

/// Builds the photo set with its default scattered layout, then applies
/// any saved design overrides. Shared by the collage screen and the
/// friend-detail preview.
List<CollagePhotoItem> buildCollagePhotoItems(User user) {
  final saved = userPhotosNotifier.value[user.id] ?? [];
  final List<MockPhoto> photos;
  if (saved.isNotEmpty) {
    photos = List.of(saved);
  } else {
    photos = List.generate(8, (i) {
      final seed = '${user.id}-photo-$i';
      return MockPhoto(
        id: seed,
        thumbnailUrl: 'https://picsum.photos/seed/$seed/300/300',
        participantIds: ['self', user.id],
        takenAt: DateTime.now().subtract(Duration(days: i * 14 + 3)),
      );
    });
  }
  photos.sort((a, b) => a.takenAt.compareTo(b.takenAt));

  // Scrapbook-style packing: photos cluster around the middle, slightly
  // overlapping (≈30-40%), with stronger rotation — like a real collage.
  final rng = Random(user.id.hashCode);
  final placed = <CollagePhotoItem>[];
  for (int i = 0; i < photos.length; i++) {
    final photo = photos[i];
    final size = 96.0 + rng.nextDouble() * 52.0;
    Offset best = Offset.zero;
    double bestPenalty = double.infinity;
    for (int attempt = 0; attempt < 160; attempt++) {
      // Radius grows with index → dense core, looser fringe
      final r = rng.nextDouble() * (60.0 + i * 26.0);
      final th = rng.nextDouble() * 2 * pi;
      final cand = Offset(r * cos(th), r * sin(th) * 1.15);
      double penalty = 0;
      for (final other in placed) {
        final minDist = (size + other.size) / 2 * 0.62; // overlap allowed
        final d = (cand - other.pos).distance;
        if (d < minDist) penalty = max(penalty, minDist - d);
      }
      if (penalty < bestPenalty) {
        bestPenalty = penalty;
        best = cand;
        if (penalty == 0) break;
      }
    }
    placed.add(CollagePhotoItem(
      photo: photo,
      pos: best,
      size: size,
      rotation: (rng.nextDouble() - 0.5) * 0.30,
    ));
  }

  // Apply saved design overrides
  final design = collageDesigns[user.id];
  if (design != null) {
    for (final item in placed) {
      final p = design.photoPos[item.photo.id];
      if (p != null) item.pos = p;
      final s = design.photoSize[item.photo.id];
      if (s != null) item.size = s;
    }
  }
  return placed;
}

enum _EditTool { move, pen, eraser, stamp, bg }

/// Full-screen collage. Opened from the friend-detail screen (tap on the
/// preview) or by long-pressing a node on the map.
///
/// The friend's node (map-identical drawing) sits at the top as a header.
/// View mode: pan / zoom only. Edit mode (pencil FAB): move & resize
/// photos, add text and stickers, free-hand pen, eraser, background tint.
class PhotoCollageScreen extends StatefulWidget {
  final User user;

  const PhotoCollageScreen({super.key, required this.user});

  @override
  State<PhotoCollageScreen> createState() => _PhotoCollageScreenState();
}

class _PhotoCollageScreenState extends State<PhotoCollageScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _photoCtrl;
  late final List<CollagePhotoItem> _photos;
  late final CollageDesign _design;
  final _stampRng = Random();

  // Same as the map's _baseRadiusFor
  double get _nodeR => widget.user.isDirect ? 16.0 : 10.0;

  // Canvas transform
  double _scale = 1.0;
  Offset _pan = Offset.zero;

  // Canvas gesture state
  double _gestureStartScale = 1.0;
  Offset _gestureStartPan = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  // Edit state
  bool _editMode = false;
  _EditTool _tool = _EditTool.move;
  Color _penColor = kCollagePenColors[1];
  double _penWidth = kCollagePenWidths[1];
  CollageStroke? _activeStroke;

  @override
  void initState() {
    super.initState();
    _design = collageDesigns.putIfAbsent(widget.user.id, () => CollageDesign());
    _photos = buildCollagePhotoItems(widget.user);

    _photoCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 450 + 100 * max(_photos.length - 1, 0)),
    )..forward();
  }

  @override
  void dispose() {
    _photoCtrl.dispose();
    super.dispose();
  }

  void _persistPhoto(CollagePhotoItem item) {
    _design.photoPos[item.photo.id] = item.pos;
    _design.photoSize[item.photo.id] = item.size;
  }

  Offset _toCanvas(Offset screen) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    return (screen - center - _pan) / _scale;
  }

  // ---- Canvas gestures: pan / zoom, pen drawing, erasing ----

  void _onCanvasScaleStart(ScaleStartDetails d) {
    if (_editMode && d.pointerCount == 1) {
      if (_tool == _EditTool.pen) {
        _activeStroke = CollageStroke(
          color: _penColor,
          width: _penWidth,
          points: [_toCanvas(d.focalPoint)],
        );
        setState(() {});
        return;
      }
      if (_tool == _EditTool.eraser) {
        _eraseAt(_toCanvas(d.focalPoint));
        return;
      }
    }
    _gestureStartScale = _scale;
    _gestureStartPan = _pan;
    _gestureStartFocal = d.focalPoint;
  }

  void _onCanvasScaleUpdate(ScaleUpdateDetails d) {
    if (_activeStroke != null) {
      if (d.pointerCount == 1) {
        setState(() => _activeStroke!.points.add(_toCanvas(d.focalPoint)));
        return;
      }
      // Second finger landed: discard the stroke, treat as canvas gesture
      _activeStroke = null;
      _gestureStartScale = _scale;
      _gestureStartPan = _pan;
      _gestureStartFocal = d.focalPoint;
    }
    if (_editMode && _tool == _EditTool.eraser && d.pointerCount == 1) {
      _eraseAt(_toCanvas(d.focalPoint));
      return;
    }
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    final newScale = (_gestureStartScale * d.scale).clamp(0.4, 3.0);
    final canvasPoint =
        (_gestureStartFocal - center - _gestureStartPan) / _gestureStartScale;
    setState(() {
      _scale = newScale;
      _pan = d.focalPoint - center - canvasPoint * newScale;
    });
  }

  void _onCanvasScaleEnd(ScaleEndDetails d) {
    final stroke = _activeStroke;
    if (stroke != null && stroke.points.length > 1) {
      _design.strokes.add(stroke);
    }
    setState(() => _activeStroke = null);
  }

  void _eraseAt(Offset cp) {
    final threshold = 16.0 / _scale;
    final before = _design.strokes.length;
    _design.strokes.removeWhere(
        (s) => s.points.any((p) => (p - cp).distance < threshold));
    if (_design.strokes.length != before) setState(() {});
  }

  // ---- Text & stamps ----

  void _addText() {
    _showTextDialog(
      onConfirm: (text, color) {
        setState(() {
          _design.texts.add(CollageTextItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: text,
            pos: -_pan / _scale,
            color: color,
          ));
        });
      },
    );
  }

  void _addStamp(String emoji) {
    setState(() {
      _design.texts.add(CollageTextItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: emoji,
        pos: -_pan / _scale +
            Offset(
              (_stampRng.nextDouble() - 0.5) * 90,
              (_stampRng.nextDouble() - 0.5) * 90,
            ),
        color: kCollagePenColors[0],
      ));
    });
  }

  void _editText(CollageTextItem item) {
    _showTextDialog(
      initial: item.text,
      initialColor: item.color,
      onConfirm: (text, color) {
        setState(() {
          item.text = text;
          item.color = color;
        });
      },
      onDelete: () {
        setState(() => _design.texts.removeWhere((t) => t.id == item.id));
      },
    );
  }

  void _showTextDialog({
    String? initial,
    Color? initialColor,
    required Function(String, Color) onConfirm,
    VoidCallback? onDelete,
  }) {
    showDialog(
      context: context,
      builder: (_) => _CollageTextDialog(
        initial: initial,
        initialColor: initialColor ?? kCollagePenColors[0],
        onConfirm: onConfirm,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    final palette = activeProfile;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final photosInteractive = _editMode && _tool == _EditTool.move;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Paper backdrop ──
          Positioned.fill(
            child: CustomPaint(
              painter: _PaperBackdropPainter(
                palette: palette,
                bgColor: _design.bgColor,
                pan: _pan,
                scale: _scale,
              ),
            ),
          ),

          // ── Canvas gestures (pan / zoom / pen / eraser) ──
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onCanvasScaleStart,
              onScaleUpdate: _onCanvasScaleUpdate,
              onScaleEnd: _onCanvasScaleEnd,
              child: const SizedBox.expand(),
            ),
          ),

          // ── Photos ──
          IgnorePointer(
            ignoring: !photosInteractive,
            child: Stack(children: _buildPhotoWidgets(center)),
          ),

          // ── Pen strokes (over photos) ──
          IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: _StrokesPainter(
                strokes: _design.strokes,
                activeStroke: _activeStroke,
                pan: _pan,
                scale: _scale,
              ),
            ),
          ),

          // ── Texts & stamps ──
          ..._buildTextWidgets(center),

          // ── Header node (map-identical drawing, fixed at top center) ──
          _buildHeaderNode(size.width, topPad, palette),

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

          // ── Edit toolbar (edit mode) ──
          if (_editMode)
            Positioned(
              bottom: bottomPad + 18,
              left: 16,
              right: 86,
              child: _buildEditToolbar(palette),
            ),

          // ── Edit / done FAB (bottom right) ──
          Positioned(
            bottom: bottomPad + 18,
            right: 18,
            child: GestureDetector(
              onTap: () => setState(() {
                _editMode = !_editMode;
                _tool = _EditTool.move;
                _activeStroke = null;
              }),
              child: Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _editMode ? palette.inkLine : AppTheme.accent,
                  border: Border.all(
                      color: palette.inkLine.withValues(alpha: 0.9),
                      width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.ink.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  _editMode ? Icons.check_rounded : Icons.edit_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // ── Hint (view mode) ──
          if (!_editMode)
            AnimatedBuilder(
              animation: _photoCtrl,
              builder: (_, __) => Positioned(
                bottom: bottomPad + 32,
                left: 0, right: 86,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _photoCtrl.value * 0.7,
                    child: Center(
                      child: Text(
                        'ピンチでズーム · ✏️で編集',
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontFamily: AppTheme.bodyFamily,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Header node ----

  Widget _buildHeaderNode(
      double screenWidth, double topPad, ColorProfile palette) {
    final r = _nodeR;
    final gap = (r * 0.24).clamp(3.0, 7.0);
    final rIcon = (r - gap).clamp(r * 0.5, r);
    final boxSize = r * 3.6;

    return Positioned(
      top: topPad + 4,
      left: screenWidth / 2 - boxSize / 2,
      width: boxSize,
      height: boxSize + 14,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 0,
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(boxSize),
                      painter: _MapNodePainter(
                        user: widget.user,
                        palette: palette,
                        r: r,
                        rIcon: rIcon,
                      ),
                    ),
                    if (widget.user.imageUrl != null &&
                        widget.user.imageUrl!.isNotEmpty)
                      ClipOval(
                        child: SizedBox(
                          width: rIcon * 2,
                          height: rIcon * 2,
                          child: Image.network(
                            widget.user.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(widget.user.emoji,
                                  style: TextStyle(fontSize: rIcon * 0.9)),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(widget.user.emoji,
                          style: TextStyle(fontSize: rIcon * 0.9)),
                  ],
                ),
              ),
            ),
            // Name below, identical to the map's label
            Positioned(
              top: boxSize / 2 + r + 5,
              child: Text(
                widget.user.name,
                style: TextStyle(
                  color: palette.ink.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  fontFamily: AppTheme.bodyFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Edit toolbar ----

  Widget _buildEditToolbar(ColorProfile palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-palette for the active tool
        if (_tool == _EditTool.pen) ...[
          _SwatchRow(
            colors: kCollagePenColors,
            selected: _penColor,
            onSelect: (c) => setState(() => _penColor = c),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Width selector
                ...kCollagePenWidths.map((w) => GestureDetector(
                      onTap: () => setState(() => _penWidth = w),
                      child: Container(
                        width: 22, height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _penWidth == w
                                ? AppTheme.accent
                                : AppTheme.ink.withValues(alpha: 0.2),
                            width: _penWidth == w ? 2.0 : 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: w * 2.2,
                          height: w * 2.2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.ink.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    )),
                const SizedBox(width: 4),
                _ToolChip(
                  icon: Icons.undo_rounded,
                  label: '戻す',
                  onTap: () => setState(() {
                    if (_design.strokes.isNotEmpty) {
                      _design.strokes.removeLast();
                    }
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_tool == _EditTool.stamp) ...[
          _StampRow(onSelect: _addStamp),
          const SizedBox(height: 8),
        ],
        if (_tool == _EditTool.bg) ...[
          _BgSwatchRow(
            selected: _design.bgColor,
            onSelect: (c) => setState(() => _design.bgColor = c),
          ),
          const SizedBox(height: 8),
        ],
        // Tool chips (scrollable)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: palette.inkLine.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolChip(
                  icon: Icons.open_with_rounded,
                  label: '移動',
                  active: _tool == _EditTool.move,
                  onTap: () => setState(() => _tool = _EditTool.move),
                ),
                _ToolChip(
                  icon: Icons.text_fields_rounded,
                  label: 'テキスト',
                  onTap: () {
                    setState(() => _tool = _EditTool.move);
                    _addText();
                  },
                ),
                _ToolChip(
                  icon: Icons.emoji_emotions_outlined,
                  label: 'スタンプ',
                  active: _tool == _EditTool.stamp,
                  onTap: () => setState(() => _tool = _EditTool.stamp),
                ),
                _ToolChip(
                  icon: Icons.brush_rounded,
                  label: 'ペン',
                  active: _tool == _EditTool.pen,
                  onTap: () => setState(() => _tool = _EditTool.pen),
                ),
                _ToolChip(
                  icon: Icons.cleaning_services_outlined,
                  label: '消しゴム',
                  active: _tool == _EditTool.eraser,
                  onTap: () => setState(() => _tool = _EditTool.eraser),
                ),
                _ToolChip(
                  icon: Icons.palette_outlined,
                  label: '背景',
                  active: _tool == _EditTool.bg,
                  onTap: () => setState(() => _tool = _EditTool.bg),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- Photos ----

  List<Widget> _buildPhotoWidgets(Offset center) {
    final n = _photos.length;
    final widgets = <Widget>[];
    for (int i = 0; i < n; i++) {
      final p = _photos[i];
      widgets.add(AnimatedBuilder(
        animation: _photoCtrl,
        builder: (_, __) {
          final totalMs = _photoCtrl.duration!.inMilliseconds;
          final startT = (i * 100) / totalMs;
          final endT = (i * 100 + 450) / totalMs;
          final raw =
              ((_photoCtrl.value - startT) / (endT - startT)).clamp(0.0, 1.0);
          if (raw == 0.0) return const SizedBox.shrink();
          final appear = Curves.easeOutBack.transform(raw);

          final screenSize = p.size * _scale;
          final screenPos = center + _pan + p.pos * _scale;
          return Positioned(
            left: screenPos.dx - screenSize / 2,
            top: screenPos.dy - screenSize / 2,
            width: screenSize,
            height: screenSize,
            child: Transform.rotate(
              angle: p.rotation,
              child: Transform.scale(
                scale: appear.clamp(0.0, 1.2),
                child: _PhotoTile(
                  item: p,
                  canvasScale: _scale,
                  onChanged: () {
                    _persistPhoto(p);
                    setState(() {});
                  },
                ),
              ),
            ),
          );
        },
      ));
    }
    return widgets;
  }

  // ---- Texts & stamps ----

  List<Widget> _buildTextWidgets(Offset center) {
    final interactive =
        _editMode && (_tool == _EditTool.move || _tool == _EditTool.stamp);
    return _design.texts.map((t) {
      final isStamp = t.text.characters.length <= 2;
      final screenPos = center + _pan + t.pos * _scale;
      final fontSize = (isStamp ? 26.0 : 17.0) * _scale;
      final text = Text(
        t.text,
        style: AppTheme.display(TextStyle(
          color: t.color,
          fontSize: fontSize.clamp(8.0, 72.0),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        )),
      );
      return Positioned(
        left: screenPos.dx - 150,
        top: screenPos.dy - 35,
        width: 300,
        height: 70,
        child: IgnorePointer(
          ignoring: !interactive,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => setState(() => t.pos += d.delta / _scale),
              onLongPress: () => _editText(t),
              child: interactive
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.4),
                          width: 1.1,
                        ),
                      ),
                      child: text,
                    )
                  : text,
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ======= Paper backdrop: tint/gradient + pan/zoom-aware dot grid =======

class _PaperBackdropPainter extends CustomPainter {
  final ColorProfile palette;
  final Color? bgColor;
  final Offset pan;
  final double scale;

  const _PaperBackdropPainter({
    required this.palette,
    required this.bgColor,
    required this.pan,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    if (bgColor != null) {
      canvas.drawRect(full, Paint()..color = bgColor!);
    } else {
      canvas.drawRect(
        full,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.background, palette.paperLow],
          ).createShader(full),
      );
    }

    // Dot grid that pans/zooms with the canvas (same as the map)
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.save();
    canvas.translate(cx + pan.dx, cy + pan.dy);
    canvas.scale(scale);
    canvas.translate(-cx, -cy);

    final inv = 1.0 / scale;
    final bounds = Rect.fromPoints(
      Offset((0 - cx - pan.dx) * inv + cx, (0 - cy - pan.dy) * inv + cy),
      Offset((size.width - cx - pan.dx) * inv + cx,
          (size.height - cy - pan.dy) * inv + cy),
    );
    const gridGap = 26.0;
    final startX = (bounds.left / gridGap).floorToDouble() * gridGap;
    final startY = (bounds.top / gridGap).floorToDouble() * gridGap;
    final points = <Offset>[];
    for (double y = startY; y <= bounds.bottom; y += gridGap) {
      for (double x = startX; x <= bounds.right; x += gridGap) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = palette.ink.withValues(alpha: 0.09)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaperBackdropPainter old) =>
      old.pan != pan ||
      old.scale != scale ||
      old.bgColor != bgColor ||
      old.palette != palette;
}

// ======= Pen strokes =======

class _StrokesPainter extends CustomPainter {
  final List<CollageStroke> strokes;
  final CollageStroke? activeStroke;
  final Offset pan;
  final double scale;

  const _StrokesPainter({
    required this.strokes,
    required this.activeStroke,
    required this.pan,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.save();
    canvas.translate(cx + pan.dx, cy + pan.dy);
    canvas.scale(scale);

    void drawStroke(CollageStroke s) {
      if (s.points.length < 2) return;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) drawStroke(s);
    if (activeStroke != null) drawStroke(activeStroke!);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokesPainter old) => true;
}

// ======= Center node painted exactly like the map's nodes =======

class _MapNodePainter extends CustomPainter {
  final User user;
  final ColorProfile palette;
  final double r;
  final double rIcon;

  const _MapNodePainter({
    required this.user,
    required this.palette,
    required this.r,
    required this.rIcon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final fill = user.nodeColor;

    canvas.drawCircle(
        c, r * 1.7, Paint()..color = fill.withValues(alpha: 0.10));
    canvas.drawCircle(c, r, Paint()..color = palette.background);
    canvas.drawCircle(
        c, rIcon, Paint()..color = fill.withValues(alpha: 0.45));
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    rim
      ..color = palette.inkLine.withValues(alpha: 0.85)
      ..strokeWidth = 1.4;
    canvas.drawCircle(c, rIcon, rim);
    rim
      ..color = palette.inkLine.withValues(alpha: 0.95)
      ..strokeWidth = 1.9;
    canvas.drawCircle(c, r, rim);
  }

  @override
  bool shouldRepaint(_MapNodePainter old) =>
      old.user != user || old.palette != palette || old.r != r;
}

// ======= Photo tile: sketchbook polaroid with washi tape =======

class _PhotoTile extends StatefulWidget {
  final CollagePhotoItem item;
  final double canvasScale;
  final VoidCallback onChanged;

  const _PhotoTile({
    required this.item,
    required this.canvasScale,
    required this.onChanged,
  });

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  double _startSize = 100;

  @override
  Widget build(BuildContext context) {
    final p = widget.item;
    final palette = activeProfile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        _startSize = p.size;
      },
      onScaleUpdate: (d) {
        if (d.pointerCount >= 2) {
          p.size = (_startSize * d.scale).clamp(48.0, 280.0);
        } else {
          p.pos += d.focalPointDelta / widget.canvasScale;
        }
        widget.onChanged();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: palette.inkLine.withValues(alpha: 0.55),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.ink.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: p.photo.thumbnailUrl != null
                  ? Image.network(
                      p.photo.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: palette.paperLow,
                        child: Icon(Icons.image_outlined,
                            color: palette.ink.withValues(alpha: 0.35),
                            size: 24),
                      ),
                    )
                  : Container(
                      color: palette.paperLow,
                      child: Icon(Icons.image_outlined,
                          color: palette.ink.withValues(alpha: 0.35),
                          size: 24),
                    ),
            ),
          ),
          Positioned(
            top: -6,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -0.06,
                child: Container(
                  width: 30,
                  height: 11,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======= Tool chip / swatch widgets =======

class _ToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToolChip({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppTheme.accent
                : AppTheme.ink.withValues(alpha: 0.0),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17,
                color: active
                    ? AppTheme.accent
                    : AppTheme.ink.withValues(alpha: 0.75)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? AppTheme.accent
                    : AppTheme.ink.withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.bodyFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;
  final Widget? trailing;

  const _SwatchRow({
    required this.colors,
    required this.selected,
    required this.onSelect,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.ink.withValues(alpha: 0.25), width: 1.2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...colors.map((c) => GestureDetector(
                  onTap: () => onSelect(c),
                  child: Container(
                    width: 24, height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: c == selected
                            ? AppTheme.accent
                            : AppTheme.ink.withValues(alpha: 0.2),
                        width: c == selected ? 2.4 : 1.0,
                      ),
                    ),
                  ),
                )),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _StampRow extends StatelessWidget {
  final ValueChanged<String> onSelect;

  const _StampRow({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.ink.withValues(alpha: 0.25), width: 1.2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: kCollageStamps
              .map((e) => GestureDetector(
                    onTap: () => onSelect(e),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _BgSwatchRow extends StatelessWidget {
  final Color? selected;
  final ValueChanged<Color?> onSelect;

  const _BgSwatchRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final palette = activeProfile;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.ink.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: kCollageBgTints.map((c) {
          final isSel = c == selected;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 24, height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c ?? palette.background,
                border: Border.all(
                  color: isSel
                      ? AppTheme.accent
                      : AppTheme.ink.withValues(alpha: 0.25),
                  width: isSel ? 2.4 : 1.0,
                ),
              ),
              child: c == null
                  ? Icon(Icons.refresh,
                      size: 13, color: AppTheme.ink.withValues(alpha: 0.4))
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ======= Text dialog with colour picker =======

class _CollageTextDialog extends StatefulWidget {
  final String? initial;
  final Color initialColor;
  final Function(String, Color) onConfirm;
  final VoidCallback? onDelete;

  const _CollageTextDialog({
    this.initial,
    required this.initialColor,
    required this.onConfirm,
    this.onDelete,
  });

  @override
  State<_CollageTextDialog> createState() => _CollageTextDialogState();
}

class _CollageTextDialogState extends State<_CollageTextDialog> {
  late final _ctrl = TextEditingController(text: widget.initial ?? '');
  late Color _color = widget.initialColor;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onConfirm(text, _color);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.initial == null ? 'テキストを追加' : 'テキストを編集',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: AppTheme.display(TextStyle(color: _color, fontSize: 16)),
            decoration: InputDecoration(
              hintText: '例: たのしかった〜！',
              hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              enabledBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppTheme.ink.withValues(alpha: 0.3)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accent),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          Row(
            children: kCollagePenColors.map((c) {
              final isSel = c == _color;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 26, height: 26,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c,
                    border: Border.all(
                      color: isSel
                          ? AppTheme.accent
                          : AppTheme.ink.withValues(alpha: 0.2),
                      width: isSel ? 2.6 : 1.0,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              widget.onDelete!();
              Navigator.pop(context);
            },
            child: const Text('削除',
                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('キャンセル',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('OK',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
