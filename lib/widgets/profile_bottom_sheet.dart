import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/connection.dart';
import '../data/mock_data.dart';
import '../theme.dart';

class ProfileBottomSheet extends StatelessWidget {
  final User user;
  final bool isSelf;

  const ProfileBottomSheet({
    super.key,
    required this.user,
    this.isSelf = false,
  });

  static void show(BuildContext context, User user, {bool isSelf = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfileBottomSheet(user: user, isSelf: isSelf),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conn = isSelf ? null : selfConnection(user.id);
    final isDirect = user.isDirect;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.only(top: 10, bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          _Header(user: user, conn: conn, isSelf: isSelf),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          ),
          const SizedBox(height: 16),
          if (isDirect || isSelf)
            _FullProfile(user: user, conn: conn)
          else
            _SimpleProfile(user: user),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final User user;
  final Connection? conn;
  final bool isSelf;

  const _Header({required this.user, this.conn, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelf ? Colors.white : user.nodeColor,
          ),
          alignment: Alignment.center,
          child: Text(
            user.emoji,
            style: TextStyle(
              fontSize: 28,
              color: Colors.black.withValues(alpha: isSelf ? 1.0 : 0.85),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user.name,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        if (conn != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(5, (i) {
                final filled = i < conn!.level.numericLevel;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                conn!.level.label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
        if (isSelf) ...[
          const SizedBox(height: 6),
          const Text(
            'you',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        ],
        if (!user.isDirect && !isSelf) ...[
          const SizedBox(height: 6),
          Text(
            '友達の友達',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _FullProfile extends StatelessWidget {
  final User user;
  final Connection? conn;

  const _FullProfile({required this.user, this.conn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatCell(label: 'MBTI', value: user.mbti),
              _Sep(),
              _StatCell(label: 'age', value: '${user.age}'),
              _Sep(),
              _StatCell(label: 'job', value: user.job),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'INTERESTS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: user.hobbies
                .map((h) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Text(
                        h,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ))
                .toList(),
          ),
          if (conn != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library_outlined,
                      color: AppTheme.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '一緒に撮った写真',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${conn!.level.numericLevel * 3} 枚',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SimpleProfile extends StatelessWidget {
  final User user;

  const _SimpleProfile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatCell(label: 'MBTI', value: user.mbti),
              _Sep(),
              _StatCell(label: 'age', value: '${user.age}'),
              _Sep(),
              _StatCell(label: 'job', value: user.job),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline,
                    color: Colors.white.withValues(alpha: 0.3), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'コネクトすると詳細を見られます',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}
