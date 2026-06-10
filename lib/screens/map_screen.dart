import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../color_profiles.dart';
import '../app_state.dart';
import '../data/mock_data.dart';
import '../models/user.dart';
import '../models/connection.dart';
import '../models/group.dart';
import '../widgets/node_graph_widget.dart';
import '../widgets/bottom_panel.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../screens/connect_flow_screen.dart';
import '../screens/room_screen.dart';
import '../screens/photo_collage_screen.dart';
import '../screens/sort_screen.dart';

const _mbtiOptions = [
  'すべて', 'ENFP', 'INFP', 'ENFJ', 'INFJ',
  'ENTP', 'INTP', 'ENTJ', 'INTJ',
  'ESFP', 'ISFP', 'ESFJ', 'ISFJ',
  'ESTP', 'ISTP', 'ESTJ', 'ISTJ',
];

const _hobbyOptions = [
  'すべて', '音楽', '写真', '読書', 'ゲーム', '旅行', 'スポーツ', 'アート', '料理',
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _is3D = false;
  int _resetSignal = 0;
  int _relayoutSignal = 0;
  bool _editMode = false;
  bool _sortMode = false;
  bool _settingsOpen = false;

  // Sort mode filters
  String _sortMbti = 'すべて';
  String _sortHobby = 'すべて';

  // Groups
  List<Group> _groups = [];

  // Node visibility
  double _nodeCount = 18;
  double _maxDegree = 3;
  double _pendingNodeCount = 18;
  double _pendingMaxDegree = 3;
  Timer? _debounceTimer;
  final _sheetCtrl = DraggableScrollableController();

  static const _groupColors = [
    Color(0xFF6B7BFB), Color(0xFFE88B6B), Color(0xFF6BC47B),
    Color(0xFFE86B9A), Color(0xFF8B6BE8),
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ---- Computed helpers ----

  List<String>? get _sortHighlightedIds {
    if (_sortMbti == 'すべて' && _sortHobby == 'すべて') return null;
    return allMockUsers.where((u) {
      if (u.id == 'self') return true;
      bool match = true;
      if (_sortMbti != 'すべて') match = match && u.mbti == _sortMbti;
      if (_sortHobby != 'すべて') match = match && u.hobbies.contains(_sortHobby);
      return match;
    }).map((u) => u.id).toList();
  }

  ({List<User> users, List<Connection> conns}) _computeVisible(List<User> extras) {
    if (_sortMode) {
      final all = [...allMockUsers.where((u) => u.id != 'self'), ...extras];
      return (users: all, conns: [...mockConnections, ...extraConnectionsNotifier.value]);
    }
    final base = [...topDirectFriends(6),
      ...pickNonDirectByCount(count: _nodeCount.round(), maxDegree: _maxDegree.round())];
    // include extras that are connected to self
    final extra3 = extras.take(5).toList();
    final all = [...base, ...extra3];
    final ids = {'self', ...all.map((u) => u.id)};
    final conns = [
      ...mockConnections.where((c) => ids.contains(c.userId1) && ids.contains(c.userId2)),
      ...extraConnectionsNotifier.value.where((c) => ids.contains(c.userId1) && ids.contains(c.userId2)),
    ];
    return (users: all, conns: conns);
  }

  // ---- Callbacks ----

  void _handleNodeTap(User user) {
    if (_editMode) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoCollageScreen(user: user)),
    );
  }

  void _handleNodeLongPress(User user) {
    if (user.id == 'self') {
      ProfileBottomSheet.show(context, user, isSelf: true);
    } else {
      ProfileBottomSheet.show(context, user);
    }
  }

  void _handleLassoComplete(Set<String> ids) {
    if (ids.length < 2) return;
    showDialog(
      context: context,
      builder: (ctx) => _GroupNameDialog(
        onConfirm: (name) {
          final color = _groupColors[_groups.length % _groupColors.length];
          setState(() {
            _groups = [
              ..._groups,
              Group(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                color: color,
                memberIds: ids,
              ),
            ];
          });
        },
      ),
    );
  }

  void _handleSortModeChanged(bool active) {
    if (!active || _sortMode) return;
    setState(() => _sortMode = true);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SortScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      if (mounted) setState(() => _sortMode = false);
    });
  }

  void _openConnectFlow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConnectFlowScreen(),
    );
  }

  void _openRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomScreen(creator: selfUser)),
    );
  }

  void _toggleEditMode() {
    setState(() => _editMode = !_editMode);
  }

  void _deleteGroup(String id) {
    setState(() => _groups = _groups.where((g) => g.id != id).toList());
  }

  void _debounce(VoidCallback fn) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) fn();
    });
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ValueListenableBuilder<List<User>>(
        valueListenable: extraUsersNotifier,
        builder: (ctx, extras, _) {
          final visible = _computeVisible(extras);
          return Stack(
            children: [
              // ── Full-screen map ──
              Positioned.fill(
                child: NodeGraphWidget(
                  selfUser: selfUser,
                  users: visible.users,
                  connections: visible.conns,
                  is3D: _is3D,
                  useConcentricLayout: false,
                  fadeNonDirect: !_sortMode,
                  showEdges: !_sortMode,
                  editMode: _editMode,
                  sortMode: _sortMode,
                  groups: _groups,
                  onNodeTap: _handleNodeTap,
                  onNodeLongPress: _handleNodeLongPress,
                  onLassoComplete: _handleLassoComplete,
                  onSortModeChanged: _handleSortModeChanged,
                  highlightedIds: _sortMode ? _sortHighlightedIds : null,
                  resetSignal: _resetSignal,
                  relayoutSignal: _relayoutSignal,
                  bottomReserve: 72,
                ),
              ),

              // ── Top bar ──
              Positioned(
                top: top + 10,
                left: 18,
                right: 14,
                child: _buildTopBar(),
              ),

              // ── Settings panel ──
              if (_settingsOpen && !_sortMode)
                Positioned(
                  top: top + 58,
                  right: 14,
                  child: _buildSettingsPanel(),
                ),

              // ── Edit mode badge ──
              if (_editMode)
                Positioned(
                  top: top + 58,
                  left: 18,
                  child: _buildEditBadge(),
                ),

              // ── Left-side FABs ──
              if (!_sortMode)
                Positioned(
                  left: 14,
                  top: top + 70,
                  child: _buildFabs(),
                ),

              // ── Groups list (edit mode) ──
              if (_editMode && _groups.isNotEmpty)
                Positioned(
                  bottom: 110,
                  left: 14,
                  child: _buildGroupsList(),
                ),

              // ── Draggable bottom sheet ──
              DraggableScrollableSheet(
                controller: _sheetCtrl,
                initialChildSize: 0.08,
                minChildSize: 0.08,
                maxChildSize: 0.86,
                snap: true,
                snapSizes: const [0.08, 0.45, 0.86],
                builder: (bctx, ctrl) => BottomPanel(
                  scrollController: ctrl,
                  sheetController: _sheetCtrl,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---- Sub-builders ----

  Widget _buildTopBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'CONNECT',
          style: AppTheme.display(TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          )),
        ),
        const Spacer(),
        _MapBtn(
          icon: Icons.gps_fixed,
          onTap: () => setState(() => _resetSignal++),
          tooltip: '自分に戻す',
        ),
        const SizedBox(width: 6),
        _MapChip(
          label: _is3D ? '3D' : '2D',
          onTap: () => setState(() => _is3D = !_is3D),
        ),
        const SizedBox(width: 6),
        _MapBtn(
          icon: _settingsOpen ? Icons.close : Icons.tune,
          active: _settingsOpen,
          onTap: () => setState(() => _settingsOpen = !_settingsOpen),
          tooltip: '設定',
        ),
      ],
    );
  }

  Widget _buildFabs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // + Connect
        _Fab(
          icon: Icons.add,
          primary: true,
          onTap: _openConnectFlow,
          tooltip: 'コネクト',
        ),
        const SizedBox(height: 10),
        // Edit toggle
        _Fab(
          icon: _editMode ? Icons.check_rounded : Icons.edit_outlined,
          active: _editMode,
          onTap: _toggleEditMode,
          tooltip: _editMode ? '編集終了' : '編集',
        ),
        if (_editMode) ...[
          const SizedBox(height: 10),
          // Re-layout (auto-arrange with group constraints)
          _Fab(
            icon: Icons.auto_fix_high_outlined,
            onTap: () => setState(() => _relayoutSignal++),
            tooltip: '自動配置',
          ),
        ],
        const SizedBox(height: 10),
        // Room / camera
        _Fab(
          icon: Icons.camera_alt_outlined,
          onTap: _openRoom,
          tooltip: 'ルーム',
        ),
      ],
    );
  }

  Widget _buildEditBadge() {
    return GestureDetector(
      onTap: _toggleEditMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 13, color: AppTheme.accent),
            const SizedBox(width: 5),
            Text(
              '編集モード · ノードをドラッグ / 投げ縄でグループ',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _groups.map((g) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: g.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: g.color.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: g.color),
              ),
              const SizedBox(width: 6),
              Text(g.name,
                  style: TextStyle(
                      color: g.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Text('${g.memberIds.length}人',
                  style: TextStyle(
                      color: g.color.withValues(alpha: 0.7), fontSize: 10)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteGroup(g.id),
                child: Icon(Icons.close, size: 13, color: g.color.withValues(alpha: 0.8)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsLabel('カラーテーマ'),
          const SizedBox(height: 8),
          _ColorPicker(),
          const SizedBox(height: 14),
          _SettingsLabel('デコ'),
          const SizedBox(height: 8),
          _DecoPicker(),
          const SizedBox(height: 14),
          _SettingsLabel('DEBUG'),
          const SizedBox(height: 8),
          _SliderRow(
            label: 'ノード数',
            valueText: '${(_pendingNodeCount + 7).round()}',
            value: _pendingNodeCount,
            min: 0, max: 55,
            onChanged: (v) {
              setState(() => _pendingNodeCount = v);
              _debounce(() => setState(() => _nodeCount = _pendingNodeCount));
            },
          ),
          const SizedBox(height: 4),
          _SliderRow(
            label: '最大次数',
            valueText: '${_pendingMaxDegree.round()}',
            value: _pendingMaxDegree,
            min: 1, max: 5, divisions: 4,
            onChanged: (v) {
              setState(() => _pendingMaxDegree = v);
              _debounce(() => setState(() => _maxDegree = _pendingMaxDegree));
            },
          ),
        ],
      ),
    );
  }
}

