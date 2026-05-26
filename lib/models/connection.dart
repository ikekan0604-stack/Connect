import 'user.dart';

class Connection {
  final String userId1;
  final String userId2;
  final RelationshipLevel level;

  const Connection({
    required this.userId1,
    required this.userId2,
    required this.level,
  });

  bool involves(String userId) => userId1 == userId || userId2 == userId;

  String otherUserId(String userId) => userId1 == userId ? userId2 : userId1;
}
