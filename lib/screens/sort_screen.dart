import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/user.dart';
import '../models/connection.dart';
import '../theme.dart';
import '../widgets/node_graph_widget.dart';
import '../widgets/profile_bottom_sheet.dart';

const _mbtiList = [
  'すべて', 'ENFP', 'INFP', 'ENFJ', 'INFJ',
  'ENTP', 'INTP', 'ENTJ', 'INTJ',
  'ESFP', 'ISFP', 'ESFJ', 'ISFJ',
  'ESTP', 'ISTP', 'ESTJ', 'ISTJ',
];

const _hobbyList = [
  'すべて', '音楽', '写真', '読書', 'ゲーム', '旅行', 'スポーツ', 'アート', '料理',
  'プログラミング', 'ダンス', '映画',
];

class SortScreen extends StatefulWidget {
  const SortScreen({super.key});

  @override
  State<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends State<SortScreen> {
  bool _is3D = false;
  String _mbtiFilter = 'すべて';
  String _hobbyFilter = 'すべて';
  RelationshipLevel? _levelFilter;
  bool _showAllEdges = false;
  bool _panelOpen = true;

  List<String>? get _highlightedIds {
    if (_mbtiFilter == 'すべて' && _hobbyFilter == 'すべて' && _levelFilter == null) {
      return null;
    }
    return allMockUsers.where((u) {
      if (u.id == 'self') return true;
      bool match = true;
      if (_mbtiFilter != 'すべて') match = match && u.mbti == _mbtiFilter;
      if (_hobbyFilter != 'すべて') {
        match = match && u.hobbies.contains(_hobbyFilter);
      }
      if (_levelFilter != null) {
        final conn = selfConnection(u.id);
        match = match && conn?.level == _levelFilter;
      }
      return match;
    }).map((u) => u.id).toList();
  }

  bool get _showEdges {
    if (_showAllEdges) return true;
    if (_levelFilter != null) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final allUsers = allMockUsers.where((u) => u.id != 'self').toList();
    return Stack(
      children: [
        Positioned.fill(
          child: NodeGraphWidget(
            selfUser: selfUser,
            users: allUsers,
            connections: mockConnections,
            is3D: _is3D,
            fadeNonDirect: false,
            highlightedIds: _highlightedIds,
            showEdges: _showEdges,
            edgeLevelFilter: _levelFilter,
            onNodeLongPress: (user) {
              if (user.id == 'self') {
                ProfileBottomSheet.show(context, user, isSelf: true);
              } else {
                ProfileBottomSheet.show(context, user);
              }
            },
          ),
        ),

        // Top controls
        Positioned(
          top: top + 10,
          left: 18,
          right: 18,
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'sort',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_highlightedIds != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.ink.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_highlightedIds!.length - 1} hit',
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.8),
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const Spacer(),
                  _MonoMiniBtn(
                    label: _is3D ? '3D' : '2D',
                    onTap: () => setState(() => _is3D = !_is3D),
                  ),
                  const SizedBox(width: 6),
                  _MonoMiniBtn(
                    label: 'filter',
                    active: _panelOpen,
                    onTap: () => setState(() => _panelOpen = !_panelOpen),
                  ),
                ],
              ),
              if (_panelOpen) ...[
                const SizedBox(height: 10),
                _FilterPanel(
                  mbtiFilter: _mbtiFilter,
                  hobbyFilter: _hobbyFilter,
                  levelFilter: _levelFilter,
                  showAllEdges: _showAllEdges,
                  onMbtiChanged: (v) => setState(() => _mbtiFilter = v),
                  onHobbyChanged: (v) => setState(() => _hobbyFilter = v),
                  onLevelChanged: (v) => setState(() => _levelFilter = v),
                  onShowAllEdgesChanged: (v) =>
                      setState(() => _showAllEdges = v),
                  onClear: () => setState(() {
                    _mbtiFilter = 'すべて';
                    _hobbyFilter = 'すべて';
                    _levelFilter = null;
                    _showAllEdges = false;
                  }),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MonoMiniBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MonoMiniBtn({
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.accent.withValues(alpha: 0.16)
              : AppTheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppTheme.accent : AppTheme.ink.withValues(alpha: 0.3),
            width: 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppTheme.accent : AppTheme.ink,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String mbtiFilter;
  final String hobbyFilter;
  final RelationshipLevel? levelFilter;
  final bool showAllEdges;
  final ValueChanged<String> onMbtiChanged;
  final ValueChanged<String> onHobbyChanged;
  final ValueChanged<RelationshipLevel?> onLevelChanged;
  final ValueChanged<bool> onShowAllEdgesChanged;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.mbtiFilter,
    required this.hobbyFilter,
    required this.levelFilter,
    required this.showAllEdges,
    required this.onMbtiChanged,
    required this.onHobbyChanged,
    required this.onLevelChanged,
    required this.onShowAllEdgesChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.ink.withValues(alpha: 0.22),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterRow(
            label: 'MBTI',
            child: _DropdownFilter(
              value: mbtiFilter,
              items: _mbtiList,
              onChanged: onMbtiChanged,
            ),
          ),
          const SizedBox(height: 6),
          _FilterRow(
            label: '趣味',
            child: _DropdownFilter(
              value: hobbyFilter,
              items: _hobbyList,
              onChanged: onHobbyChanged,
            ),
          ),
          const SizedBox(height: 6),
          _FilterRow(
            label: '関係',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _LevelChip(
                    label: 'すべて',
                    selected: levelFilter == null,
                    onTap: () => onLevelChanged(null),
                  ),
                  ...RelationshipLevel.values.map((l) => _LevelChip(
                        label: l.label,
                        selected: levelFilter == l,
                        onTap: () =>
                            onLevelChanged(levelFilter == l ? null : l),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '線を表示',
                style: TextStyle(
                  color: AppTheme.ink.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: showAllEdges,
                  onChanged: onShowAllEdgesChanged,
                  activeColor: Colors.white,
                  activeTrackColor: AppTheme.accent,
                  inactiveThumbColor: AppTheme.surfaceElevated,
                  inactiveTrackColor: AppTheme.ink.withValues(alpha: 0.18),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClear,
                child: Text(
                  'reset',
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
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

class _FilterRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FilterRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.ink.withValues(alpha: 0.45),
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownFilter({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceElevated,
          style: TextStyle(color: AppTheme.ink, fontSize: 12),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: AppTheme.ink.withValues(alpha: 0.5),
            size: 14,
          ),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.accent
                : AppTheme.ink.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.ink.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
