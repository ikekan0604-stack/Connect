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

// Free-floating text label placed on the map in edit mode.
// pos is in world coordinates (relative to canvas center).
class MapTextItem {
  final String id;
  String text;
  Offset pos;
  MapTextItem({required this.id, required this.text, required this.pos});
}

// ---------------- Collage design (per friend) ----------------

class CollageTextItem {
  final String id;
  String text;
  Offset pos; // canvas coords, origin = center
  Color color;
  CollageTextItem({
    required this.id,
    required this.text,
    required this.pos,
    required this.color,
  });
}

class CollageStroke {
  final Color color;
  final double width;
  final List<Offset> points; // canvas coords
  CollageStroke({required this.color, required this.width, required this.points});
}

class CollageDesign {
  final Map<String, Offset> photoPos = {};
  final Map<String, double> photoSize = {};
  final List<CollageTextItem> texts = [];
  final List<CollageStroke> strokes = [];
  Color? bgColor; // null = default paper gradient
}

// In-memory store of collage edits, keyed by friend user id
final collageDesigns = <String, CollageDesign>{};

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
