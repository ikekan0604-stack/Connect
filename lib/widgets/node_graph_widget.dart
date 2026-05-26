import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/connection.dart';

// ---------------- Data structs ----------------

class _Star {
  final Offset pos;
  final double size;
  final double opacity;
  const _Star(this.pos, this.size, this.opacity);
}

class _WorldNode {
  final User user;
  final double baseRadius;
  final double wx, wy, wz;
  // Pre-built at layout time — never recreated during rotation
  final TextPainter emojiPainter;
  final TextPainter? namePainter; // null when baseRadius < 11

  _WorldNode({
    required this.user,
    required this.baseRadius,
    required this.wx,
    required this.wy,
    required this.wz,
    required this.emojiPainter,
    this.namePainter,
  });

  void dispose() {
    emojiPainter.dispose();
    namePainter?.dispose();
  }
}

class _WorldEdge {
  final int fromIdx;
  final int toIdx;
  final double thickness;
  final double opacity;
  const _WorldEdge(this.fromIdx, this.toIdx, this.thickness, this.opacity);
}

// ---------------- View transform state (Listenable) ----------------

/// Encapsulates pan / zoom / 3D rotation. The painter listens to this
/// directly via `super(repaint:)` so we don't need `setState` on every
/// gesture frame.
class GraphViewState extends ChangeNotifier {
  Offset pan = Offset.zero;
  double scale = 1.0;
  double rotX = 0.18;
  double rotY = 0.0;

  void update({
    Offset? pan,
    double? scale,
    double? rotX,
    double? rotY,
  }) {
    if (pan != null) this.pan = pan;
    if (scale != null) this.scale = scale;
    if (rotX != null) this.rotX = rotX;
    if (rotY != null) this.rotY = rotY;
    notifyListeners();
  }

  void reset() {
    pan = Offset.zero;
    scale = 1.0;
    rotX = 0.18;
    rotY = 0.0;
    notifyListeners();
  }
}

// ---------------- Color helpers ----------------

Color _desaturate(Color c, [double amount = 1.0]) {
  final r = (c.r * 255.0).round();
  final g = (c.g * 255.0).round();
  final b = (c.b * 255.0).round();
  final gray = (r * 0.299 + g * 0.587 + b * 0.114).round();
  return Color.fromARGB(
    (c.a * 255.0).round(),
    (r * (1 - amount) + gray * amount).round(),
    (g * (1 - amount) + gray * amount).round(),
    (b * (1 - amount) + gray * amount).round(),
  );
}

double _edgeOpacity(RelationshipLevel l) {
  switch (l) {
    case RelationshipLevel.acquaintance:
      return 0.08;
    case RelationshipLevel.familiar:
      return 0.16;
    case RelationshipLevel.friend:
      return 0.28;
    case RelationshipLevel.closeFriend:
      return 0.45;
    case RelationshipLevel.bestFriend:
      return 0.70;
  }
}

double _edgeThickness(RelationshipLevel l) {
  switch (l) {
    case RelationshipLevel.acquaintance:
      return 0.6;
    case RelationshipLevel.familiar:
      return 1.1;
    case RelationshipLevel.friend:
      return 1.9;
    case RelationshipLevel.closeFriend:
      return 2.8;
    case RelationshipLevel.bestFriend:
      return 4.0;
  }
}

// ---------------- Widget ----------------

class NodeGraphWidget extends StatefulWidget {
  final User selfUser;
  final List<User> users;
  final List<Connection> connections;
  final bool is3D;
  final bool fadeNonDirect;
  final List<String>? highlightedIds;
  final bool showEdges;
  final RelationshipLevel? edgeLevelFilter;
  final Function(User) onNodeLongPress;
  final int resetSignal;

  const NodeGraphWidget({
    super.key,
    required this.selfUser,
    required this.users,
    required this.connections,
    required this.is3D,
    this.fadeNonDirect = false,
    this.highlightedIds,
    this.showEdges = true,
    this.edgeLevelFilter,
    required this.onNodeLongPress,
    this.resetSignal = 0,
  });

