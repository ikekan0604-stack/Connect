import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/mock_data.dart';
import '../models/user.dart';
import '../models/connection.dart';
import '../app_state.dart';
import '../screens/photo_collage_screen.dart';
import 'profile_bottom_sheet.dart';

class BottomPanel extends StatefulWidget {
  final ScrollController scrollController;
  final DraggableScrollableController? sheetController;

  const BottomPanel({
    super.key,
    required this.scrollController,
    this.sheetController,
  });

  @override
  State<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<BottomPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _snapSizes = [0.08, 0.45, 0.86];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // The handle/tab area isn't a scrollable, so DraggableScrollableSheet
  // ignores drags there — drive the sheet manually via its controller.
  void _onHandleDrag(DragUpdateDetails d) {
    final c = widget.sheetController;
    if (c == null || !c.isAttached) return;
    final h = MediaQuery.of(context).size.height;
    c.jumpTo((c.size - d.delta.dy / h).clamp(_snapSizes.first, _snapSizes.last));
  }

  void _onHandleDragEnd(DragEndDetails d) {
    final c = widget.sheetController;
    if (c == null || !c.isAttached) return;
    final v = d.primaryVelocity ?? 0;
    final cur = c.size;
    double target;
    if (v < -250) {
      target = _snapSizes.firstWhere((s) => s > cur + 0.005,
          orElse: () => _snapSizes.last);
    } else if (v > 250) {
      target = _snapSizes.lastWhere((s) => s < cur - 0.005,
          orElse: () => _snapSizes.first);
    } else {
      target = _snapSizes.reduce(
          (a, b) => (a - cur).abs() < (b - cur).abs() ? a : b);
    }
    c.animateTo(target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
  }

  void _onHandleTap() {
    final c = widget.sheetController;
    if (c == null || !c.isAttached) return;
    final target = c.size < 0.2 ? _snapSizes[1] : _snapSizes.first;
    c.animateTo(target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppTheme.ink.withValues(alpha: 0.12), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar + tab bar: manually draggable region
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onHandleTap,
            onVerticalDragUpdate: _onHandleDrag,
            onVerticalDragEnd: _onHandleDragEnd,
            child: Column(
              children: [
                Container(
                  height: 28,
                  alignment: Alignment.center,
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.ink.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabCtrl,
                  tabs: const [
                    Tab(text: '友達'),
                    Tab(text: 'プロフィール'),
                    Tab(text: 'タイムライン'),
                  ],
                  labelColor: AppTheme.textPrimary,
                  unselectedLabelColor: AppTheme.textTertiary,
                  indicatorColor: AppTheme.accent,
                  indicatorWeight: 2,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.bodyFamily,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 13,
                    fontFamily: AppTheme.bodyFamily,
                  ),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _FriendsTab(scrollController: widget.scrollController),
                _ProfileTab(scrollController: widget.scrollController),
                _TimelineTab(scrollController: widget.scrollController),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======= Friends Tab =======

class _FriendsTab extends StatelessWidget {
  final ScrollController scrollController;

  const _FriendsTab({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<User>>(
      valueListenable: extraUsersNotifier,
      builder: (ctx, extras, _) {
        final friends = [...directFriendsSorted, ...extras];
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: friends.length,
          itemBuilder: (_, i) => _FriendTile(
            user: friends[i],
            connection: selfConnection(friends[i].id),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoCollageScreen(user: friends[i]),
                ),
              );
            },
            onLongPress: () => ProfileBottomSheet.show(context, friends[i]),
          ),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  final User user;
  final Connection? connection;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FriendTile({
    required this.user,
    required this.connection,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final level = connection?.level;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.ink.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            // Avatar circle
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: user.nodeColor.withValues(alpha: 0.3),
                border: Border.all(
                    color: user.nodeColor.withValues(alpha: 0.7), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(user.emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),

            // Name / meta
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
                    '${user.mbti} · ${user.age}歳 · ${user.job}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Relationship level indicator (5 dots)
            if (level != null) _LevelDots(level: level),

            const SizedBox(width: 6),
            Icon(Icons.chevron_right,
                size: 16, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _LevelDots extends StatelessWidget {
  final RelationshipLevel level;
  const _LevelDots({required this.level});

  @override
  Widget build(BuildContext context) {
    final filled = level.numericLevel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final active = i < filled;
        return Container(
          width: 6, height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppTheme.accent.withValues(alpha: 0.85)
                : AppTheme.ink.withValues(alpha: 0.12),
          ),
        );
      }),
    );
  }
}

// ======= Profile Tab =======

class _ProfileTab extends StatefulWidget {
  final ScrollController scrollController;
  const _ProfileTab({required this.scrollController});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _nameCtrl = TextEditingController(text: selfUser.name);
  final _mbtiCtrl = TextEditingController(text: selfUser.mbti);
  final _ageCtrl = TextEditingController(text: '${selfUser.age}');
  final _jobCtrl = TextEditingController(text: selfUser.job);
  final _bioCtrl = TextEditingController(text: 'よろしく！デザインと旅行が好きです。');
  bool _saved = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _mbtiCtrl, _ageCtrl, _jobCtrl, _bioCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2),
        () { if (mounted) setState(() => _saved = false); });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        children: [
          // Avatar + name header
          Center(
            child: Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    border: Border.all(color: AppTheme.accent, width: 2),
                  ),
                  child: const Center(
                    child: Text('✦', style: TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selfUser.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Edit fields
          _Field(label: '名前', controller: _nameCtrl),
          _Field(label: 'MBTI', controller: _mbtiCtrl),
          _Field(label: '年齢', controller: _ageCtrl, keyboardType: TextInputType.number),
          _Field(label: '職業', controller: _jobCtrl),
          _Field(label: 'ひとこと', controller: _bioCtrl, maxLines: 3),

          const SizedBox(height: 20),

          // Save button
          GestureDetector(
            onTap: _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 50,
              decoration: BoxDecoration(
                color: _saved
                    ? AppTheme.accent.withValues(alpha: 0.3)
                    : AppTheme.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                _saved ? '保存しました ✓' : '保存する',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.ink.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.ink.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======= Timeline Tab =======

class _TimelineTab extends StatelessWidget {
  final ScrollController scrollController;
  const _TimelineTab({required this.scrollController});

  static final _dummyEvents = [
    _TimelineEvent(
        emoji: '✦', text: '田中 勇樹 と撮影しました', time: '2時間前', accent: true),
    _TimelineEvent(emoji: '🌟', text: '山田 咲 とコネクトしました', time: '昨日'),
    _TimelineEvent(emoji: '📸', text: '渡辺 蓮 と写真を撮りました', time: '3日前'),
    _TimelineEvent(emoji: '🔗', text: '佐藤 寛 とコネクトしました', time: '1週間前'),
    _TimelineEvent(emoji: '📸', text: '伊藤 美咲 と写真を撮りました', time: '2週間前'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Placeholder notice
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'タイムラインはサンプルデータです',
                style: TextStyle(color: AppTheme.accent, fontSize: 11),
              ),
            ],
          ),
        ),
        ..._dummyEvents.map((e) => _EventTile(event: e)),
      ],
    );
  }
}

class _TimelineEvent {
  final String emoji;
  final String text;
  final String time;
  final bool accent;

  const _TimelineEvent({
    required this.emoji,
    required this.text,
    required this.time,
    this.accent = false,
  });
}

class _EventTile extends StatelessWidget {
  final _TimelineEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: event.accent
            ? AppTheme.accent.withValues(alpha: 0.06)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.accent
              ? AppTheme.accent.withValues(alpha: 0.25)
              : AppTheme.ink.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Text(event.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event.text,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            event.time,
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
