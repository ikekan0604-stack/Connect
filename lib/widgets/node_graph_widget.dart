import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
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

class _NodeGraphWidgetState extends State<NodeGraphWidget>
    with SingleTickerProviderStateMixin {
  static const double _fov = 460.0;

  late List<_Star> _stars;
  List<_WorldNode> _worldNodes = const [];
  List<_WorldEdge> _worldEdges = const [];

  final GraphViewState _view = GraphViewState();

  Size _lastSize = Size.zero;

  // Profile images loaded from network — keyed by user.id
  final Map<String, ui.Image> _profileImages = {};
  int _imageVersion = 0;

  // ---- Center-change feature ----
  /// Id of the user currently at the visual center of the 2D graph.
  String _centerId = 'self';
  /// Tracks the last center we built layout for (triggers rebuild on change).
  String _lastCenterId = 'self';
  /// True while a center-change-triggered rebuild is pending.
  bool _animPending = false;
  /// Previous 2D positions to interpolate FROM during the recenter animation.
  final Map<String, Offset> _animFrom = {};
  /// Drives the recenter animation (0 → 1 = old positions → new positions).
  late AnimationController _animCtrl;
  /// Eased animation progress exposed to the painter via ValueNotifier.
  final ValueNotifier<double> _animT = ValueNotifier(1.0);

  // Listener-based gesture state (avoids gesture arena — fixes Flutter web button taps)
  final Map<int, Offset> _pointers = {};
  Offset? _prevFocal;
  double? _prevDist;
  double _baseScale = 1.0;

  // Manual long-press detection
  Timer? _longPressTimer;
  Offset? _longPressOrigin;
  static const _kLongPressDuration = Duration(milliseconds: 500);
  static const _kLongPressMoveSlop = 12.0;

  @override
  void initState() {
    super.initState();
    _stars = _generateStars(60);
    PaintingBinding.instance.systemFonts.addListener(_onFontsLoaded);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animCtrl.addListener(() {
      // Ease-out cubic: fast start, gentle landing.
      final t = _animCtrl.value;
      _animT.value = 1 - (1 - t) * (1 - t) * (1 - t);
    });
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsLoaded);
    _longPressTimer?.cancel();
    _animCtrl.dispose();
    _animT.dispose();
    _disposeNodeList(_worldNodes);
    for (final img in _profileImages.values) {
      img.dispose();
    }
    _view.dispose();
    super.dispose();
  }

  void _onFontsLoaded() {
    if (mounted && _lastSize != Size.zero) {
      _buildLayout(_lastSize);
    }
  }

  // ---------------- Center-change (tap-to-recenter) ----------------

  /// Switch the visual center to [newId] and smoothly animate the graph.
  void _setCenterId(String newId) {
    if (newId == _centerId) {
      // Tapping the current center → return to self.
      if (_centerId == 'self') return;
      newId = 'self';
    }
    // Snapshot current world positions as animation start.
    _animFrom.clear();
    for (final n in _worldNodes) {
      _animFrom[n.user.id] = Offset(n.wx, n.wy);
    }
    _animT.value = 0.0;
    _animCtrl.reset();
    _animPending = true;
    setState(() {
      _centerId = newId;
    });
    // _buildLayout will be scheduled in build() when _lastCenterId != _centerId.
  }

  /// Single-tap handler: recenter in 2D; no-op in 3D.
  void _handleTap(Offset pos) {
    if (widget.is3D) return;
    final hit = _hitTest(pos);
    if (hit == null) return;
    _setCenterId(hit.user.id);
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
    // Edges carry a spring-multiplier so closer relationships pull nodes together.
    final fEdges = <(int, int, double)>[];
    for (final c in widget.connections) {
      final a = idIdx[c.userId1];
      final b = idIdx[c.userId2];
      if (a != null && b != null && a != b) {
        fEdges.add((a, b, _springMult(c.level)));
      }
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
      // Concentric/radial layout centred on _centerId.
      final userIds = [for (final u in ordered) u.id];
      final r = _FRLayout.computeConcentric(
        n: n,
        userIds: userIds,
        centerId: _centerId,
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

    // Kick off network image loads for any nodes that have an imageUrl.
    _loadProfileImages(worldNodes);

    // If this layout was triggered by a center change, start the position animation.
    if (_animPending) {
      _animPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animCtrl.forward();
      });
    }
  }

  // ---------------- Network image loading ----------------

  void _loadProfileImages(List<_WorldNode> nodes) {
    for (final node in nodes) {
      final url = node.user.imageUrl;
      if (url == null || url.isEmpty) continue;
      if (_profileImages.containsKey(node.user.id)) continue; // already loaded
      _loadNetworkImage(node.user.id, url);
    }
  }

  Future<void> _loadNetworkImage(String id, String url) async {
    try {
      // Use dart:html XHR to fetch raw image bytes — more reliable than
      // NetworkImage on Flutter web (CanvasKit) which can silently fail.
      final request = await html.HttpRequest.request(
        url,
        responseType: 'arraybuffer',
      ).timeout(const Duration(seconds: 15));
      if (request.status != 200) return;
      final bytes = (request.response as ByteBuffer).asUint8List();
      // Decode to ui.Image via Skia codec — produces a CanvasKit-native image.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 120,
        targetHeight: 120,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (mounted) {
        setState(() {
          _profileImages[id] = frame.image;
          _imageVersion++;
        });
      }
    } catch (_) {
      // silently ignore — node shows kanji/emoji fallback
    }
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

  static double _springMult(RelationshipLevel l) {
    switch (l) {
      case RelationshipLevel.bestFriend:   return 2.8;
      case RelationshipLevel.closeFriend:  return 1.8;
      case RelationshipLevel.friend:       return 1.0;
      case RelationshipLevel.familiar:     return 0.5;
      case RelationshipLevel.acquaintance: return 0.25;
    }
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

  // ---------------- Listener-based gestures ----------------
  // Using Listener instead of GestureDetector so we never enter the gesture
  // arena — this lets button taps in parent/sibling widgets work correctly
  // on Flutter web (CanvasKit), where GestureDetector(onScale) would otherwise
  // compete with and block all TapGestureRecognizers.

  void _handlePointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;

    if (_pointers.length == 1) {
      // Start long-press timer
      _longPressOrigin = e.localPosition;
      _longPressTimer?.cancel();
      _longPressTimer = Timer(_kLongPressDuration, () {
        final pos = _longPressOrigin;
        if (pos == null) return;
        final hit = _hitTest(pos);
        if (hit != null) widget.onNodeLongPress(hit.user);
        _longPressOrigin = null;
      });
    } else {
      // Multi-touch: cancel long press, snapshot scale
      _longPressTimer?.cancel();
      _longPressOrigin = null;
      _baseScale = _view.scale;
    }

    _prevFocal = _focal();
    _prevDist = _dist();
  }

  void _handlePointerMove(PointerMoveEvent e) {
    _pointers[e.pointer] = e.localPosition;

    // Cancel long press on movement
    if (_longPressOrigin != null &&
        (e.localPosition - _longPressOrigin!).distance > _kLongPressMoveSlop) {
      _longPressTimer?.cancel();
      _longPressOrigin = null;
    }

    final focal = _focal();
    if (focal == null || _prevFocal == null) {
      _prevFocal = focal;
      _prevDist = _dist();
      return;
    }
    final delta = focal - _prevFocal!;

    if (_pointers.length == 1) {
      if (widget.is3D) {
        _view.update(
          rotY: _view.rotY - delta.dx * 0.008,
          rotX: (_view.rotX + delta.dy * 0.008).clamp(-pi / 2, pi / 2),
        );
      } else {
        _view.update(pan: _view.pan + delta);
      }
    } else {
      final d = _dist();
      final prev = _prevDist;
      double newScale = _view.scale;
      if (d != null && prev != null && prev > 0) {
        newScale = (_view.scale * d / prev).clamp(0.3, 3.0);
      }
      _view.update(scale: newScale, pan: _view.pan + delta);
    }

    _prevFocal = focal;
    _prevDist = _dist();
  }

  void _handlePointerUp(PointerUpEvent e) => _removePointer(e.pointer, tap: true);
  void _handlePointerCancel(PointerCancelEvent e) => _removePointer(e.pointer);

  void _removePointer(int id, {bool tap = false}) {
    final wasSinglePointer = _pointers.length == 1;
    final timerStillActive = _longPressTimer?.isActive ?? false;
    final origin = _longPressOrigin;

    _pointers.remove(id);

    if (_pointers.isEmpty) {
      _longPressTimer?.cancel();
      _longPressOrigin = null;
      _prevFocal = null;
      _prevDist = null;
      // Single-pointer quick release with no movement → single tap
      if (tap && wasSinglePointer && timerStillActive && origin != null) {
        _handleTap(origin);
      }
    } else {
      _prevFocal = _focal();
      _prevDist = _dist();
    }
  }

  Offset? _focal() {
    if (_pointers.isEmpty) return null;
    return _pointers.values.reduce((a, b) => a + b) /
        _pointers.length.toDouble();
  }

  double? _dist() {
    if (_pointers.length < 2) return null;
    final pts = _pointers.values.toList();
    return (pts[0] - pts[1]).distance;
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final size = constraints.biggest;
      final validSize = size.width >= 50 && size.height >= 50;
      final centerChanged = _lastCenterId != _centerId;
      if (validSize && (_worldNodes.isEmpty || _lastSize != size || centerChanged)) {
        if (centerChanged) _lastCenterId = _centerId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _buildLayout(size);
        });
      }
      if (!validSize) return const SizedBox.shrink();
      return Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
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
              profileImages: _profileImages,
              imageVersion: _imageVersion,
              animFrom: _animFrom,
              animT: _animT,
            ),
          ),
        ),
      );
    });
  }
}