  @override
  State<NodeGraphWidget> createState() => _NodeGraphWidgetState();
}

class _NodeGraphWidgetState extends State<NodeGraphWidget> {
  static const double _fov = 460.0;

  late List<_Star> _stars;
  List<_WorldNode> _worldNodes = const [];
  List<_WorldEdge> _worldEdges = const [];

  final GraphViewState _view = GraphViewState();

  double _baseScale = 1.0;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _stars = _generateStars(60);
  }

  @override
  void dispose() {
    _disposeNodeList(_worldNodes);
    _view.dispose();
    super.dispose();
  }

  void _disposeNodeList(List<_WorldNode> nodes) {
    for (final n in nodes) {
      n.dispose();
    }
  }

  /// Sig that, when changed, requires the heavy FR layout to re-run.
  /// Filter / highlight changes are NOT included.
  String _computePositionSig() {
    final ids = widget.users.map((u) => u.id).join(',');
    return '${widget.is3D}|$ids|${widget.users.length}';
  }

  /// Sig for edge list (cheap to recompute).
  String _computeEdgeSig() {
    return '${widget.showEdges}|${widget.edgeLevelFilter}|${widget.connections.length}';
  }

  String _lastPositionSig = '';
  String _lastEdgeSig = '';

  @override
  void didUpdateWidget(NodeGraphWidget old) {
    super.didUpdateWidget(old);
    if (_lastSize != Size.zero) {
      final pSig = _computePositionSig();
      final eSig = _computeEdgeSig();
      final needPositions = pSig != _lastPositionSig;
      final needEdges = eSig != _lastEdgeSig;
      if (needPositions) {
        _buildLayout(_lastSize); // builds positions + edges
      } else if (needEdges) {
        _rebuildEdgesOnly();
      }
    }
    if (old.resetSignal != widget.resetSignal) {
      _view.reset();
    }
  }

  void _rebuildEdgesOnly() {
    if (_worldNodes.isEmpty) return;
    final idIdx = {
      for (int i = 0; i < _worldNodes.length; i++) _worldNodes[i].user.id: i
    };
    final worldEdges = <_WorldEdge>[];
    if (widget.showEdges) {
      for (final c in widget.connections) {
        if (widget.edgeLevelFilter != null &&
            c.level != widget.edgeLevelFilter) {
          continue;
        }
        final a = idIdx[c.userId1];
        final b = idIdx[c.userId2];
        if (a == null || b == null) continue;
        worldEdges.add(_WorldEdge(
          a,
          b,
          _edgeThickness(c.level),
          _edgeOpacity(c.level),
        ));
      }
    }
    setState(() {
      _worldEdges = worldEdges;
      _lastEdgeSig = _computeEdgeSig();
    });
  }

  // ---------------- Stars ----------------

  List<_Star> _generateStars(int count) {
    final rng = Random(42);
    return List.generate(count, (_) {
      return _Star(
        Offset(rng.nextDouble(), rng.nextDouble()),
        rng.nextDouble() * 0.8 + 0.3,
        rng.nextDouble() * 0.30 + 0.06,
      );
    });
  }

  // ---------------- Layout (FR) ----------------

  void _buildLayout(Size size) {
    if (size.width < 50 || size.height < 50) return;
    _lastSize = size;
    _lastPositionSig = _computePositionSig();
    _lastEdgeSig = _computeEdgeSig();

    final ordered = [widget.selfUser, ...widget.users];
    final n = ordered.length;
    if (n == 0) {
      final old = _worldNodes;
      setState(() {
        _worldNodes = const [];
        _worldEdges = const [];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _disposeNodeList(old));
      return;
    }

    final idIdx = {for (int i = 0; i < n; i++) ordered[i].id: i};
    final fEdges = <List<int>>[];
    for (final c in widget.connections) {
      final a = idIdx[c.userId1];
      final b = idIdx[c.userId2];
      if (a != null && b != null && a != b) fEdges.add([a, b]);
    }

    final shortSide = max(min(size.width, size.height), 200.0);

    List<double> px, py, pz;
    if (widget.is3D) {
      final r = _FRLayout.compute3D(
        n: n,
        selfIdx: 0,
        edges: fEdges,
        shortSide: shortSide,
      );
      px = r.$1;
      py = r.$2;
      pz = r.$3;
    } else {
      final r = _FRLayout.compute2D(
        n: n,
        selfIdx: 0,
        edges: fEdges,
        shortSide: shortSide,
      );
      px = r.$1;
      py = r.$2;
      pz = List<double>.filled(n, 0);
    }

    final worldNodes = <_WorldNode>[];
    for (int i = 0; i < n; i++) {
      final u = ordered[i];
      final r = _baseRadiusFor(u);
      worldNodes.add(_WorldNode(
        user: u,
        baseRadius: r,
        wx: px[i],
        wy: py[i],
        wz: pz[i],
        emojiPainter: _buildEmojiPainter(u.emoji, r),
        namePainter: r >= 11 ? _buildNamePainter(u.name, r) : null,
      ));
    }

    final worldEdges = <_WorldEdge>[];
    if (widget.showEdges) {
      for (final c in widget.connections) {
        if (widget.edgeLevelFilter != null &&
            c.level != widget.edgeLevelFilter) {
          continue;
        }
        final a = idIdx[c.userId1];
        final b = idIdx[c.userId2];
        if (a == null || b == null) continue;
        worldEdges.add(_WorldEdge(
          a,
          b,
          _edgeThickness(c.level),
          _edgeOpacity(c.level),
        ));
      }
    }

    final old = _worldNodes;
    setState(() {
      _worldNodes = worldNodes;
      _worldEdges = worldEdges;
    });
    // Dispose after next frame so the old painter finishes its last draw.
    WidgetsBinding.instance.addPostFrameCallback((_) => _disposeNodeList(old));
  }

  static TextPainter _buildEmojiPainter(String emoji, double r) {
    return TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: r * 0.85, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static TextPainter _buildNamePainter(String name, double r) {
    return TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
          fontSize: r < 16 ? 8.5 : 10,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  double _baseRadiusFor(User u) {
    if (u.id == 'self') return 26;
    if (u.isDirect) return 19;
    return 12;
  }

  bool _isPrimary(User u) {
    if (!widget.fadeNonDirect) return true;
    return u.id == 'self' || u.isDirect;
  }

  // ---------------- Hit test ----------------

  _WorldNode? _hitTest(Offset tapScreenPos) {
    final size = _lastSize;
    if (size == Size.zero || _worldNodes.isEmpty) return null;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Inverse view transform (canvas: translate(cx+pan), scale, translate(-cx))
    final painterX =
        (tapScreenPos.dx - cx - _view.pan.dx) / _view.scale + cx;
    final painterY =
        (tapScreenPos.dy - cy - _view.pan.dy) / _view.scale + cy;
    final painterPos = Offset(painterX, painterY);

    _WorldNode? best;
    double bestDist = double.infinity;

    if (widget.is3D) {
      final cosX = cos(_view.rotX), sinX = sin(_view.rotX);
      final cosY = cos(_view.rotY), sinY = sin(_view.rotY);
      for (final n in _worldNodes) {
        final x1 = n.wx * cosY + n.wz * sinY;
        final z1 = -n.wx * sinY + n.wz * cosY;
        final y2 = n.wy * cosX - z1 * sinX;
        final z2 = n.wy * sinX + z1 * cosX;
        final dz = max(z2 + _fov, 20.0);
        final s = _fov / dz;
        final nodePos = Offset(cx + x1 * s, cy + y2 * s);
        final nodeR = n.baseRadius * s.clamp(0.45, 1.5);
        final d = (painterPos - nodePos).distance;
        final hitR = nodeR + 14 / _view.scale;
        if (d <= hitR && d < bestDist) {
          best = n;
          bestDist = d;
        }
      }
    } else {
      for (final n in _worldNodes) {
        final nodePos = Offset(cx + n.wx, cy + n.wy);
        final d = (painterPos - nodePos).distance;
        final hitR = n.baseRadius + 14 / _view.scale;
        if (d <= hitR && d < bestDist) {
          best = n;
          bestDist = d;
        }
      }
    }
    return best;
  }

  void _onLongPress(LongPressStartDetails details) {
    final hit = _hitTest(details.localPosition);
    if (hit != null) widget.onNodeLongPress(hit.user);
  }

  // ---------------- Gestures (no setState) ----------------

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _view.scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 1) {
      if (widget.is3D) {
        _view.update(
          rotY: _view.rotY - details.focalPointDelta.dx * 0.008,
          rotX: (_view.rotX + details.focalPointDelta.dy * 0.008)
              .clamp(-pi / 2, pi / 2),
        );
      } else {
        _view.update(pan: _view.pan + details.focalPointDelta);
      }
    } else {
      _view.update(
        scale: (_baseScale * details.scale).clamp(0.3, 3.0),
        pan: _view.pan + details.focalPointDelta,
      );
    }
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final size = constraints.biggest;
      final validSize = size.width >= 50 && size.height >= 50;
      if (validSize && (_worldNodes.isEmpty || _lastSize != size)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _buildLayout(size);
        });
      }
      if (!validSize) return const SizedBox.shrink();
      return GestureDetector(
        onLongPressStart: _onLongPress,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: _GraphPainter(
              stars: _stars,
              worldNodes: _worldNodes,
              worldEdges: _worldEdges,
              is3D: widget.is3D,
              fadeNonDirect: widget.fadeNonDirect,
              highlightedIds: widget.highlightedIds,
              showEdges: widget.showEdges,
              view: _view,
            ),
          ),
        ),
      );
    });
  }
}

