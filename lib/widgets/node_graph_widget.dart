import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/connection.dart';
import '../models/group.dart';
import '../theme.dart';
import '../color_profiles.dart';
import '../app_state.dart';

// ---------------- Data structs ----------------

enum _DoodleKind { star, heart, rocket, sparkle, swirl, dot }

class _Doodle {
  final _DoodleKind kind;
  final Offset pos;
  final double size;
  final double rotation;
  final double opacity;
  final ui.Path path;
  const _Doodle(
      this.kind, this.pos, this.size, this.rotation, this.opacity, this.path);
}

class _WorldNode {
  final User user;
  final double baseRadius;
  final double wx, wy, wz;
  final int ringDepth;
  final TextPainter emojiPainter;
  final TextPainter? namePainter;

  _WorldNode({
    required this.user,
    required this.baseRadius,
    required this.wx,
    required this.wy,
    required this.wz,
    this.ringDepth = -1,
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
  final bool isPrimary;
  final bool dashed;
  const _WorldEdge(this.fromIdx, this.toIdx, this.thickness, this.opacity,
      {this.isPrimary = false, this.dashed = false});
}

// ---------------- View transform state ----------------

class GraphViewState extends ChangeNotifier {
  Offset pan = Offset.zero;
  double scale = 1.0;
  double rotX = 0.18;
  double rotY = 0.0;

  void update({Offset? pan, double? scale, double? rotX, double? rotY}) {
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

// ---------------- Helpers ----------------

double _seedNoise(int s) {
  final x = sin(s * 12.9898) * 43758.5453;
  return (x - x.floorToDouble()) * 2 - 1;
}

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
    case RelationshipLevel.acquaintance: return 0.08;
    case RelationshipLevel.familiar:    return 0.16;
    case RelationshipLevel.friend:      return 0.28;
    case RelationshipLevel.closeFriend: return 0.45;
    case RelationshipLevel.bestFriend:  return 0.70;
  }
}

double _edgeThickness(RelationshipLevel l) {
  switch (l) {
    case RelationshipLevel.acquaintance: return 0.6;
    case RelationshipLevel.familiar:    return 1.1;
    case RelationshipLevel.friend:      return 1.9;
    case RelationshipLevel.closeFriend: return 2.8;
    case RelationshipLevel.bestFriend:  return 4.0;
  }
}

// Sort mode: rubber-band pinch-out physics
const double _kMinNormalScale    = 0.28; // pinch wall — resistance starts here
const double _kSortSnapThreshold = 0.13; // virtualScale below this → snap to sort

// ---------------- Widget ----------------

class NodeGraphWidget extends StatefulWidget {
  final User selfUser;
  final List<User> users;
  final List<Connection> connections;
  final bool is3D;
  final bool useConcentricLayout;
  final bool fadeNonDirect;
  final List<String>? highlightedIds;
  final bool showEdges;
  final RelationshipLevel? edgeLevelFilter;
  // Callbacks
  final Function(User) onNodeLongPress;
  final Function(User)? onNodeTap;
  final Function(Set<String>)? onLassoComplete;
  final Function(bool)? onSortModeChanged;
  // Edit / visual modes
  final bool editMode;
  final bool sortMode;
  final List<Group> groups;
  final int resetSignal;
  final int relayoutSignal;
  final double bottomReserve;

  const NodeGraphWidget({
    super.key,
    required this.selfUser,
    required this.users,
    required this.connections,
    required this.is3D,
    this.useConcentricLayout = false,
    this.fadeNonDirect = false,
    this.highlightedIds,
    this.showEdges = true,
    this.edgeLevelFilter,
    required this.onNodeLongPress,
    this.onNodeTap,
    this.onLassoComplete,
    this.onSortModeChanged,
    this.editMode = false,
    this.sortMode = false,
    this.groups = const [],
    this.resetSignal = 0,
    this.relayoutSignal = 0,
    this.bottomReserve = 0,
  });

  @override
  State<NodeGraphWidget> createState() => _NodeGraphWidgetState();
}

class _NodeGraphWidgetState extends State<NodeGraphWidget>
    with SingleTickerProviderStateMixin {
  static const double _fov = 460.0;

  late List<_Doodle> _doodles;
  List<_WorldNode> _worldNodes = const [];
  List<_WorldEdge> _worldEdges = const [];

  final GraphViewState _view = GraphViewState();
  Size _lastSize = Size.zero;
  final Map<String, ui.Image> _profileImages = {};
  int _imageVersion = 0;
  final Map<String, int> _ringDepthById = {};

  // Concentric recenter
  String _centerId = 'self';
  String _lastCenterId = 'self';
  bool _animPending = false;
  final Map<String, Offset> _animFrom = {};
  late AnimationController _animCtrl;
  final ValueNotifier<double> _animT = ValueNotifier(1.0);

  // Listener gesture state
  final Map<int, Offset> _pointers = {};
  Offset? _prevFocal;
  double? _prevDist;
  double _baseScale = 1.0;

  // Long-press detection
  Timer? _longPressTimer;
  Offset? _longPressOrigin;
  static const _kLongPressDuration = Duration(milliseconds: 500);
  static const _kLongPressMoveSlop = 12.0;

  // ---- Edit mode drag state ----
  String? _draggingNodeId;
  Offset? _dragStartScreenPos;
  Offset? _dragStartWorldPos;
  final Map<String, Offset> _nodePositionOverrides = {};

  // ---- Lasso state ----
  bool _isLasso = false;
  final List<Offset> _lassoScreenPoints = [];

  // ---- Sort mode rubber-band state ----
  double _virtualScale = 1.0;
  double _rubberBandDepth = 0.0; // 0.0 = no tension, 1.0 = snap threshold

  // ---- Repaint extra trigger ----
  final ValueNotifier<int> _overlayVersion = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _doodles = _generateDoodles(46);
    PaintingBinding.instance.systemFonts.addListener(_onFontsLoaded);
    activeProfileIndex.addListener(_onPaletteChanged);
    decoStyleNotifier.addListener(_onDecoChanged);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animCtrl.addListener(() {
      final t = _animCtrl.value;
      _animT.value = 1 - (1 - t) * (1 - t) * (1 - t);
    });
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsLoaded);
    activeProfileIndex.removeListener(_onPaletteChanged);
    decoStyleNotifier.removeListener(_onDecoChanged);
    _longPressTimer?.cancel();
    _animCtrl.dispose();
    _animT.dispose();
    _overlayVersion.dispose();
    _disposeNodeList(_worldNodes);
    for (final img in _profileImages.values) img.dispose();
    _view.dispose();
    super.dispose();
  }

  void _onFontsLoaded() {
    if (mounted && _lastSize != Size.zero) _buildLayout(_lastSize);
  }

  void _onPaletteChanged() {
    if (mounted && _lastSize != Size.zero) _buildLayout(_lastSize);
  }

  void _onDecoChanged() {
    if (mounted) setState(() {});
  }

  // ---------------- Center-change ----------------

  void _setCenterId(String newId) {
    if (newId == _centerId) {
      if (_centerId == 'self') return;
      newId = 'self';
    }
    _animFrom.clear();
    for (final n in _worldNodes) {
      _animFrom[n.user.id] = Offset(n.wx, n.wy);
    }
    _animT.value = 0.0;
    _animCtrl.reset();
    _animPending = true;
    setState(() => _centerId = newId);
  }

  void _handleTap(Offset pos) {
    final hit = _hitTest(pos);
    // Single tap → photo collage callback
    if (widget.onNodeTap != null && hit != null && hit.user.id != 'self') {
      widget.onNodeTap!(hit.user);
      return;
    }
    if (!widget.useConcentricLayout || widget.is3D) return;
    if (hit == null) return;
    _setCenterId(hit.user.id);
  }

  void _disposeNodeList(List<_WorldNode> nodes) {
    for (final n in nodes) n.dispose();
  }

