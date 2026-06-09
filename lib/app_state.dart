import 'package:flutter/material.dart';
import 'models/group.dart';
import 'models/photo.dart';
import 'models/user.dart';
import 'models/connection.dart';

// Map edit mode toggle
final editModeNotifier = ValueNotifier<bool>(false);

// Groups created by lasso selection
final groupsNotifier = ValueNotifier<List<Group>>([]);

// Extra users added via mock connect flow
final extraUsersNotifier = ValueNotifier<List<User>>([]);
final extraConnectionsNotifier = ValueNotifier<List<Connection>>([]);

// Photos per user (key = userId). Populated by mock camera flow.
final userPhotosNotifier = ValueNotifier<Map<String, List<MockPhoto>>>({});

// Deco style for the map background
enum DecoStyle { sketchbook, starry, sakura, ocean }
final decoStyleNotifier = ValueNotifier<DecoStyle>(DecoStyle.sketchbook);

// Counter for refreshing the node graph on connection change
final graphVersionNotifier = ValueNotifier<int>(0);

void addMockConnection(User newUser, Connection conn) {
  extraUsersNotifier.value = [...extraUsersNotifier.value, newUser];
  extraConnectionsNotifier.value = [...extraConnectionsNotifier.value, conn];
  graphVersionNotifier.value++;
}

void addMockPhotos(List<String> participantIds) {
  final now = DateTime.now();
  final newPhotos = List.generate(
    participantIds.length > 1 ? 1 : 0,
    (i) => MockPhoto(
      id: '${now.millisecondsSinceEpoch}_$i',
      thumbnailUrl: 'https://picsum.photos/seed/${now.millisecondsSinceEpoch + i}/300/300',
      participantIds: participantIds,
      takenAt: now,
    ),
  );
  final updated = Map<String, List<MockPhoto>>.from(userPhotosNotifier.value);
  for (final uid in participantIds) {
    updated[uid] = [...(updated[uid] ?? []), ...newPhotos];
  }
  userPhotosNotifier.value = updated;
}
