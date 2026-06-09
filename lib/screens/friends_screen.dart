import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/user.dart';
import '../models/connection.dart';
import '../theme.dart';
import '../widgets/profile_bottom_sheet.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final friends = directFriendsSorted;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'friends',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.5,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Text(
                '${friends.length}',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: friends.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) => _FriendRow(
          user: friends[i],
          onTap: () => ProfileBottomSheet.show(context, friends[i]),
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const _FriendRow({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final conn = selfConnection(user.id);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: user.nodeColor,
              ),
              alignment: Alignment.center,
              child: Text(user.emoji, style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        user.mbti,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ),
                      Text(
                        '${user.age}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          user.job,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (conn != null) ...[
              const SizedBox(width: 8),
              _LevelIndicator(level: conn.level),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelIndicator extends StatelessWidget {
  final RelationshipLevel level;

  const _LevelIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    final value = level.numericLevel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: filled
                  ? AppTheme.accent
                  : AppTheme.ink.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }),
    );
  }
}