  String _computePositionSig() {
    final ids = widget.users.map((u) => u.id).join(',');
    return '${widget.is3D}|${widget.useConcentricLayout}|$ids|${widget.users.length}';
  }

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
      if (pSig != _lastPositionSig) {
        _buildLayout(_lastSize);
      } else if (eSig != _lastEdgeSig) {
        _rebuildEdgesOnly();
      }
    }
    if (old.resetSignal != widget.resetSignal) {
      _view.reset();
      _nodePositionOverrides.clear();
      if (widget.useConcentricLayout && _centerId != 'self') {
        setState(() => _centerId = 'self');
      }
    }
    if (old.relayoutSignal != widget.relayoutSignal) {
      // Re-run layout without position overrides, using group constraints
      _nodePositionOverrides.clear();
      if (_lastSize != Size.zero) _buildLayout(_lastSize);
    }
    if (!old.is3D && widget.is3D) {
      _view.update(pan: Offset.zero);
    }
  }

  void _rebuildEdgesOnly() {
    if (_worldNodes.isEmpty) return;
    final idIdx = {for (int i = 0; i < _worldNodes.length; i++) _worldNodes[i].user.id: i};
    final worldEdges = <_WorldEdge>[];
    if (widget.showEdges) {
      for (final c in widget.connections) {
        if (widget.edgeLevelFilter != null && c.level != widget.edgeLevelFilter) continue;
        final a = idIdx[c.userId1];
        final b = idIdx[c.userId2];
        if (a == null || b == null) continue;
        final dA = _ringDepthById[c.userId1] ?? -1;
        final dB = _ringDepthById[c.userId2] ?? -1;
        final isPrimary = widget.useConcentricLayout && dA >= 0 && dA <= 1 && dB >= 0 && dB <= 1;
        worldEdges.add(_WorldEdge(a, b, _edgeThickness(c.level), _edgeOpacity(c.level),
            isPrimary: isPrimary,
            dashed: c.level != RelationshipLevel.closeFriend &&
                c.level != RelationshipLevel.bestFriend));
      }
    }
    setState(() {
      _worldEdges = worldEdges;
      _lastEdgeSig = _computeEdgeSig();
    });
  }

  // ---------------- Background doodles ----------------

  List<_Doodle> _generateDoodles(int count) {
    final rng = Random(7);
    const pool = [
      _DoodleKind.sparkle, _DoodleKind.sparkle, _DoodleKind.dot,
      _DoodleKind.dot, _DoodleKind.star, _DoodleKind.star,
      _DoodleKind.heart, _DoodleKind.swirl, _DoodleKind.rocket,
    ];
    const spread = 560.0;
    return List.generate(count, (_) {
      final kind = pool[rng.nextInt(pool.length)];
      final size = switch (kind) {
        _DoodleKind.rocket  => 30.0 + rng.nextDouble() * 16,
        _DoodleKind.heart   => 16.0 + rng.nextDouble() * 12,
        _DoodleKind.star    => 14.0 + rng.nextDouble() * 14,
        _DoodleKind.swirl   => 16.0 + rng.nextDouble() * 12,
        _DoodleKind.sparkle =>  9.0 + rng.nextDouble() * 12,
        _DoodleKind.dot     =>  2.5 + rng.nextDouble() * 3,
      };
      return _Doodle(
        kind,
        Offset((rng.nextDouble() - 0.5) * 2 * spread,
            (rng.nextDouble() - 0.5) * 2 * spread),
        size,
        (rng.nextDouble() - 0.5) * 0.7,
        (kind == _DoodleKind.dot ? 0.18 : 0.11) + rng.nextDouble() * 0.05,
        _buildDoodlePath(kind, rng),
      );
    });
  }

  static ui.Path _buildDoodlePath(_DoodleKind kind, Random rng) {
    final p = ui.Path();
    switch (kind) {
      case _DoodleKind.star:
        const points = 5;
        for (int i = 0; i <= points * 2; i++) {
          final isOuter = i.isEven;
          final rr = (isOuter ? 0.5 : 0.21) * (1 + (rng.nextDouble() - 0.5) * 0.1);
          final a = -pi / 2 + i * pi / points;
          final x = cos(a) * rr, y = sin(a) * rr;
          i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
        }
        p.close();
        break;
      case _DoodleKind.heart:
        p.moveTo(0, 0.32);
        p.cubicTo(-0.55, -0.12, -0.32, -0.52, 0, -0.18);
        p.cubicTo(0.32, -0.52, 0.55, -0.12, 0, 0.32);
        p.close();
        break;
      case _DoodleKind.rocket:
        p.moveTo(0, -0.5);
        p.cubicTo(0.26, -0.28, 0.26, 0.12, 0.14, 0.30);
        p.lineTo(-0.14, 0.30);
        p.cubicTo(-0.26, 0.12, -0.26, -0.28, 0, -0.5);
        p.close();
        p.moveTo(-0.14, 0.16); p.lineTo(-0.34, 0.40); p.lineTo(-0.12, 0.30);
        p.moveTo(0.14, 0.16);  p.lineTo(0.34, 0.40);  p.lineTo(0.12, 0.30);
        p.addOval(Rect.fromCircle(center: const Offset(0, -0.08), radius: 0.10));
        break;
      case _DoodleKind.sparkle:
        const r = 0.5, w = 0.10;
        p.moveTo(0, -r);
        p.quadraticBezierTo(w, -w, r, 0);
        p.quadraticBezierTo(w, w, 0, r);
        p.quadraticBezierTo(-w, w, -r, 0);
        p.quadraticBezierTo(-w, -w, 0, -r);
        p.close();
        break;
      case _DoodleKind.swirl:
        const turns = 1.6, steps = 26;
        for (int i = 0; i <= steps; i++) {
          final t = i / steps;
          final a = t * turns * 2 * pi;
          final rr = 0.06 + t * 0.42;
          final x = cos(a) * rr, y = sin(a) * rr;
          i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
        }
        break;
      case _DoodleKind.dot:
        p.addOval(Rect.fromCircle(center: Offset.zero, radius: 0.5));
        break;
    }
    return p;
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
      setState(() { _worldNodes = const []; _worldEdges = const []; });
      WidgetsBinding.instance.addPostFrameCallback((_) => _disposeNodeList(old));
      return;
    }

    final idIdx = {for (int i = 0; i < n; i++) ordered[i].id: i};
    final fEdges = <(int, int, double)>[];
    for (final c in widget.connections) {
      final a = idIdx[c.userId1];
      final b = idIdx[c.userId2];
      if (a != null && b != null && a != b) {
        fEdges.add((a, b, _springMult(c.level)));
      }
    }
    // Virtual springs between group members: pull them together
    for (final group in widget.groups) {
      final memberIdxs = group.memberIds.map((id) => idIdx[id]).whereType<int>().toList();
      for (int a = 0; a < memberIdxs.length; a++) {
        for (int b = a + 1; b < memberIdxs.length; b++) {
          fEdges.add((memberIdxs[a], memberIdxs[b], 3.0));
        }
      }
    }

    final shortSide = max(min(size.width, size.height), 200.0);
    List<double> px, py, pz;
    List<int> ringDepths = List<int>.filled(n, -1);

    if (widget.is3D) {
      final r = _FRLayout.compute3D(n: n, selfIdx: 0, edges: fEdges, shortSide: shortSide);
      px = r.$1; py = r.$2; pz = r.$3;
    } else if (widget.useConcentricLayout) {
      final userIds = [for (final u in ordered) u.id];
      final r = _FRLayout.computeConcentric(
          n: n, userIds: userIds, centerId: _centerId, edges: fEdges, shortSide: shortSide);
      px = r.$1; py = r.$2; pz = List<double>.filled(n, 0);
      ringDepths = r.$3;
    } else {
      final r = _FRLayout.compute2DGrouped(n: n, selfIdx: 0, edges: fEdges, shortSide: shortSide);
      px = r.$1; py = r.$2; pz = List<double>.filled(n, 0);
    }

    // Apply manual position overrides (from drag)
    for (int i = 0; i < n; i++) {
      final id = ordered[i].id;
      final override = _nodePositionOverrides[id];
      if (override != null) {
        px[i] = override.dx;
        py[i] = override.dy;
      }
    }

    _ringDepthById.clear();
    for (int i = 0; i < n; i++) {
      _ringDepthById[ordered[i].id] = ringDepths[i];
    }

    final worldNodes = <_WorldNode>[];
    for (int i = 0; i < n; i++) {
      final u = ordered[i];
      final r = (widget.useConcentricLayout && !widget.is3D)
          ? _radiusForRing(ringDepths[i])
          : _baseRadiusFor(u);
      worldNodes.add(_WorldNode(
        user: u,
        baseRadius: r,
        wx: px[i], wy: py[i], wz: pz[i],
        ringDepth: ringDepths[i],
        emojiPainter: _buildEmojiPainter(u.emoji, r, activeProfile.ink),
        namePainter: r >= 11 ? _buildNamePainter(u.name, r, activeProfile.ink) : null,
      ));
    }

    final worldEdges = <_WorldEdge>[];
    if (widget.showEdges) {
      for (final c in widget.connections) {
        if (widget.edgeLevelFilter != null && c.level != widget.edgeLevelFilter) continue;
        final a = idIdx[c.userId1];
        final b = idIdx[c.userId2];
        if (a == null || b == null) continue;
        final dA = ringDepths[a];
        final dB = ringDepths[b];
        final isPrimary = widget.useConcentricLayout &&
            dA >= 0 && dA <= 1 && dB >= 0 && dB <= 1;
        worldEdges.add(_WorldEdge(a, b, _edgeThickness(c.level), _edgeOpacity(c.level),
            isPrimary: isPrimary,
            dashed: c.level != RelationshipLevel.closeFriend &&
                c.level != RelationshipLevel.bestFriend));
      }
    }

    final old = _worldNodes;
    setState(() { _worldNodes = worldNodes; _worldEdges = worldEdges; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _disposeNodeList(old));
    _loadProfileImages(worldNodes);

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
      if (_profileImages.containsKey(node.user.id)) continue;
      _loadNetworkImage(node.user.id, url);
    }
  }

  Future<void> _loadNetworkImage(String id, String url) async {
    try {
      final request = await html.HttpRequest.request(url, responseType: 'arraybuffer')
          .timeout(const Duration(seconds: 15));
      if (request.status != 200) return;
      final bytes = (request.response as ByteBuffer).asUint8List();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120, targetHeight: 120);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (mounted) {
        setState(() {
          _profileImages[id] = frame.image;
          _imageVersion++;
        });
      }
    } catch (_) {}
  }

  static TextPainter _buildEmojiPainter(String emoji, double r, Color ink) {
    return TextPainter(
      text: TextSpan(text: emoji,
          style: TextStyle(fontSize: r * 0.82, color: ink, fontFamily: AppTheme.bodyFamily)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static TextPainter _buildNamePainter(String name, double r, Color ink) {
    return TextPainter(
      text: TextSpan(text: name,
          style: TextStyle(
            color: ink.withValues(alpha: 0.85),
            fontSize: r < 16 ? 8.5 : 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            fontFamily: AppTheme.bodyFamily,
          )),
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
    if (u.id == 'self') return 22;
    if (u.isDirect) return 16;
    return 10;
  }

  static double _radiusForRing(int depth) {
    if (depth <= 0) return 22;
    if (depth == 1) return 17;
    if (depth == 2) return 11;
    if (depth == 3) return 9;
    return 7;
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
    final painterX = (tapScreenPos.dx - cx - _view.pan.dx) / _view.scale + cx;
    final painterY = (tapScreenPos.dy - cy - _view.pan.dy) / _view.scale + cy;
    final painterPos = Offset(painterX, painterY);

    _WorldNode? best;
    double bestDist = double.infinity;
    final comp = (1.0 / _view.scale).clamp(0.45, 1.7);

    if (widget.is3D) {
      final cosX = cos(_view.rotX), sinX = sin(_view.rotX);
      final cosY = cos(_view.rotY), sinY = sin(_view.rotY);
      for (final n in _worldNodes) {
        final wx = _nodePositionOverrides[n.user.id]?.dx ?? n.wx;
        final wy = _nodePositionOverrides[n.user.id]?.dy ?? n.wy;
        final x1 = wx * cosY + n.wz * sinY;
        final z1 = -wx * sinY + n.wz * cosY;
        final y2 = wy * cosX - z1 * sinX;
        final z2 = wy * sinX + z1 * cosX;
        final dz = max(z2 + _fov, 20.0);
        final s = _fov / dz;
        final nodePos = Offset(cx + x1 * s, cy + y2 * s);
        final nodeR = n.baseRadius * s.clamp(0.45, 1.5) * comp;
        final d = (painterPos - nodePos).distance;
        final hitR = nodeR + 14 / _view.scale;
        if (d <= hitR && d < bestDist) { best = n; bestDist = d; }
      }
    } else {
      for (final n in _worldNodes) {
        final wx = _nodePositionOverrides[n.user.id]?.dx ?? n.wx;
        final wy = _nodePositionOverrides[n.user.id]?.dy ?? n.wy;
        final nodePos = Offset(cx + wx, cy + wy);
        final d = (painterPos - nodePos).distance;
        final hitR = n.baseRadius * comp + 14 / _view.scale;
        if (d <= hitR && d < bestDist) { best = n; bestDist = d; }
      }
    }
    return best;
  }

  // ---------------- Lasso helpers ----------------

  bool _isPointInPolygon(Offset point, List<Offset> polygon) {
    int crossings = 0;
    final n = polygon.length;
    for (int i = 0; i < n; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % n];
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        crossings++;
      }
    }
    return crossings.isOdd;
  }

  void _finishLasso() {
    if (_lassoScreenPoints.length < 4) return;
    final size = _lastSize;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final enclosed = <String>{};
    for (final node in _worldNodes) {
      final wx = _nodePositionOverrides[node.user.id]?.dx ?? node.wx;
      final wy = _nodePositionOverrides[node.user.id]?.dy ?? node.wy;
      // Screen position of node
      final sx = cx + _view.pan.dx + wx * _view.scale;
      final sy = cy + _view.pan.dy + wy * _view.scale;
      if (_isPointInPolygon(Offset(sx, sy), _lassoScreenPoints)) {
        enclosed.add(node.user.id);
      }
    }
    setState(() {
      _isLasso = false;
      _lassoScreenPoints.clear();
    });
    _overlayVersion.value++;
    if (enclosed.length >= 2) {
      widget.onLassoComplete?.call(enclosed);
    }
  }

  // ---------------- Listener gestures ----------------

  void _handlePointerDown(PointerDownEvent e) {
    // Ignore touches in the bottom reserve area (reserved for draggable sheet)
    if (widget.bottomReserve > 0 &&
        _lastSize != Size.zero &&
        e.localPosition.dy > _lastSize.height - widget.bottomReserve) {
      return;
    }

    _pointers[e.pointer] = e.localPosition;

    if (_pointers.length == 1) {
      if (widget.editMode && !widget.is3D) {
        final hit = _hitTest(e.localPosition);
        if (hit != null && hit.user.id != 'self') {
          // Immediately start dragging the node
          _draggingNodeId = hit.user.id;
          _dragStartScreenPos = e.localPosition;
          _dragStartWorldPos = _nodePositionOverrides[hit.user.id] ?? Offset(hit.wx, hit.wy);
        } else {
          // Empty space: immediate lasso (1-finger on empty = lasso in edit mode)
          setState(() {
            _isLasso = true;
            _lassoScreenPoints.clear();
            _lassoScreenPoints.add(e.localPosition);
          });
          _overlayVersion.value++;
        }
      } else {
        // Normal mode: long press detection
        _longPressOrigin = e.localPosition;
        _longPressTimer?.cancel();
        _longPressTimer = Timer(_kLongPressDuration, () {
          final pos = _longPressOrigin;
          if (pos == null) return;
          final hit = _hitTest(pos);
          if (hit != null) widget.onNodeLongPress(hit.user);
          _longPressOrigin = null;
        });
      }
    } else {
      _longPressTimer?.cancel();
      _longPressOrigin = null;
      if (_isLasso) {
        setState(() {
          _isLasso = false;
          _lassoScreenPoints.clear();
        });
        _overlayVersion.value++;
      }
      _draggingNodeId = null;
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

    // ---- Edit mode: drag node / lasso / pan ----
    if (widget.editMode && !widget.is3D && _pointers.length == 1) {
      if (_draggingNodeId != null) {
        final delta = e.localPosition - _dragStartScreenPos!;
        final worldDelta = Offset(delta.dx / _view.scale, delta.dy / _view.scale);
        setState(() {
          _nodePositionOverrides[_draggingNodeId!] = _dragStartWorldPos! + worldDelta;
        });
        _overlayVersion.value++;
        return;
      }
      if (_isLasso) {
        setState(() => _lassoScreenPoints.add(e.localPosition));
        _overlayVersion.value++;
        return;
      }
      // Empty space swipe = pan (fall through to normal pan logic below)
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
        final ratio = d / prev;
        _virtualScale = (_virtualScale * ratio).clamp(0.05, 3.5);

        if (!widget.sortMode && _virtualScale < _kMinNormalScale) {
          // Rubber-band resistance: displayed scale resists the pull
          final deficit = _kMinNormalScale - _virtualScale;
          newScale = (_kMinNormalScale - deficit * 0.32).clamp(0.10, 3.5);
          final depth = (deficit / (_kMinNormalScale - _kSortSnapThreshold)).clamp(0.0, 1.0);
          if ((depth - _rubberBandDepth).abs() > 0.005) {
            setState(() => _rubberBandDepth = depth);
            _overlayVersion.value++;
          }
          if (_virtualScale < _kSortSnapThreshold) {
            // Snap to sort mode ("ぐんっ" transition)
            _virtualScale = _kMinNormalScale;
            setState(() => _rubberBandDepth = 0.0);
            _overlayVersion.value++;
            widget.onSortModeChanged?.call(true);
            newScale = _kMinNormalScale;
          }
        } else {
          newScale = _virtualScale.clamp(0.10, 3.5);
          if (_rubberBandDepth != 0.0) {
            setState(() => _rubberBandDepth = 0.0);
            _overlayVersion.value++;
          }
        }
      }

      if (widget.is3D) {
        final ratio = newScale / _view.scale;
        _view.update(
          scale: newScale,
          pan: Offset(_view.pan.dx * ratio + delta.dx, _view.pan.dy * ratio + delta.dy),
        );
      } else {
        final prevFocal = _prevFocal!;
        final cx = _lastSize.width / 2;
        final cy = _lastSize.height / 2;
        final ratio = newScale / _view.scale;
        final newPan = Offset(
          focal.dx - cx - (prevFocal.dx - cx - _view.pan.dx) * ratio,
          focal.dy - cy - (prevFocal.dy - cy - _view.pan.dy) * ratio,
        );
        _view.update(scale: newScale, pan: newPan);
      }
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

      // Lasso completion
      if (widget.editMode && _isLasso && _lassoScreenPoints.length > 3) {
        _finishLasso();
      }

      // Reset drag state
      if (_draggingNodeId != null) {
        _draggingNodeId = null;
        _dragStartScreenPos = null;
        _dragStartWorldPos = null;
      }

      // Reset lasso state if not finishing
      if (_isLasso && _lassoScreenPoints.length <= 3) {
        setState(() {
          _isLasso = false;
          _lassoScreenPoints.clear();
        });
        _overlayVersion.value++;
      }

      // Single tap
      if (tap && wasSinglePointer && timerStillActive && origin != null && !widget.editMode) {
        _handleTap(origin);
      }

      // Snap back from rubber-band zone on release
      if (!widget.sortMode && _virtualScale < _kMinNormalScale) {
        _virtualScale = _kMinNormalScale;
        _view.update(scale: _kMinNormalScale);
        setState(() => _rubberBandDepth = 0.0);
        _overlayVersion.value++;
      }
    } else {
      _prevFocal = _focal();
      _prevDist = _dist();
    }
  }

  Offset? _focal() {
    if (_pointers.isEmpty) return null;
    return _pointers.values.reduce((a, b) => a + b) / _pointers.length.toDouble();
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
      final centerChanged = widget.useConcentricLayout && _lastCenterId != _centerId;
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
          child: ValueListenableBuilder<int>(
            valueListenable: _overlayVersion,
            builder: (_, __, ___) => CustomPaint(
              size: size,
              painter: _GraphPainter(
                doodles: _doodles,
                worldNodes: _worldNodes,
                worldEdges: _worldEdges,
                is3D: widget.is3D,
                useConcentricLayout: widget.useConcentricLayout,
                fadeNonDirect: widget.fadeNonDirect,
                highlightedIds: widget.highlightedIds,
                showEdges: widget.showEdges,
                view: _view,
                profileImages: _profileImages,
                imageVersion: _imageVersion,
                animFrom: _animFrom,
                animT: _animT,
                palette: activeProfile,
                nodeOverrides: Map.unmodifiable(_nodePositionOverrides),
                groups: widget.groups,
                lassoPoints: List.unmodifiable(_lassoScreenPoints),
                sortMode: widget.sortMode,
                decoStyle: decoStyleNotifier.value,
                editMode: widget.editMode,
                rubberBandDepth: _rubberBandDepth,
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ---------------- Force-directed Layout ----------------

class _FRLayout {
  static (List<double>, List<double>, List<int>) computeConcentric({
    required int n,
    required List<String> userIds,
    required String centerId,
    required List<(int, int, double)> edges,
    required double shortSide,
  }) {
    final px = List<double>.filled(n, 0.0);
    final py = List<double>.filled(n, 0.0);
    final idToIdx = <String, int>{for (int i = 0; i < n; i++) userIds[i]: i};
    final centerIdx = idToIdx[centerId] ?? 0;

    final adj = List<List<int>>.generate(n, (_) => <int>[]);
    for (final (i, j, _) in edges) { adj[i].add(j); adj[j].add(i); }

    final ringOf = List<int>.filled(n, -1);
    final parent = List<int>.filled(n, -1);
    ringOf[centerIdx] = 0;
    final queue = <int>[centerIdx];
    final rings = <int, List<int>>{0: [centerIdx]};

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      final d = ringOf[cur];
      for (final nb in adj[cur]) {
        if (ringOf[nb] == -1) {
          ringOf[nb] = d + 1;
          parent[nb] = cur;
          queue.add(nb);
          rings.putIfAbsent(d + 1, () => <int>[]).add(nb);
        }
      }
    }

    final isolated = <int>[];
    for (int i = 0; i < n; i++) { if (ringOf[i] == -1) isolated.add(i); }
    if (isolated.isNotEmpty) {
      final maxRing = rings.keys.reduce(max) + 1;
      rings[maxRing] = isolated;
      for (final i in isolated) ringOf[i] = maxRing;
    }

    const double ringGap = 108.0;
    const double nodeArcDirect = 58.0;
    const double nodeArcOther  = 44.0;

    double prevRadius = 0;
    final sortedKeys = rings.keys.toList()..sort();

    for (final ring in sortedKeys) {
      if (ring == 0) continue;
      final nodes = rings[ring]!;
      final byParent = <int, List<int>>{};
      for (final idx in nodes) byParent.putIfAbsent(parent[idx], () => []).add(idx);
      final parentKeys = byParent.keys.toList()
        ..sort((a, b) {
          if (a == -1) return 1;
          if (b == -1) return -1;
          return atan2(py[a], px[a]).compareTo(atan2(py[b], px[b]));
        });
      final orderedNodes = <int>[];
      for (final p in parentKeys) {
        orderedNodes.addAll(_orderGroupByConnection(byParent[p]!, edges));
      }

      final arc = ring == 1 ? nodeArcDirect : nodeArcOther;
      final minByArc = orderedNodes.length * arc / (2 * pi);
      final radius = max(prevRadius + ringGap, minByArc);

      for (int i = 0; i < orderedNodes.length; i++) {
        final angle = 2 * pi * i / orderedNodes.length - pi / 2;
        px[orderedNodes[i]] = radius * cos(angle);
        py[orderedNodes[i]] = radius * sin(angle);
      }
      prevRadius = radius;
    }

    _separateNodesFromEdges(n: n, px: px, py: py, edges: edges,
        anchored: {centerIdx}, nodeRadius: 11.0, clearance: 8.0, passes: 60);
    return (px, py, ringOf);
  }

  static void _separateNodesFromEdges({
    required int n, required List<double> px, required List<double> py,
    required List<(int, int, double)> edges, required Set<int> anchored,
    double nodeRadius = 14.0, double clearance = 10.0, int passes = 80,
  }) {
    final minDist = nodeRadius + clearance;
    for (int pass = 0; pass < passes; pass++) {
      bool any = false;
      for (final (ei, ej, _) in edges) {
        final ax = px[ei], ay = py[ei];
        final bx = px[ej], by = py[ej];
        final edgeLen2 = (bx - ax) * (bx - ax) + (by - ay) * (by - ay);
        if (edgeLen2 < 4.0) continue;
        final invLen2 = 1.0 / edgeLen2;
        for (int k = 0; k < n; k++) {
          if (k == ei || k == ej || anchored.contains(k)) continue;
          final t = ((px[k] - ax) * (bx - ax) + (py[k] - ay) * (by - ay)) * invLen2;
          if (t < 0.08 || t > 0.92) continue;
          final nearX = ax + t * (bx - ax);
          final nearY = ay + t * (by - ay);
          final dx = px[k] - nearX;
          final dy = py[k] - nearY;
          final d2 = dx * dx + dy * dy;
          if (d2 >= minDist * minDist) continue;
          any = true;
          final d = sqrt(d2);
          final push = (minDist - d) * 0.55;
          if (d < 0.5) {
            final invLen = 1.0 / sqrt(edgeLen2);
            px[k] += -(by - ay) * invLen * push;
            py[k] += (bx - ax) * invLen * push;
          } else {
            px[k] += dx / d * push;
            py[k] += dy / d * push;
          }
        }
      }
      if (!any) break;
    }
  }

  static List<int> _orderGroupByConnection(List<int> group, List<(int, int, double)> edges) {
    if (group.length <= 2) return List.from(group);
    final groupSet = group.toSet();
    final weights = <(int, int), double>{};
    for (final (a, b, w) in edges) {
      if (groupSet.contains(a) && groupSet.contains(b)) {
        weights[(a, b)] = w; weights[(b, a)] = w;
      }
    }
    final result = <int>[group.first];
    final rem = group.sublist(1).toSet();
    while (rem.isNotEmpty) {
      final last = result.last;
      int? best; double bestW = -1;
      for (final r in rem) {
        final w = weights[(last, r)] ?? 0.0;
        if (w > bestW) { bestW = w; best = r; }
      }
      result.add(best ?? rem.first);
      rem.remove(result.last);
    }
    return result;
  }

  static List<int> _detectCommunities({
    required int n, required List<(int, int, double)> edges, int iterations = 20,
  }) {
    final rng = Random(42);
    final labels = List<int>.generate(n, (i) => i);
    for (int iter = 0; iter < iterations; iter++) {
      final order = List<int>.generate(n, (i) => i)..shuffle(rng);
      bool changed = false;
      for (final i in order) {
        final votes = <int, double>{};
        for (final (a, b, w) in edges) {
          if (a == i) votes.update(labels[b], (v) => v + w, ifAbsent: () => w);
          else if (b == i) votes.update(labels[a], (v) => v + w, ifAbsent: () => w);
        }
        if (votes.isEmpty) continue;
        final best = votes.entries.reduce((x, y) => x.value >= y.value ? x : y).key;
        if (best != labels[i]) { labels[i] = best; changed = true; }
      }
      if (!changed) break;
    }
    final unique = labels.toSet().toList()..sort();
    final map = {for (int i = 0; i < unique.length; i++) unique[i]: i};
    return labels.map((l) => map[l]!).toList();
  }

  static (List<double>, List<double>) compute2DGrouped({
    required int n, required int selfIdx,
    required List<(int, int, double)> edges,
    required double shortSide, int iterations = 130,
  }) {
    if (n == 0) return (<double>[], <double>[]);
    final rng = Random(42);
    final px = List<double>.filled(n, 0);
    final py = List<double>.filled(n, 0);

    final communities = _detectCommunities(n: n, edges: edges);
    final communityGroups = <int, List<int>>{};
    for (int i = 0; i < n; i++) communityGroups.putIfAbsent(communities[i], () => []).add(i);
    final sortedCIds = communityGroups.keys.toList()
      ..sort((a, b) => communityGroups[b]!.length.compareTo(communityGroups[a]!.length));

    final selfCommunity = communities[selfIdx];
    final otherCIds = sortedCIds.where((c) => c != selfCommunity).toList();
    final centX = <int, double>{selfCommunity: 0.0};
    final centY = <int, double>{selfCommunity: 0.0};
    final centroidR = shortSide * 0.48;
    for (int ci = 0; ci < otherCIds.length; ci++) {
      final angle = 2 * pi * ci / max(otherCIds.length, 1) - pi / 2;
      centX[otherCIds[ci]] = centroidR * cos(angle);
      centY[otherCIds[ci]] = centroidR * sin(angle);
    }

    for (int i = 0; i < n; i++) {
      if (i == selfIdx) continue;
      final c = communities[i];
      final angle = 2 * pi * rng.nextDouble();
      final r = shortSide * 0.06 * (0.5 + rng.nextDouble());
      px[i] = centX[c]! + r * cos(angle);
      py[i] = centY[c]! + r * sin(angle);
    }

    final area = shortSide * shortSide;
    final k = sqrt(area / max(n, 4)) * 1.4;
    const double minGap = 50.0;
    double temp = shortSide * 0.09;
    final fx = List<double>.filled(n, 0);
    final fy = List<double>.filled(n, 0);

    for (int iter = 0; iter < iterations; iter++) {
      for (int i = 0; i < n; i++) { fx[i] = 0; fy[i] = 0; }
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          double dx = px[i] - px[j], dy = py[i] - py[j];
          double dist = sqrt(dx * dx + dy * dy);
          if (dist < 0.5) {
            dx = (rng.nextDouble() - 0.5) * 6; dy = (rng.nextDouble() - 0.5) * 6;
            dist = sqrt(dx * dx + dy * dy);
            if (dist < 0.01) dist = 0.01;
          }
          final invDist = 1 / dist;
          var force = (k * k) * invDist;
          if (dist < minGap) force += (minGap - dist) * 14;
          fx[i] += dx * invDist * force; fy[i] += dy * invDist * force;
          fx[j] -= dx * invDist * force; fy[j] -= dy * invDist * force;
        }
      }
      for (final (i, j, mult) in edges) {
        final dx = px[i] - px[j], dy = py[i] - py[j];
        double dist = sqrt(dx * dx + dy * dy);
        if (dist < 1) dist = 1;
        final invDist = 1 / dist;
        final force = (dist * dist) / k * mult;
        fx[i] -= dx * invDist * force; fy[i] -= dy * invDist * force;
        fx[j] += dx * invDist * force; fy[j] += dy * invDist * force;
      }
      for (int i = 0; i < n; i++) {
        if (i == selfIdx) continue;
        final c = communities[i];
        fx[i] -= (px[i] - centX[c]!) * 0.014;
        fy[i] -= (py[i] - centY[c]!) * 0.014;
        fx[i] -= px[i] * 0.001;
        fy[i] -= py[i] * 0.001;
      }
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

    for (int pass = 0; pass < 120; pass++) {
      bool anyOverlap = false;
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          final dx = px[i] - px[j], dy = py[i] - py[j];
          final d = sqrt(dx * dx + dy * dy);
          if (d < minGap && d > 0.01) {
            final push = (minGap - d) * 0.55;
            final nx = dx / d, ny = dy / d;
            if (i == selfIdx) { px[j] -= nx * push * 2; py[j] -= ny * push * 2; }
            else if (j == selfIdx) { px[i] += nx * push * 2; py[i] += ny * push * 2; }
            else { px[i] += nx * push; py[i] += ny * push; px[j] -= nx * push; py[j] -= ny * push; }
            anyOverlap = true;
          }
        }
      }
      if (!anyOverlap) break;
    }
    px[selfIdx] = 0; py[selfIdx] = 0;
    _separateNodesFromEdges(n: n, px: px, py: py, edges: edges, anchored: {selfIdx});
    px[selfIdx] = 0; py[selfIdx] = 0;
    return (px, py);
  }

  static (List<double>, List<double>, List<double>) compute3D({
    required int n, required int selfIdx,
    required List<(int, int, double)> edges,
    required double shortSide, int iterations = 90,
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
      for (int i = 0; i < n; i++) { fx[i] = 0; fy[i] = 0; fz[i] = 0; }
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          double dx = px[i]-px[j], dy = py[i]-py[j], dz = pz[i]-pz[j];
          double dist = sqrt(dx*dx + dy*dy + dz*dz);
          if (dist < 0.5) {
            dx=(rng.nextDouble()-0.5)*5; dy=(rng.nextDouble()-0.5)*5; dz=(rng.nextDouble()-0.5)*5;
            dist = sqrt(dx*dx+dy*dy+dz*dz);
            if (dist < 0.01) dist = 0.01;
          }
          final invDist = 1/dist;
          var force = (k*k)*invDist;
          if (dist < minDist) force += (minDist-dist)*8;
          fx[i]+=dx*invDist*force; fy[i]+=dy*invDist*force; fz[i]+=dz*invDist*force;
          fx[j]-=dx*invDist*force; fy[j]-=dy*invDist*force; fz[j]-=dz*invDist*force;
        }
      }
      for (final (i,j,mult) in edges) {
        final dx=px[i]-px[j], dy=py[i]-py[j], dz=pz[i]-pz[j];
        double dist = sqrt(dx*dx+dy*dy+dz*dz);
        if (dist<1) dist=1;
        final invDist=1/dist;
        final force=(dist*dist)/k*mult;
        fx[i]-=dx*invDist*force; fy[i]-=dy*invDist*force; fz[i]-=dz*invDist*force;
        fx[j]+=dx*invDist*force; fy[j]+=dy*invDist*force; fz[j]+=dz*invDist*force;
      }
      for (int i=0; i<n; i++) {
        if (i==selfIdx) continue;
        fx[i]-=px[i]*0.006; fy[i]-=py[i]*0.006; fz[i]-=pz[i]*0.006;
      }
      for (int i=0; i<n; i++) {
        if (i==selfIdx) { px[i]=0; py[i]=0; pz[i]=0; continue; }
        final mag=sqrt(fx[i]*fx[i]+fy[i]*fy[i]+fz[i]*fz[i]);
        if (mag<0.001) continue;
        final clamped=min(mag,temp);
        px[i]+=fx[i]/mag*clamped; py[i]+=fy[i]/mag*clamped; pz[i]+=fz[i]/mag*clamped;
      }
      temp = max(temp*0.965, 0.4);
    }
    return (px, py, pz);
  }
}