// ======= Group name dialog =======

class _GroupNameDialog extends StatefulWidget {
  final Function(String name) onConfirm;
  const _GroupNameDialog({required this.onConfirm});

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'グループ名',
        style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: '例: 大学の友達',
          hintStyle: TextStyle(color: AppTheme.textTertiary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.accent),
          ),
        ),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) {
            widget.onConfirm(v.trim());
            Navigator.pop(context);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('キャンセル',
              style: TextStyle(color: AppTheme.textTertiary)),
        ),
        TextButton(
          onPressed: () {
            final name = _ctrl.text.trim();
            if (name.isNotEmpty) {
              widget.onConfirm(name);
              Navigator.pop(context);
            }
          },
          child: Text('作成',
              style: TextStyle(
                  color: AppTheme.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ======= Sort filter dropdown =======

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value != 'すべて'
                  ? AppTheme.accent.withValues(alpha: 0.6)
                  : AppTheme.ink.withValues(alpha: 0.2),
            ),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontFamily: AppTheme.bodyFamily),
            dropdownColor: AppTheme.surfaceElevated,
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) => v != null ? onChanged(v) : null,
          ),
        ),
      ],
    );
  }
}

// ======= Map button atoms =======

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String tooltip;

  const _MapBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 30, height: 26,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.16)
                : AppTheme.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppTheme.accent
                  : AppTheme.ink.withValues(alpha: 0.28),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon,
              size: 14, color: active ? AppTheme.accent : AppTheme.ink),
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MapChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 26,
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.ink.withValues(alpha: 0.28)),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: AppTheme.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  final IconData icon;
  final bool primary;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  const _Fab({
    required this.icon,
    this.primary = false,
    this.active = false,
    required this.onTap,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? AppTheme.accent
        : active
            ? AppTheme.accent.withValues(alpha: 0.18)
            : AppTheme.surface.withValues(alpha: 0.93);
    final border = primary
        ? AppTheme.accent
        : active
            ? AppTheme.accent
            : AppTheme.ink.withValues(alpha: 0.28);
    final iconColor = primary
        ? Colors.white
        : active
            ? AppTheme.accent
            : AppTheme.ink;

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: primary ? 0 : 1.4),
            boxShadow: primary
                ? [
                    BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

// ======= Settings sub-widgets =======

class _SettingsLabel extends StatelessWidget {
  final String text;
  const _SettingsLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            color: AppTheme.ink.withValues(alpha: 0.45),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5));
  }
}