// ---------------- Force-directed Layout ----------------

class _FRLayout {
  // ---- Concentric / radial layout (replaces FR for 2D) ----
  //
  // Runs BFS from [centerId], assigns each node to a ring, then places
  // ring nodes evenly on circles.  Ring radii adapt to node count so
  // nodes never crowd each other.
  //
  // edges: (fromIdx, toIdx, springMult) — mult is ignored here; only
  // connectivity matters for BFS.
  static (List<double>, List<double>) computeConcentric({
    required int n,
    required List<String> userIds,
    required String centerId,
    required List<(int, int, double)> edges,
    required double shortSide,
  }) {
    final px = List<double>.filled(n, 0.0);
    final py = List<double>.filled(n, 0.0);
    final idToIdx = <String, int>{
      for (int i = 0; i < n; i++) userIds[i]: i,
    };

    final centerIdx = idToIdx[centerId] ?? 0;

    // Build adjacency list.
    final adj = List<List<int>>.generate(n, (_) => <int>[]);
    for (final (i, j, _) in edges) {
      adj[i].add(j);
      adj[j].add(i);
    }

    // BFS from center → assign ring number.
    final ringOf = List<int>.filled(n, -1);
    ringOf[centerIdx] = 0;
    final queue = <int>[centerIdx];
    // rings[k] = list of node indices at BFS depth k.
    final rings = <int, List<int>>{0: [centerIdx]};

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      final d = ringOf[cur];
      for (final nb in adj[cur]) {
        if (ringOf[nb] == -1) {
          ringOf[nb] = d + 1;
          queue.add(nb);
          rings.putIfAbsent(d + 1, () => <int>[]).add(nb);
        }
      }
    }