// ---------------- Painter ----------------

class _GraphPainter extends CustomPainter {
  static const double _fov = 460.0;

  final List<_Doodle> doodles;
  final List<_WorldNode> worldNodes;
  final List<_WorldEdge> worldEdges;
  final bool is3D;
  final bool useConcentricLayout;
  final bool fadeNonDirect;
  final List<String>? highlightedIds;
  final bool showEdges;
  final GraphViewState view;
  final Map<String, ui.Image> profileImages;
  final int imageVersion;
  final Map<String, Offset> animFrom;
  final ValueNotifier<double> animT;
  final ColorProfile palette;
  // New fields
  final Map<String, Offset> nodeOverrides;
  final List<Group> groups;
  final List<Offset> lassoPoints;
  final bool sortMode;
  final DecoStyle decoStyle;
  final bool editMode;
  final double rubberBandDepth;

  final _fillPaint = Paint();
  final _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final _glowPaint = Paint();
  final _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final _gridPaint = Paint()..strokeCap = StrokeCap.round;

  ui.Picture? _bgPicture;
  Size _bgPictureSize = Size.zero;

  _GraphPainter({
    required this.doodles,
    required this.worldNodes,
    required this.worldEdges,
    required this.is3D,
    required this.useConcentricLayout,
    required this.fadeNonDirect,
    required this.highlightedIds,
    required this.showEdges,
    required this.view,
    required this.profileImages,
    required this.imageVersion,
    required this.animFrom,
    required this.animT,
    required this.palette,
    required this.nodeOverrides,
    required this.groups,
    required this.lassoPoints,
    required this.sortMode,
    required this.decoStyle,
    required this.editMode,
    required this.rubberBandDepth,
  }) : super(repaint: Listenable.merge([view, animT]));