// ---------------- Force-directed Layout ----------------

class _FRLayout {
  static (List<double>, List<double>) compute2D({
    required int n,
    required int selfIdx,
    required List<List<int>> edges,
    required double shortSide,
    int iterations = 90,
  }) {
    final rng = Random(42);
    final px = List<double>.filled(n, 0);
    final py = List<double>.filled(n, 0);

    for (int i = 0; i < n; i++) {
      if (i == selfIdx) continue;
      final angle = 2 * pi * i / max(n - 1, 1) + rng.nextDouble() * 0.4;
      final r = shortSide * (0.14 + rng.nextDouble() * 0.20);
      px[i] = r * cos(angle);
      py[i] = r * sin(angle);
    }

    final area = shortSide * shortSide;
    final k = sqrt(area / max(n, 4)) * 0.85;
    final minDist = 36.0;
    double temp = shortSide * 0.08;

    final fx = List<double>.filled(n, 0);
    final fy = List<double>.filled(n, 0);

    for (int iter = 0; iter < iterations; iter++) {
      for (int i = 0; i < n; i++) {
        fx[i] = 0;
        fy[i] = 0;
      }

      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          double dx = px[i] - px[j];
          double dy = py[i] - py[j];
          double dist = sqrt(dx * dx + dy * dy);
          if (dist < 0.5) {
            dx = (rng.nextDouble() - 0.5) * 5;
            dy = (rng.nextDouble() - 0.5) * 5;
            dist = sqrt(dx * dx + dy * dy);
            if (dist < 0.01) dist = 0.01;
          }
          final invDist = 1 / dist;
          var force = (k * k) * invDist;
          if (dist < minDist) force += (minDist - dist) * 8;
          final ux = dx * invDist;
          final uy = dy * invDist;
          fx[i] += ux * force;
          fy[i] += uy * force;
          fx[j] -= ux * force;
          fy[j] -= uy * force;
        }
      }

