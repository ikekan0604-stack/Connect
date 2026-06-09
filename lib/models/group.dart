import 'package:flutter/material.dart';

class Group {
  final String id;
  final String name;
  final Color color;
  final Set<String> memberIds;

  const Group({
    required this.id,
    required this.name,
    required this.color,
    required this.memberIds,
  });

  Group copyWith({String? name, Color? color, Set<String>? memberIds}) => Group(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        memberIds: memberIds ?? Set.from(this.memberIds),
      );
}
