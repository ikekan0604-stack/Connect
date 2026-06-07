import 'dart:async';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/user.dart';
import '../models/connection.dart';
import '../theme.dart';
import '../widgets/node_graph_widget.dart';
import '../widgets/profile_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _debounce = Duration(milliseconds: 300);

  bool _is3D = false;
  bool _settingsOpen = false;
  int _resetSignal = 0;

  // _pending: scrubber-following value, updated immediately for UI feel
  // _applied: graph-consumed value, updated after debounce
  double _pendingAdditional = 18;
  double _appliedAdditional = 18;
  double _pendingMaxDegree = 3;
  double _appliedMaxDegree = 3;

  Timer? _additionalTimer;
  Timer? _maxDegreeTimer;

  int get _displayTotalCount => 7 + _pendingAdditional.round();

  @override
  void dispose() {
    _additionalTimer?.cancel();
    _maxDegreeTimer?.cancel();
    super.dispose();
  }

  void _onAdditionalChanged(double v) {
    setState(() => _pendingAdditional = v);
    _additionalTimer?.cancel();
    _additionalTimer = Timer(_debounce, () {
      if (!mounted) return;
      if (_appliedAdditional != _pendingAdditional) {
        setState(() => _appliedAdditional = _pendingAdditional);
      }
    });
  }

  void _onMaxDegreeChanged(double v) {
    setState(() => _pendingMaxDegree = v);
    _maxDegreeTimer?.cancel();
    _maxDegreeTimer = Timer(_debounce, () {
      if (!mounted) return;
      if (_appliedMaxDegree != _pendingMaxDegree) {
        setState(() => _appliedMaxDegree = _pendingMaxDegree);
      }
    });
  }

  void _onNodeLongPress(User user) {
    if (user.id == 'self') {
      ProfileBottomSheet.show(context, user, isSelf: true);
    } else {
      ProfileBottomSheet.show(context, user);
    }
  }

  ({List<User> users, List<Connection> connections}) _computeVisible() {
    final direct = topDirectFriends(6);
    final additional = pickNonDirectByCount(
      count: _appliedAdditional.round(),
      maxDegree: _appliedMaxDegree.round(),
    );
    final users = [...direct, ...additional];
    final ids = {'self', ...users.map((u) => u.id)};
    final conns = mockConnections
        .where((c) => ids.contains(c.userId1) && ids.contains(c.userId2))
        .toList();
    return (users: users, connections: conns);
  }

  void _resetView() {
    setState(() => _resetSignal++);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final visible = _computeVisible();
    return Stack(
      children: [
        Positioned.fill(
          child: NodeGraphWidget(
            selfUser: selfUser,
            users: visible.users,
            connections: visible.connections,
            is3D: _is3D,
            useConcentricLayout: false,
            fadeNonDirect: true,
            showEdges: true,
            onNodeLongPress: _onNodeLongPress,
            resetSignal: _resetSignal,
          ),
        ),

        Positioned(
          top: top + 14,
          left: 22,
          right: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONNECT',
                style: AppTheme.display(const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4.0,
                )),
              ),
              const Spacer(),
              _IconBtn(
                icon: Icons.gps_fixed,
                tooltip: '自分に戻る',
                onTap: _resetView,
              ),
              const SizedBox(width: 6),
              _ModeChip(
                label: _is3D ? '3D' : '2D',
                onTap: () => setState(() => _is3D = !_is3D),
              ),
              const SizedBox(width: 6),
              _IconBtn(
                icon: _settingsOpen ? Icons.close : Icons.tune,
                tooltip: '設定',
                active: _settingsOpen,
                onTap: () => setState(() => _settingsOpen = !_settingsOpen),
              ),
            ],
          ),
        ),

        if (_settingsOpen)
          Positioned(
            top: top + 56,
            right: 14,
            child: _SettingsPanel(
              totalCount: _displayTotalCount,
              additionalCount: _pendingAdditional,
              maxDegree: _pendingMaxDegree,
              onAdditionalChanged: _onAdditionalChanged,
              onMaxDegreeChanged: _onMaxDegreeChanged,
            ),
          ),

        if (_is3D)
          Positioned(
            top: top + 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '一本指で回転 ・ 二本指でズーム/移動',
                style: TextStyle(
                  color: AppTheme.ink.withValues(alpha: 0.45),
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------- Small UI atoms ----------------

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 30,
          height: 26,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.16)
                : AppTheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppTheme.accent
                  : AppTheme.ink.withValues(alpha: 0.3),
              width: 1.4,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: active ? AppTheme.accent : AppTheme.ink,
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ModeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.ink.withValues(alpha: 0.3),
            width: 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final int totalCount;
  final double additionalCount;
  final double maxDegree;
  final ValueChanged<double> onAdditionalChanged;
  final ValueChanged<double> onMaxDegreeChanged;

  const _SettingsPanel({
    required this.totalCount,
    required this.additionalCount,
    required this.maxDegree,
    required this.onAdditionalChanged,
    required this.onMaxDegreeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.ink.withValues(alpha: 0.25),
          width: 1.4,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEBUG',
            style: TextStyle(
              color: AppTheme.ink.withValues(alpha: 0.45),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: 'ノード数',
            valueText: '$totalCount',
            value: additionalCount,
            min: 0,
            max: 60,
            onChanged: onAdditionalChanged,
          ),
          const SizedBox(height: 4),
          _SliderRow(
            label: '最大次数',
            valueText: '${maxDegree.round()}',
            value: maxDegree,
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: onMaxDegreeChanged,
          ),
        ],
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
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.ink.withValues(alpha: 0.7),
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
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
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