    // Orphans (disconnected from center) go in the outermost ring.
    final isolated = <int>[];
    for (int i = 0; i < n; i++) {
      if (ringOf[i] == -1) isolated.add(i);
    }
    if (isolated.isNotEmpty) {
      final maxRing = rings.keys.reduce(max) + 1;
      rings[maxRing] = isolated;
    }

    // ---- Place each ring concentrically ----
    // Minimum radius gap between adjacent rings.
    const double ringGap = 88.0;
    // Minimum arc-length per node (covers the node diameter + small padding).
    const double nodeArcDirect = 50.0; // for ring 1 (larger nodes)
    const double nodeArcOther  = 38.0; // for rings 2+

    double prevRadius = 0;
    final sortedKeys = rings.keys.toList()..sort();

    for (final ring in sortedKeys) {
      if (ring == 0) continue; // center stays at (0, 0)
      final nodes = rings[ring]!;

      // Sort by index for deterministic, stable ordering.
      nodes.sort();

      final arc = ring == 1 ? nodeArcDirect : nodeArcOther;
      final minByArc = nodes.length * arc / (2 * pi);
      final radius = max(prevRadius + ringGap, minByArc);

      // Distribute nodes evenly starting from top (−π/2).
      for (int i = 0; i < nodes.length; i++) {
        final angle = 2 * pi * i / nodes.length - pi / 2;
        px[nodes[i]] = radius * cos(angle);
        py[nodes[i]] = radius * sin(angle);
      }

      prevRadius = radius;
    }