      for (final e in edges) {
        final i = e[0], j = e[1];
        final dx = px[i] - px[j];
        final dy = py[i] - py[j];
        double dist = sqrt(dx * dx + dy * dy);
        if (dist < 1) dist = 1;
        final invDist = 1 / dist;
        final force = (dist * dist) / k;
        final ux = dx * invDist;
        final uy = dy * invDist;
        fx[i] -= ux * force;
        fy[i] -= uy * force;
        fx[j] += ux * force;
        fy[j] += uy * force;
      }

      for (int i = 0; i < n; i++) {
        if (i == selfIdx) continue;
        fx[i] -= px[i] * 0.006;
        fy[i] -= py[i] * 0.006;
      }

      for (int i = 0; i < n; i++) {
        if (i == selfIdx) {
          px[i] = 0;
          py[i] = 0;
          continue;
        }
        final mag = sqrt(fx[i] * fx[i] + fy[i] * fy[i]);
        if (mag < 0.001) continue;
        final clamped = min(mag, temp);
        px[i] += fx[i] / mag * clamped;
        py[i] += fy[i] / mag * clamped;
      }

      temp = max(temp * 0.965, 0.4);
    }
    return (px, py);
  }

  static (List<double>, List<double>, List<double>) compute3D({
    required int n,
    required int selfIdx,
    required List<List<int>> edges,
    required double shortSide,
    int iterations = 90,
  }) {
    final rng = Random(43);
    final px = List<double>.filled(n, 0);
    final py = List<double>.filled(n, 0);
    final pz = List<double>.filled(n, 0);

    for (int i = 0; i < n; i++) {
      if (i == selfIdx) continue;
      final golden = (1 + sqrt(5)) / 2;
      final theta = 2 * pi * i / golden;
      final phi = acos(1 - 2 * (i + 0.5) / n);
      final r = shortSide * (0.20 + rng.nextDouble() * 0.10);
      px[i] = r * sin(phi) * cos(theta);
      py[i] = r * cos(phi);
      pz[i] = r * sin(phi) * sin(theta);
    }

    final area = shortSide * shortSide;
    final k = sqrt(area / max(n, 4)) * 0.85;
    final minDist = 32.0;
    double temp = shortSide * 0.08;

    final fx = List<double>.filled(n, 0);
    final fy = List<double>.filled(n, 0);
    final fz = List<double>.filled(n, 0);

    for (int iter = 0; iter < iterations; iter++) {
      for (int i = 0; i < n; i++) {
        fx[i] = 0;
        fy[i] = 0;
        fz[i] = 0;
      }

      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          double dx = px[i] - px[j];
          double dy = py[i] - py[j];
          double dz = pz[i] - pz[j];
          double dist = sqrt(dx * dx + dy * dy + dz * dz);
          if (dist < 0.5) {
            dx = (rng.nextDouble() - 0.5) * 5;
            dy = (rng.nextDouble() - 0.5) * 5;
            dz = (rng.nextDouble() - 0.5) * 5;
            dist = sqrt(dx * dx + dy * dy + dz * dz);
            if (dist < 0.01) dist = 0.01;
          }
          final invDist = 1 / dist;
          var force = (k * k) * invDist;
          if (dist < minDist) force += (minDist - dist) * 8;
          final ux = dx * invDist;
          final uy = dy * invDist;
          final uz = dz * invDist;
          fx[i] += ux * force;
          fy[i] += uy * force;
          fz[i] += uz * force;
          fx[j] -= ux * force;
          fy[j] -= uy * force;
          fz[j] -= uz * force;
        }
      }

      for (final e in edges) {
        final i = e[0], j = e[1];
        final dx = px[i] - px[j];
        final dy = py[i] - py[j];
        final dz = pz[i] - pz[j];
        double dist = sqrt(dx * dx + dy * dy + dz * dz);
        if (dist < 1) dist = 1;
        final invDist = 1 / dist;
        final force = (dist * dist) / k;
        final ux = dx * invDist;
        final uy = dy * invDist;
        final uz = dz * invDist;
        fx[i] -= ux * force;
        fy[i] -= uy * force;
        fz[i] -= uz * force;
        fx[j] += ux * force;
        fy[j] += uy * force;
        fz[j] += uz * force;
      }

      for (int i = 0; i < n; i++) {
        if (i == selfIdx) continue;
        fx[i] -= px[i] * 0.006;
        fy[i] -= py[i] * 0.006;
        fz[i] -= pz[i] * 0.006;
      }

      for (int i = 0; i < n; i++) {
        if (i == selfIdx) {
          px[i] = 0;
          py[i] = 0;
          pz[i] = 0;
          continue;
        }
        final mag = sqrt(fx[i] * fx[i] + fy[i] * fy[i] + fz[i] * fz[i]);
        if (mag < 0.001) continue;
        final clamped = min(mag, temp);
        px[i] += fx[i] / mag * clamped;
        py[i] += fy[i] / mag * clamped;
        pz[i] += fz[i] / mag * clamped;
      }
      temp = max(temp * 0.965, 0.4);
    }
    return (px, py, pz);
  }
}