  double _nodeOpacity(_WorldNode node) {
    if (sortMode) {
      final highlighted = highlightedIds == null || highlightedIds!.contains(node.user.id);
      return highlighted ? 1.0 : 0.15;
    }
    if (useConcentricLayout && !is3D && node.ringDepth >= 0) {
      final d = node.ringDepth;
      if (d <= 1) return 1.0;
      if (d == 2) return 0.50;
      if (d == 3) return 0.24;
      return 0.12;
    }
    final primary = _isPrimary(node.user);
    final highlighted = highlightedIds == null || highlightedIds!.contains(node.user.id);
    if (!highlighted) return 0.18;
    if (!primary) return 0.45;
    return 1.0;
  }

  bool _isPrimary(User u) {
    if (!fadeNonDirect) return true;
    return u.id == 'self' || u.isDirect;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    if (worldNodes.isEmpty) return;

    canvas.save();
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.translate(cx + view.pan.dx, cy + view.pan.dy);
    canvas.scale(view.scale);
    canvas.translate(-cx, -cy);

    final inv = 1.0 / view.scale;
    final bounds = Rect.fromPoints(
      Offset((0 - cx - view.pan.dx) * inv + cx, (0 - cy - view.pan.dy) * inv + cy),
      Offset((size.width - cx - view.pan.dx) * inv + cx,
          (size.height - cy - view.pan.dy) * inv + cy),
    );

    if (!sortMode) {
      _drawDotGrid(canvas, bounds);
      _drawDoodles(canvas, cx, cy);
    }

    final n = worldNodes.length;
    final posList = List<Offset>.filled(n, Offset.zero);
    final radList = List<double>.filled(n, 0);
    final depths = List<double>.filled(n, 0);
    final comp = (1.0 / view.scale).clamp(0.45, 1.7);
    // Build id → index map for groups
    final idToIdx = <String, int>{for (int i = 0; i < n; i++) worldNodes[i].user.id: i};

    if (is3D) {
      final cosX = cos(view.rotX), sinX = sin(view.rotX);
      final cosY = cos(view.rotY), sinY = sin(view.rotY);
      for (int i = 0; i < n; i++) {
        final node = worldNodes[i];
        final wx = nodeOverrides[node.user.id]?.dx ?? node.wx;
        final wy = nodeOverrides[node.user.id]?.dy ?? node.wy;
        final x1 = wx * cosY + node.wz * sinY;
        final z1 = -wx * sinY + node.wz * cosY;
        final y2 = wy * cosX - z1 * sinX;
        final z2 = wy * sinX + z1 * cosX;
        final dz = max(z2 + _fov, 20.0);
        final s = _fov / dz;
        posList[i] = Offset(cx + x1 * s, cy + y2 * s);
        radList[i] = node.baseRadius * s.clamp(0.45, 1.5) * comp;
        depths[i] = z2;
      }
    } else {
      final t = animT.value;
      final animating = t < 1.0 && animFrom.isNotEmpty;
      for (int i = 0; i < n; i++) {
        final node = worldNodes[i];
        double wx = nodeOverrides[node.user.id]?.dx ?? node.wx;
        double wy = nodeOverrides[node.user.id]?.dy ?? node.wy;
        if (animating && nodeOverrides[node.user.id] == null) {
          final from = animFrom[node.user.id];
          if (from != null) {
            wx = ui.lerpDouble(from.dx, wx, t)!;
            wy = ui.lerpDouble(from.dy, wy, t)!;
          }
        }
        posList[i] = Offset(cx + wx, cy + wy);
        radList[i] = node.baseRadius * comp;
        depths[i] = 0;
      }
    }

    // ---- Group circles (draw before nodes) ----
    if (!sortMode) {
      _drawGroups(canvas, posList, idToIdx);
    }

    // ---- Edges ----
    if (showEdges && !sortMode) {
      for (final e in worldEdges) {
        if (e.fromIdx >= n || e.toIdx >= n) continue;
        double alpha = e.opacity;
        double width = e.thickness;
        if (useConcentricLayout && !is3D) {
          if (e.isPrimary) { alpha = (e.opacity * 2.4).clamp(0.0, 0.82); width = e.thickness * 1.7; }
          else { alpha = e.opacity * 0.20; }
        }
        _edgePaint
          ..color = palette.ink.withValues(alpha: (alpha * 1.5).clamp(0.0, 0.9))
          ..strokeWidth = width * comp;
        _drawSketchEdge(canvas, posList[e.fromIdx], posList[e.toIdx], _edgePaint,
            e.fromIdx * 911 + e.toIdx, dashed: e.dashed);
      }
    }

    // Depth sort for 3D
    final order = List<int>.generate(n, (i) => i);
    if (is3D) order.sort((a, b) => depths[b].compareTo(depths[a]));

    // ---- Nodes ----
    if (sortMode) {
      _drawSortModeNodes(canvas, order, posList, radList);
    } else {
      for (final i in order) {
        _drawNodeBody(canvas, worldNodes[i], posList[i], radList[i]);
        _drawNodeRings(canvas, worldNodes[i], posList[i], radList[i]);
      }
    }

    // Edit mode: highlight dragged node
    if (editMode) {
      for (int i = 0; i < n; i++) {
        if (nodeOverrides.containsKey(worldNodes[i].user.id)) {
          _fillPaint.color = palette.accent.withValues(alpha: 0.25);
          canvas.drawCircle(posList[i], radList[i] + 4, _fillPaint);
        }
      }
    }

    canvas.restore();

    // ---- Lasso overlay (screen space) ----
    if (lassoPoints.length >= 2) {
      _drawLasso(canvas);
    }

    // ---- Sort pull indicator (rubber-band tension visualization) ----
    if (rubberBandDepth > 0.0 && !sortMode) {
      _drawSortPullIndicator(canvas, size);
    }
  }