    return (px, py);
  }


  // edges: (fromIdx, toIdx, springMultiplier)
  // springMultiplier > 1 = stronger pull (bestFriend) → nodes end up closer;
  // springMultiplier < 1 = weaker pull (acquaintance) → nodes drift further apart.
  static (List<double>, List<double>) compute2D({
    required int n,
    required int selfIdx,
    required List<(int, int, double)> edges,
    required double shortSide,
    int iterations = 100,
  }) {
    final rng = Random(42);
    final px = List<double>.filled(n, 0);
    final py = List<double>.filled(n, 0);

    for (int i = 0; i < n; i++) {
      if (i == selfIdx) continue;
      final angle = 2 * pi * i / max(n - 1, 1) + rng.nextDouble() * 0.4;
      final r = shortSide * (0.15 + rng.nextDouble() * 0.18);
      px[i] = r * cos(angle);
      py[i] = r * sin(angle);
    }

    final area = shortSide * shortSide;
    final k = sqrt(area / max(n, 4)) * 0.9;
    // Minimum gap: 50 px covers the worst case (self r=26 + direct r=19 + 5px pad).
    const double minGap = 50.0;
    double temp = shortSide * 0.09;

    final fx = List<double>.filled(n, 0);
    final fy = List<double>.filled(n, 0);

    for (int iter = 0; iter < iterations; iter++) {
      for (int i = 0; i < n; i++) {
        fx[i] = 0;
        fy[i] = 0;
      }

      // ---- Repulsion: all pairs ----
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          double dx = px[i] - px[j];
          double dy = py[i] - py[j];
          double dist = sqrt(dx * dx + dy * dy);
          if (dist < 0.5) {
            dx = (rng.nextDouble() - 0.5) * 6;
            dy = (rng.nextDouble() - 0.5) * 6;
            dist = sqrt(dx * dx + dy * dy);
            if (dist < 0.01) dist = 0.01;
          }
          final invDist = 1 / dist;
          // Coulomb repulsion + hard spring when too close
          var force = (k * k) * invDist;
          if (dist < minGap) force += (minGap - dist) * 14;
          final ux = dx * invDist;
          final uy = dy * invDist;
          fx[i] += ux * force;
          fy[i] += uy * force;
          fx[j] -= ux * force;
          fy[j] -= uy * force;
        }
      }

      // ---- Attraction: relationship-weighted spring ----
      for (final (i, j, mult) in edges) {
        final dx = px[i] - px[j];
        final dy = py[i] - py[j];
        double dist = sqrt(dx * dx + dy * dy);
        if (dist < 1) dist = 1;
        final invDist = 1 / dist;
        // mult > 1 amplifies pull → equilibrium distance shrinks
        final force = (dist * dist) / k * mult;
        final ux = dx * invDist;
        final uy = dy * invDist;
        fx[i] -= ux * force;
        fy[i] -= uy * force;
        fx[j] += ux * force;
        fy[j] += uy * force;
      }

      // ---- Weak gravity toward origin ----
      for (int i = 0; i < n; i++) {
        if (i == selfIdx) continue;
        fx[i] -= px[i] * 0.006;
        fy[i] -= py[i] * 0.006;
      }

      // ---- Apply clamped displacement ----
      for (int i = 0; i < n; i++) {
        if (i == selfIdx) { px[i] = 0; py[i] = 0; continue; }
        final mag = sqrt(fx[i] * fx[i] + fy[i] * fy[i]);
        if (mag < 0.001) continue;
        final clamped = min(mag, temp);
        px[i] += fx[i] / mag * clamped;
        py[i] += fy[i] / mag * clamped;
      }

      temp = max(temp * 0.96, 0.4);
    }

    // ---- Post-process: guarantee no two nodes overlap ----
    // Iterative separation passes: push overlapping pairs apart until resolved.
    for (int pass = 0; pass < 120; pass++) {
      bool anyOverlap = false;
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          final dx = px[i] - px[j];
          final dy = py[i] - py[j];
          final d = sqrt(dx * dx + dy * dy);
          if (d < minGap && d > 0.01) {
            final push = (minGap - d) * 0.55;
            final nx = dx / d;
            final ny = dy / d;
            // Keep self anchored at origin; push the other node harder.
            if (i == selfIdx) {
              px[j] -= nx * push * 2;
              py[j] -= ny * push * 2;
            } else if (j == selfIdx) {
              px[i] += nx * push * 2;
              py[i] += ny * push * 2;
            } else {
              px[i] += nx * push;
              py[i] += ny * push;
              px[j] -= nx * push;
              py[j] -= ny * push;
            }
            anyOverlap = true;
          }
        }
      }
      if (!anyOverlap) break;
    }

    // Re-anchor self (separation passes may have drifted it slightly).
    px[selfIdx] = 0;
    py[selfIdx] = 0;

    return (px, py);
  }

  static (List<double>, List<double>, List<double>) compute3D({
    required int n,
    required int selfIdx,
    required List<(int, int, double)> edges,
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

      for (final (i, j, mult) in edges) {
        final dx = px[i] - px[j];
        final dy = py[i] - py[j];
        final dz = pz[i] - pz[j];
        double dist = sqrt(dx * dx + dy * dy + dz * dz);
        if (dist < 1) dist = 1;
        final invDist = 1 / dist;
        final force = (dist * dist) / k * mult;
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
  final Map<String, ui.Image> profileImages;
  final int imageVersion;
  /// Previous 2D positions for recenter animation (empty when not animating).
  final Map<String, Offset> animFrom;
  /// Drives the recenter animation: 0 = old positions, 1 = new positions.
  final ValueNotifier<double> animT;

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
    required this.profileImages,
    required this.imageVersion,
    required this.animFrom,
    required this.animT,
  }) : super(repaint: Listenable.merge([view, animT]));

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
      // 2D: optionally interpolate from previous positions (recenter animation).
      final t = animT.value;
      final animating = t < 1.0 && animFrom.isNotEmpty;
      for (int i = 0; i < n; i++) {
        final node = worldNodes[i];
        double wx = node.wx, wy = node.wy;
        if (animating) {
          final from = animFrom[node.user.id];
          if (from != null) {
            wx = ui.lerpDouble(from.dx, wx, t)!;
            wy = ui.lerpDouble(from.dy, wy, t)!;
          }
        }
        posList[i] = Offset(cx + wx, cy + wy);
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
    // Descending z2: larger z2 = farther from camera → draw first (painter's algorithm).
    // Smaller z2 = closer (perspective scale s is larger) → draw last, on top.
    if (is3D) order.sort((a, b) => depths[b].compareTo(depths[a]));

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

    final profileImg = isSelf ? null : profileImages[node.user.id];
    if (profileImg != null) {
      // Draw circular profile photo on top of the filled circle.
      _drawProfileImage(canvas, profileImg, pos, r, globalOpacity);
    } else {
      // Emoji fallback — use pre-cached TextPainter; layout() already done at build time.
      final ep = node.emojiPainter;
      ep.paint(canvas, pos - Offset(ep.width / 2, ep.height / 2));
    }

    // Name — only for primary nodes with enough opacity.
    if (primary && globalOpacity > 0.5 && node.namePainter != null) {
      final np = node.namePainter!;
      np.paint(canvas, Offset(pos.dx - np.width / 2, pos.dy + r + 4));
    }
  }

  void _drawProfileImage(
      Canvas canvas, ui.Image img, Offset pos, double r, double opacity) {
    final rect = Rect.fromCircle(center: pos, radius: r);
    canvas.save();
    // Clip to circle before drawing the image.
    canvas.clipPath(Path()..addOval(rect));
    final paint = Paint()..filterQuality = FilterQuality.low;
    if (opacity < 1.0) {
      // Bake opacity into the image via a color-matrix.
      paint.colorFilter = ColorFilter.matrix([
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, opacity, 0,
      ]);
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      rect,
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.worldNodes != worldNodes ||
      old.worldEdges != worldEdges ||
      old.is3D != is3D ||
      old.fadeNonDirect != fadeNonDirect ||
      old.highlightedIds != highlightedIds ||
      old.showEdges != showEdges ||
      old.imageVersion != imageVersion;
}