// ---------------- Painter ----------------

class _GraphPainter extends CustomPainter {
  static const double _fov = 460.0;

  final List<_Star> stars;
  final List<_WorldNode> worldNodes;
  final List<_WorldEdge> worldEdges;
  final bool is3D;
  final bool fadeNonDirect;
  final List<String>? highlightedIds;
  final bool showEdges;
  final GraphViewState view;

  // Cached paint objects — allocated once per painter, mutated per draw call.
  final _fillPaint = Paint();
  final _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final _glowPaint = Paint();
  final _edgePaint = Paint()..strokeCap = StrokeCap.round;

  // Cached background + stars picture, invalidated only when size changes.
  ui.Picture? _bgPicture;
  Size _bgPictureSize = Size.zero;

  _GraphPainter({
    required this.stars,
    required this.worldNodes,
    required this.worldEdges,
    required this.is3D,
    required this.fadeNonDirect,
    required this.highlightedIds,
    required this.showEdges,
    required this.view,
  }) : super(repaint: view);

  bool _isPrimary(User u) {
    if (!fadeNonDirect) return true;
    return u.id == 'self' || u.isDirect;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBgAndStars(canvas, size);
    if (worldNodes.isEmpty) return;

    canvas.save();
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.translate(cx + view.pan.dx, cy + view.pan.dy);
    canvas.scale(view.scale);
    canvas.translate(-cx, -cy);

    // Compute screen positions in painter-space (pre view-transform).
    final n = worldNodes.length;
    final posList = List<Offset>.filled(n, Offset.zero);
    final radList = List<double>.filled(n, 0);
    final depths = List<double>.filled(n, 0);

    if (is3D) {
      final cosX = cos(view.rotX), sinX = sin(view.rotX);
      final cosY = cos(view.rotY), sinY = sin(view.rotY);
      for (int i = 0; i < n; i++) {
        final node = worldNodes[i];
        final x1 = node.wx * cosY + node.wz * sinY;
        final z1 = -node.wx * sinY + node.wz * cosY;
        final y2 = node.wy * cosX - z1 * sinX;
        final z2 = node.wy * sinX + z1 * cosX;
        final dz = max(z2 + _fov, 20.0);
        final s = _fov / dz;
        posList[i] = Offset(cx + x1 * s, cy + y2 * s);
        radList[i] = node.baseRadius * s.clamp(0.45, 1.5);
        depths[i] = z2;
      }
    } else {
      for (int i = 0; i < n; i++) {
        final node = worldNodes[i];
        posList[i] = Offset(cx + node.wx, cy + node.wy);
        radList[i] = node.baseRadius;
        depths[i] = 0;
      }
    }

    if (showEdges) {
      for (final e in worldEdges) {
        if (e.fromIdx >= n || e.toIdx >= n) continue;
        _edgePaint
          ..color = Colors.white.withValues(alpha: e.opacity)
          ..strokeWidth = e.thickness;
        canvas.drawLine(posList[e.fromIdx], posList[e.toIdx], _edgePaint);
      }
    }

    // Depth-sort indices (farther first) for 3D
    final order = List<int>.generate(n, (i) => i);
    if (is3D) order.sort((a, b) => depths[a].compareTo(depths[b]));

    for (final i in order) {
      _drawNode(canvas, worldNodes[i], posList[i], radList[i]);
    }

    canvas.restore();
  }

