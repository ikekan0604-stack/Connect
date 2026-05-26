import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/user.dart';
import '../theme.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Detailed profile (for direct friends)
  final _nameCtrl = TextEditingController(text: selfUser.name);
  final _ageCtrl = TextEditingController(text: '${selfUser.age}');
  final _jobCtrl = TextEditingController(text: selfUser.job);
  final _mbtiCtrl = TextEditingController(text: selfUser.mbti);
  final _bioCtrl = TextEditingController(text: 'よろしく！デザインと旅行が好きです。');
  final _hobbiesCtrl =
      TextEditingController(text: selfUser.hobbies.join('、'));

  // Simple profile (for indirect friends)
  final _simpleNameCtrl = TextEditingController(text: selfUser.name);
  final _simpleMbtiCtrl = TextEditingController(text: selfUser.mbti);
  final _simpleAgeCtrl = TextEditingController(text: '${selfUser.age}');
  final _simpleJobCtrl = TextEditingController(text: selfUser.job);

  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [
      _nameCtrl, _ageCtrl, _jobCtrl, _mbtiCtrl, _bioCtrl, _hobbiesCtrl,
      _simpleNameCtrl, _simpleMbtiCtrl, _simpleAgeCtrl, _simpleJobCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('保存しました'),
        backgroundColor: AppTheme.accent.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          GestureDetector(
            onTap: _save,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _saved
                      ? Colors.green.withOpacity(0.2)
                      : AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _saved
                        ? Colors.green.withOpacity(0.5)
                        : AppTheme.accent.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  _saved ? '保存済み ✓' : '保存',
                  style: TextStyle(
                    color: _saved ? Colors.green : AppTheme.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 2,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '詳細プロフィール'),
            Tab(text: '簡易プロフィール'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _DetailedProfileTab(
            nameCtrl: _nameCtrl,
            ageCtrl: _ageCtrl,
            jobCtrl: _jobCtrl,
            mbtiCtrl: _mbtiCtrl,
            bioCtrl: _bioCtrl,
            hobbiesCtrl: _hobbiesCtrl,
          ),
          _SimpleProfileTab(
            nameCtrl: _simpleNameCtrl,
            mbtiCtrl: _simpleMbtiCtrl,
            ageCtrl: _simpleAgeCtrl,
            jobCtrl: _simpleJobCtrl,
          ),
        ],
      ),
    );
  }
}

class _DetailedProfileTab extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController ageCtrl;
  final TextEditingController jobCtrl;
  final TextEditingController mbtiCtrl;
  final TextEditingController bioCtrl;
  final TextEditingController hobbiesCtrl;

  const _DetailedProfileTab({
    required this.nameCtrl,
    required this.ageCtrl,
    required this.jobCtrl,
    required this.mbtiCtrl,
    required this.bioCtrl,
    required this.hobbiesCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionLabel(
          icon: '👁️',
          label: '直接つながった友達に表示されます',
          accent: true,
        ),
        const SizedBox(height: 20),

        // Avatar preview
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selfUser.nodeColor.withOpacity(0.15),
                  border:
                      Border.all(color: selfUser.nodeColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: selfUser.nodeColor.withOpacity(0.35),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🌟', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'アバター変更 (準備中)',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _Field(label: '名前', ctrl: nameCtrl, hint: '田中 太郎'),
        _Field(label: 'MBTI', ctrl: mbtiCtrl, hint: 'ENFP'),
        _Field(label: '年齢', ctrl: ageCtrl, hint: '24', keyboardType: TextInputType.number),
        _Field(label: '職業', ctrl: jobCtrl, hint: 'デザイナー'),
        _Field(label: '趣味 (読点区切り)', ctrl: hobbiesCtrl, hint: '写真、旅行、音楽'),
        _Field(label: '自己紹介', ctrl: bioCtrl, hint: 'よろしく！', maxLines: 3),

        const SizedBox(height: 24),
        _BannerSection(),
      ],
    );
  }
}

class _SimpleProfileTab extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController mbtiCtrl;
  final TextEditingController ageCtrl;
  final TextEditingController jobCtrl;

  const _SimpleProfileTab({
    required this.nameCtrl,
    required this.mbtiCtrl,
    required this.ageCtrl,
    required this.jobCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionLabel(
          icon: '🔒',
          label: '友達の友達など間接的なユーザーに表示されます',
          accent: false,
        ),
        const SizedBox(height: 20),
        _Field(label: '名前', ctrl: nameCtrl, hint: '田中 太郎'),
        _Field(label: 'MBTI', ctrl: mbtiCtrl, hint: 'ENFP'),
        _Field(label: '年齢', ctrl: ageCtrl, hint: '24', keyboardType: TextInputType.number),
        _Field(label: '職業', ctrl: jobCtrl, hint: 'デザイナー'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '簡易プロフィールについて',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                '直接コネクトしていないユーザーには、ここで設定した限られた情報のみが表示されます。詳細は直接コネクトしてから公開されます。',
                style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String icon;
  final String label;
  final bool accent;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppTheme.accent : Colors.white54;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent
            ? AppTheme.accent.withOpacity(0.08)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent ? AppTheme.accent.withOpacity(0.3) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}

class _BannerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.workspace_premium_outlined,
                color: Colors.white.withValues(alpha: 0.6), size: 14),
            const SizedBox(width: 6),
            Text(
              'BANNERS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.6,
          children: const [
            _BannerTile(label: '写真 5枚', unlocked: true),
            _BannerTile(label: 'ENFP', unlocked: true),
            _BannerTile(label: '友達 3人', unlocked: true),
            _BannerTile(label: '写真 20枚', unlocked: false),
            _BannerTile(label: '親友', unlocked: false),
            _BannerTile(label: 'レア', unlocked: false),
          ],
        ),
      ],
    );
  }
}

class _BannerTile extends StatelessWidget {
  final String label;
  final bool unlocked;

  const _BannerTile({
    required this.label,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: unlocked
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: unlocked ? 0.15 : 0.06),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            unlocked ? Icons.check_circle_outline : Icons.lock_outline,
            size: 14,
            color: unlocked
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: unlocked
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.20),
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