class _ColorPicker extends StatelessWidget {
  _ColorPicker();

  @override
  Widget build(BuildContext context) {
    final selected = activeProfileIndex.value;
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: [
        for (int i = 0; i < kColorProfiles.length; i++)
          GestureDetector(
            onTap: () => activeProfileIndex.value = i,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
              decoration: BoxDecoration(
                color: kColorProfiles[i].background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: i == selected
                      ? AppTheme.accent
                      : AppTheme.ink.withValues(alpha: 0.2),
                  width: i == selected ? 1.8 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kColorProfiles[i].accent),
                  ),
                  const SizedBox(width: 4),
                  Text(kColorProfiles[i].name,
                      style: TextStyle(
                          color: kColorProfiles[i].textPrimary,
                          fontSize: 9,
                          fontWeight: i == selected
                              ? FontWeight.w700
                              : FontWeight.w500)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DecoPicker extends StatelessWidget {
  const _DecoPicker();

  static const _styles = [
    (DecoStyle.sketchbook, '手書き', '📓'),
    (DecoStyle.starry, '星空', '✨'),
    (DecoStyle.sakura, '桜', '🌸'),
    (DecoStyle.ocean, '海', '🌊'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DecoStyle>(
      valueListenable: decoStyleNotifier,
      builder: (ctx, current, _) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _styles.map((s) {
          final (style, label, emoji) = s;
          final active = current == style;
          return GestureDetector(
            onTap: () => decoStyleNotifier.value = style,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.accent.withValues(alpha: 0.12)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? AppTheme.accent
                      : AppTheme.ink.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(label,
                      style: TextStyle(
                          color: active ? AppTheme.accent : AppTheme.ink,
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: TextStyle(
                  color: AppTheme.ink.withValues(alpha: 0.7), fontSize: 11)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 1.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.ink.withValues(alpha: 0.15),
              thumbColor: AppTheme.accent,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              overlayColor: AppTheme.accent.withValues(alpha: 0.12),
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              value: value,
              min: min, max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 22,
          child: Text(valueText,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