  void _drawSortPullIndicator(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final t = rubberBandDepth;

    // Expanding ring that shows tension building up
    final r = 18.0 + t * 18.0;
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = palette.accent.withValues(alpha: t * 0.14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = palette.accent.withValues(alpha: 0.25 + t * 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + t * 2.2,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'sort',
        style: TextStyle(
          color: palette.ink.withValues(alpha: 0.25 + t * 0.55),
          fontSize: 9.0 + t * 3.0,
          fontWeight: FontWeight.w700,
          fontFamily: AppTheme.bodyFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    tp.dispose();
  }

  // ---- Group shapes: axis-aligned rounded rectangles ----

  void _drawGroups(Canvas canvas, List<Offset> posList, Map<String, int> idToIdx) {
    for (final group in groups) {
      final memberPos = group.memberIds
          .map((id) => idToIdx[id] != null ? posList[idToIdx[id]!] : null)
          .whereType<Offset>()
          .toList();
      if (memberPos.isEmpty) continue;

      double minX = memberPos.first.dx, maxX = memberPos.first.dx;
      double minY = memberPos.first.dy, maxY = memberPos.first.dy;
      for (final p in memberPos) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      const pad = 42.0;
      const cornerR = 20.0;
      final rect = Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(cornerR));

      // Fill
      canvas.drawRRect(rrect, Paint()..color = group.color.withValues(alpha: 0.09));
      // Border (dashed look via two paints)
      canvas.drawRRect(rrect,
          Paint()
            ..color = group.color.withValues(alpha: 0.50)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);

      // Label — top-left of the box
      final tp = TextPainter(
        text: TextSpan(
          text: group.name,
          style: TextStyle(
            color: group.color.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: AppTheme.bodyFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(minX - pad + 8, minY - pad - tp.height - 4));
      tp.dispose();
    }
  }

  // ---- Sort mode: uniform abstract dots ----

  void _drawSortModeNodes(
      Canvas canvas, List<int> order, List<Offset> posList, List<double> radList) {
    for (final i in order) {
      final node = worldNodes[i];
      final isSelf = node.user.id == 'self';
      final opacity = _nodeOpacity(node);
      final dotR = isSelf ? 10.0 : 6.0;
      final color = isSelf
          ? palette.accent.withValues(alpha: opacity)
          : (highlightedIds != null && highlightedIds!.contains(node.user.id))
              ? palette.ink.withValues(alpha: opacity * 0.75)
              : palette.ink.withValues(alpha: opacity * 0.25);
      canvas.drawCircle(posList[i], dotR, Paint()..color = color);
    }
  }

  // ---- Lasso ----

  void _drawLasso(Canvas canvas) {
    final path = Path()..moveTo(lassoPoints.first.dx, lassoPoints.first.dy);
    for (final p in lassoPoints.skip(1)) path.lineTo(p.dx, p.dy);
    if (lassoPoints.length > 2) path.close();

    canvas.drawPath(path,
        Paint()
          ..color = palette.accent.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill);
    canvas.drawPath(path,
        Paint()
          ..color = palette.accent.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  // ---- Background ----

  void _drawBackground(Canvas canvas, Size size) {
    switch (decoStyle) {
      case DecoStyle.sketchbook:
        _drawPaper(canvas, size);
      case DecoStyle.starry:
        _drawStarryBackground(canvas, size);
      case DecoStyle.sakura:
        _drawSakuraBackground(canvas, size);
      case DecoStyle.ocean:
        _drawOceanBackground(canvas, size);
    }
  }

  void _drawPaper(Canvas canvas, Size size) {
    if (_bgPicture == null || _bgPictureSize != size) {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      final full = Rect.fromLTWH(0, 0, size.width, size.height);
      c.drawRect(full,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.background, palette.paperLow],
            ).createShader(full));
      _bgPicture = recorder.endRecording();
      _bgPictureSize = size;
    }
    canvas.drawPicture(_bgPicture!);
  }

  void _drawStarryBackground(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0D0D2B));
    final rng = Random(99);
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (int i = 0; i < 140; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.5 + rng.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), r, starPaint..color = Colors.white.withValues(alpha: 0.3 + rng.nextDouble() * 0.6));
    }
  }