  /// Renders background color + static stars into a cached Picture.
  /// Only rebuilds when the canvas size changes — zero cost during rotation.
  void _drawBgAndStars(Canvas canvas, Size size) {
    if (_bgPicture == null || _bgPictureSize != size) {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF080808),
      );
      final p = Paint();
      for (final s in stars) {
        p.color = Colors.white.withValues(alpha: s.opacity);
        c.drawCircle(
          Offset(s.pos.dx * size.width, s.pos.dy * size.height),
          s.size,
          p,
        );
      }
      _bgPicture = recorder.endRecording();
      _bgPictureSize = size;
    }
    canvas.drawPicture(_bgPicture!);
  }

  void _drawNode(Canvas canvas, _WorldNode node, Offset pos, double r) {
    final isSelf = node.user.id == 'self';
    final primary = _isPrimary(node.user);
    final highlighted =
        highlightedIds == null || highlightedIds!.contains(node.user.id);

    Color fill;
    if (isSelf) {
      fill = Colors.white;
    } else if (!primary) {
      fill = _desaturate(node.user.nodeColor, 1.0);
    } else {
      fill = node.user.nodeColor;
    }

    double globalOpacity;
    if (!highlighted) {
      globalOpacity = 0.18;
    } else if (!primary) {
      globalOpacity = 0.45;
    } else {
      globalOpacity = 1.0;
    }

    // Soft glow via layered circles — no MaskFilter.blur, much cheaper.
    if (primary && highlighted) {
      final glowColor = isSelf ? Colors.white : fill;
      _glowPaint.color = glowColor.withValues(alpha: 0.05 * globalOpacity);
      canvas.drawCircle(pos, r * 3.0, _glowPaint);
      _glowPaint.color = glowColor.withValues(alpha: 0.12 * globalOpacity);
      canvas.drawCircle(pos, r * 1.7, _glowPaint);
    }

    _fillPaint.color = fill.withValues(alpha: globalOpacity);
    canvas.drawCircle(pos, r, _fillPaint);

    _rimPaint.color = Colors.white.withValues(alpha: 0.25 * globalOpacity);
    canvas.drawCircle(pos, r, _rimPaint);

    if (globalOpacity < 0.35) return;

    // Emoji — use pre-cached TextPainter; layout() already done at build time.
    final ep = node.emojiPainter;
    ep.paint(canvas, pos - Offset(ep.width / 2, ep.height / 2));

    // Name — only for primary nodes with enough opacity.
    if (primary && globalOpacity > 0.5 && node.namePainter != null) {
      final np = node.namePainter!;
      np.paint(canvas, Offset(pos.dx - np.width / 2, pos.dy + r + 4));
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.worldNodes != worldNodes ||
      old.worldEdges != worldEdges ||
      old.is3D != is3D ||
      old.fadeNonDirect != fadeNonDirect ||
      old.highlightedIds != highlightedIds ||
      old.showEdges != showEdges;
}
