import 'package:flutter/material.dart';

enum RelationshipLevel { acquaintance, familiar, friend, closeFriend, bestFriend }

extension RelationshipLevelExt on RelationshipLevel {
  String get label {
    switch (this) {
      case RelationshipLevel.acquaintance:
        return '知り合い';
      case RelationshipLevel.familiar:
        return '顔見知り';
      case RelationshipLevel.friend:
        return '友達';
      case RelationshipLevel.closeFriend:
        return '仲良し';
      case RelationshipLevel.bestFriend:
        return '親友';
    }
  }

  int get numericLevel {
    return RelationshipLevel.values.indexOf(this) + 1;
  }

  double get lineThickness {
    switch (this) {
      case RelationshipLevel.acquaintance:
        return 1.0;
      case RelationshipLevel.familiar:
        return 2.0;
      case RelationshipLevel.friend:
        return 3.5;
      case RelationshipLevel.closeFriend:
        return 5.0;
      case RelationshipLevel.bestFriend:
        return 7.0;
    }
  }

  Color get color {
    switch (this) {
      case RelationshipLevel.acquaintance:
        return const Color(0xFF4A4A8A);
      case RelationshipLevel.familiar:
        return const Color(0xFF5A7ABF);
      case RelationshipLevel.friend:
        return const Color(0xFF4A9AEF);
      case RelationshipLevel.closeFriend:
        return const Color(0xFF00AAFF);
      case RelationshipLevel.bestFriend:
        return const Color(0xFF00EEFF);
    }
  }

  Color get badgeColor {
    switch (this) {
      case RelationshipLevel.acquaintance:
        return const Color(0xFF2A2A4A);
      case RelationshipLevel.familiar:
        return const Color(0xFF1E3A6E);
      case RelationshipLevel.friend:
        return const Color(0xFF1A4A8E);
      case RelationshipLevel.closeFriend:
        return const Color(0xFF005A88);
      case RelationshipLevel.bestFriend:
        return const Color(0xFF006688);
    }
  }
}

class User {
  final String id;
  final String name;
  final String emoji;
  final String mbti;
  final List<String> hobbies;
  final int age;
  final String job;
  final Color nodeColor;
  final int activityScore;
  final bool isDirect;

  const User({
    required this.id,
    required this.name,
    required this.emoji,
    required this.mbti,
    required this.hobbies,
    required this.age,
    required this.job,
    required this.nodeColor,
    required this.activityScore,
    this.isDirect = false,
  });

  User copyWith({
    String? name,
    String? emoji,
    String? mbti,
    List<String>? hobbies,
    int? age,
    String? job,
    bool? isDirect,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      mbti: mbti ?? this.mbti,
      hobbies: hobbies ?? this.hobbies,
      age: age ?? this.age,
      job: job ?? this.job,
      nodeColor: nodeColor,
      activityScore: activityScore,
      isDirect: isDirect ?? this.isDirect,
    );
  }
}