  void _drawSakuraBackground(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFFFF0F5), const Color(0xFFFFE4EC)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final rng = Random(77);
    final petalPaint = Paint()
      ..color = const Color(0xFFFFB7CC).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rng.nextDouble() * pi);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero,
            width: 10 + rng.nextDouble() * 14, height: 6 + rng.nextDouble() * 8),
        petalPaint,
      );
      canvas.restore();
    }
  }

  void _drawOceanBackground(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0A2F5E), const Color(0xFF0E4D8A)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int wave = 0; wave < 6; wave++) {
      final path = Path();
      final baseY = size.height * (0.2 + wave * 0.12);
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 8) {
        path.lineTo(x, baseY + sin(x * 0.02 + wave) * 12);
      }
      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawDotGrid(Canvas canvas, Rect bounds) {
    const gap = 26.0;
    final startX = (bounds.left / gap).floorToDouble() * gap;
    final startY = (bounds.top / gap).floorToDouble() * gap;
    final points = <Offset>[];
    for (double y = startY; y <= bounds.bottom; y += gap) {
      for (double x = startX; x <= bounds.right; x += gap) {
        points.add(Offset(x, y));
      }
    }
    _gridPaint..color = palette.ink.withValues(alpha: 0.09)..strokeWidth = 2.0;
    canvas.drawPoints(ui.PointMode.points, points, _gridPaint);
  }

  void _drawDoodles(Canvas canvas, double cx, double cy) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillP = Paint()..style = PaintingStyle.fill;
    for (final d in doodles) {
      canvas.save();
      canvas.translate(cx + d.pos.dx, cy + d.pos.dy);
      canvas.rotate(d.rotation);
      canvas.scale(d.size);
      if (d.kind == _DoodleKind.dot) {
        fillP.color = palette.ink.withValues(alpha: d.opacity);
        canvas.drawPath(d.path, fillP);
      } else {
        stroke
          ..color = palette.ink.withValues(alpha: d.opacity)
          ..strokeWidth = 1.5 / d.size;
        canvas.drawPath(d.path, stroke);
      }
      canvas.restore();
    }
  }

  void _drawSketchEdge(Canvas canvas, Offset a, Offset b, Paint paint, int seed,
      {bool dashed = false}) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 6) { canvas.drawLine(a, b, paint); return; }
    final nx = -dy / len, ny = dx / len;
    final amp = (len * 0.04).clamp(1.5, 9.0);
    final o1 = _seedNoise(seed) * amp;
    final o2 = _seedNoise(seed * 31 + 7) * amp;
    final c1 = Offset(a.dx + dx * 0.33 + nx * o1, a.dy + dy * 0.33 + ny * o1);
    final c2 = Offset(a.dx + dx * 0.66 + nx * o2, a.dy + dy * 0.66 + ny * o2);
    final path = ui.Path()..moveTo(a.dx, a.dy)..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.dx, b.dy);
    if (!dashed) { canvas.drawPath(path, paint); return; }
    const dash = 5.0, gapLen = 4.5;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist = end + gapLen;
      }
    }
  }

  void _drawNodeBody(Canvas canvas, _WorldNode node, Offset pos, double r) {
    final isSelf = node.user.id == 'self';
    Color fill;
    double globalOpacity;
    bool showGlow;

    if (useConcentricLayout && !is3D && node.ringDepth >= 0) {
      fill = isSelf ? palette.accent : node.user.nodeColor;
      final depth = node.ringDepth;
      if (depth <= 1) { globalOpacity = 1.0; showGlow = true; }
      else if (depth == 2) { globalOpacity = 0.50; showGlow = false; }
      else if (depth == 3) { globalOpacity = 0.24; showGlow = false; }
      else { globalOpacity = 0.12; showGlow = false; }
    } else {
      final primary = _isPrimary(node.user);
      final highlighted = highlightedIds == null || highlightedIds!.contains(node.user.id);
      fill = isSelf ? palette.accent : (!primary ? _desaturate(node.user.nodeColor, 1.0) : node.user.nodeColor);
      globalOpacity = !highlighted ? 0.18 : (!primary ? 0.45 : 1.0);
      showGlow = primary && highlighted;
    }

    final gap = (r * 0.24).clamp(3.0, 7.0);
    final rIcon = (r - gap).clamp(r * 0.5, r);

    if (showGlow) {
      _glowPaint.color = fill.withValues(alpha: 0.10 * globalOpacity);
      canvas.drawCircle(pos, r * 1.7, _glowPaint);
    }
    _fillPaint.color = palette.background;
    canvas.drawCircle(pos, r, _fillPaint);
    _fillPaint.color = fill.withValues(alpha: 0.45 * globalOpacity);
    canvas.drawCircle(pos, rIcon, _fillPaint);

    final detailed = globalOpacity >= 0.35;
    if (detailed) {
      final profileImg = isSelf ? null : profileImages[node.user.id];
      if (profileImg != null) {
        _drawProfileImage(canvas, profileImg, pos, rIcon, globalOpacity);
      } else {
        final ep = node.emojiPainter;
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        final s = (rIcon / node.baseRadius).clamp(0.2, 1.0);
        canvas.scale(s);
        ep.paint(canvas, Offset(-ep.width / 2, -ep.height / 2));
        canvas.restore();
      }
    }
    if (!detailed) return;
    if (globalOpacity > 0.5 && node.namePainter != null) {
      final np = node.namePainter!;
      final comp = (1.0 / view.scale).clamp(0.45, 1.7);
      canvas.save();
      canvas.translate(pos.dx, pos.dy + r);
      canvas.scale(comp);
      np.paint(canvas, Offset(-np.width / 2, 5));
      canvas.restore();
    }
  }

  void _drawNodeRings(Canvas canvas, _WorldNode node, Offset pos, double r) {
    final opacity = _nodeOpacity(node);
    if (opacity <= 0.001) return;
    final isSelf = node.user.id == 'self';
    final comp = (1.0 / view.scale).clamp(0.45, 1.7);
    final gap = (r * 0.24).clamp(3.0, 7.0);
    final rIcon = (r - gap).clamp(r * 0.5, r);
    _rimPaint
      ..color = palette.inkLine.withValues(alpha: (0.85 * opacity).clamp(0.0, 1.0))
      ..strokeWidth = (isSelf ? 1.9 : 1.4) * comp;
    canvas.drawCircle(pos, rIcon, _rimPaint);
    _rimPaint
      ..color = palette.inkLine.withValues(alpha: (0.95 * opacity).clamp(0.0, 1.0))
      ..strokeWidth = (isSelf ? 2.4 : 1.9) * comp;
    canvas.drawCircle(pos, r, _rimPaint);
  }

  void _drawProfileImage(Canvas canvas, ui.Image img, Offset pos, double r, double opacity) {
    final rect = Rect.fromCircle(center: pos, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final paint = Paint()..filterQuality = FilterQuality.low;
    if (opacity < 1.0) {
      paint.colorFilter = ColorFilter.matrix([
        1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, opacity, 0,
      ]);
    }
    canvas.drawImageRect(img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.worldNodes != worldNodes ||
      old.worldEdges != worldEdges ||
      old.is3D != is3D ||
      old.useConcentricLayout != useConcentricLayout ||
      old.fadeNonDirect != fadeNonDirect ||
      old.highlightedIds != highlightedIds ||
      old.showEdges != showEdges ||
      old.palette != palette ||
      old.imageVersion != imageVersion ||
      old.nodeOverrides != nodeOverrides ||
      old.groups != groups ||
      old.lassoPoints != lassoPoints ||
      old.sortMode != sortMode ||
      old.decoStyle != decoStyle ||
      old.editMode != editMode ||
      old.rubberBandDepth != rubberBandDepth;
}
