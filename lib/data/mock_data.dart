import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/connection.dart';

// ---------------- Color helpers (poppy pastel palette, GRAVITY-style) ----------------

// Saturation is boosted from the original muted values so nodes read as bright
// candy pastels on the navy canvas rather than washed-out greys.
Color _muted(double hue, [double sat = 0.20, double light = 0.74]) {
  final popSat = (sat * 2.6).clamp(0.0, 0.72);
  return HSLColor.fromAHSL(1.0, hue, popSat, light).toColor();
}

// ---------------- Self ----------------

final User selfUser = User(
  id: 'self',
  name: '自分',
  emoji: '✦',
  mbti: 'ENFP',
  hobbies: const ['写真', '旅行', '音楽'],
  age: 24,
  job: 'デザイナー',
  nodeColor: const Color(0xFFFFFFFF), // pure white for self
  activityScore: 9999,
  isDirect: false,
);

// ---------------- Direct friends (degree 1) ----------------

final List<User> mockDirectFriends = [
  User(
    id: 'u1',
    name: '田中 勇樹',
    emoji: '田',
    mbti: 'ENFP',
    hobbies: const ['音楽', '写真', 'カフェ巡り'],
    age: 24,
    job: 'デザイナー',
    nodeColor: _muted(8, 0.22, 0.74),
    activityScore: 95,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u1/120/120',
  ),
  User(
    id: 'u2',
    name: '佐藤 寛',
    emoji: '佐',
    mbti: 'INTJ',
    hobbies: const ['プログラミング', '読書', 'チェス'],
    age: 26,
    job: 'エンジニア',
    nodeColor: _muted(175, 0.20, 0.72),
    activityScore: 88,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u2/120/120',
  ),
  User(
    id: 'u3',
    name: '山田 咲',
    emoji: '山',
    mbti: 'INFJ',
    hobbies: const ['絵画', '読書', 'ヨガ'],
    age: 22,
    job: '学生',
    nodeColor: _muted(335, 0.22, 0.78),
    activityScore: 82,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u3/120/120',
  ),
  User(
    id: 'u4',
    name: '鈴木 健',
    emoji: '鈴',
    mbti: 'ESTP',
    hobbies: const ['サッカー', 'ゲーム', '料理'],
    age: 28,
    job: '営業',
    nodeColor: _muted(28, 0.24, 0.72),
    activityScore: 79,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u4/120/120',
  ),
  User(
    id: 'u5',
    name: '伊藤 美咲',
    emoji: '伊',
    mbti: 'ISFP',
    hobbies: const ['写真', '旅行', 'アート'],
    age: 23,
    job: 'フォトグラファー',
    nodeColor: _muted(290, 0.18, 0.76),
    activityScore: 76,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u5/120/120',
  ),
  User(
    id: 'u6',
    name: '渡辺 蓮',
    emoji: '渡',
    mbti: 'ENTP',
    hobbies: const ['デザイン', '映画', 'DIY'],
    age: 25,
    job: 'デザイナー',
    nodeColor: _muted(140, 0.20, 0.73),
    activityScore: 72,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u6/120/120',
  ),
  User(
    id: 'u7',
    name: '中村 りな',
    emoji: '中',
    mbti: 'INFP',
    hobbies: const ['読書', '詩', '散歩'],
    age: 21,
    job: '学生',
    nodeColor: _muted(200, 0.20, 0.76),
    activityScore: 65,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u7/120/120',
  ),
  User(
    id: 'u8',
    name: '小林 翔',
    emoji: '小',
    mbti: 'ISTJ',
    hobbies: const ['ランニング', '筋トレ', '料理'],
    age: 30,
    job: 'マネージャー',
    nodeColor: _muted(50, 0.22, 0.74),
    activityScore: 58,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u8/120/120',
  ),
  User(
    id: 'u9',
    name: '加藤 遥',
    emoji: '加',
    mbti: 'ESFJ',
    hobbies: const ['ダンス', 'カフェ', 'ボランティア'],
    age: 24,
    job: '看護師',
    nodeColor: _muted(355, 0.22, 0.80),
    activityScore: 55,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u9/120/120',
  ),
  User(
    id: 'u10',
    name: '吉田 大輝',
    emoji: '吉',
    mbti: 'INTP',
    hobbies: const ['科学', 'プログラミング', 'アニメ'],
    age: 27,
    job: '研究者',
    nodeColor: _muted(190, 0.22, 0.68),
    activityScore: 52,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u10/120/120',
  ),
  User(
    id: 'u11',
    name: '山本 茉莉',
    emoji: '本',
    mbti: 'ENFJ',
    hobbies: const ['教育', 'ピアノ', '旅行'],
    age: 25,
    job: '教師',
    nodeColor: _muted(265, 0.20, 0.74),
    activityScore: 48,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u11/120/120',
  ),
  User(
    id: 'u12',
    name: '松本 剛',
    emoji: '松',
    mbti: 'ENTJ',
    hobbies: const ['ビジネス', 'ゴルフ', '読書'],
    age: 32,
    job: '起業家',
    nodeColor: _muted(25, 0.24, 0.70),
    activityScore: 42,
    isDirect: true,
    imageUrl: 'https://picsum.photos/seed/connect-u12/120/120',
  ),
];

// ---------------- Indirect friends (degree 2) ----------------

final List<User> mockIndirectFriends = [
  User(
    id: 'i1',
    name: '木村 優',
    emoji: '木',
    mbti: 'ISTP',
    hobbies: const ['ゲーム', '釣り', 'バイク'],
    age: 25,
    job: 'エンジニア',
    nodeColor: _muted(215, 0.16, 0.74),
    activityScore: 40,
  ),
  User(
    id: 'i2',
    name: '林 さくら',
    emoji: '林',
    mbti: 'ESFP',
    hobbies: const ['歌', 'ダンス', 'SNS'],
    age: 20,
    job: '学生',
    nodeColor: _muted(335, 0.18, 0.78),
    activityScore: 38,
    imageUrl: 'https://picsum.photos/seed/connect-i2/120/120',
  ),
  User(
    id: 'i3',
    name: '清水 誠',
    emoji: '清',
    mbti: 'ISFJ',
    hobbies: const ['登山', 'キャンプ', '料理'],
    age: 29,
    job: '公務員',
    nodeColor: _muted(130, 0.16, 0.76),
    activityScore: 36,
  ),
  User(
    id: 'i4',
    name: '岡田 実',
    emoji: '岡',
    mbti: 'ENFP',
    hobbies: const ['演劇', '映画', '旅行'],
    age: 23,
    job: '俳優',
    nodeColor: _muted(295, 0.16, 0.76),
    activityScore: 34,
  ),
  User(
    id: 'i5',
    name: '前田 健太',
    emoji: '前',
    mbti: 'ESTJ',
    hobbies: const ['筋トレ', 'スポーツ観戦', '料理'],
    age: 27,
    job: 'トレーナー',
    nodeColor: _muted(18, 0.18, 0.72),
    activityScore: 32,
  ),
  User(
    id: 'i6',
    name: '藤原 あや',
    emoji: '藤',
    mbti: 'INFP',
    hobbies: const ['絵', '読書', '音楽'],
    age: 22,
    job: 'アーティスト',
    nodeColor: _muted(310, 0.16, 0.77),
    activityScore: 30,
    imageUrl: 'https://picsum.photos/seed/connect-i6/120/120',
  ),
  User(
    id: 'i7',
    name: '中島 拓',
    emoji: '島',
    mbti: 'ENTP',
    hobbies: const ['音楽制作', 'DJ', 'テクノロジー'],
    age: 26,
    job: 'DJ',
    nodeColor: _muted(170, 0.16, 0.72),
    activityScore: 28,
    imageUrl: 'https://picsum.photos/seed/connect-i7/120/120',
  ),
  User(
    id: 'i8',
    name: '村上 由梨',
    emoji: '村',
    mbti: 'INTJ',
    hobbies: const ['コーヒー', '読書', 'ひとり旅'],
    age: 28,
    job: 'カフェ店主',
    nodeColor: _muted(35, 0.16, 0.68),
    activityScore: 26,
  ),
  User(
    id: 'i9',
    name: '小川 大介',
    emoji: '川',
    mbti: 'ESFP',
    hobbies: const ['サーフィン', '釣り', 'BBQ'],
    age: 31,
    job: 'インストラクター',
    nodeColor: _muted(205, 0.18, 0.72),
    activityScore: 24,
  ),
  User(
    id: 'i10',
    name: '高橋 花',
    emoji: '高',
    mbti: 'ISFJ',
    hobbies: const ['フラワーアレンジ', '料理', 'ヨガ'],
    age: 25,
    job: 'フローリスト',
    nodeColor: _muted(345, 0.16, 0.80),
    activityScore: 22,
  ),
  User(
    id: 'i11',
    name: '斎藤 一',
    emoji: '斎',
    mbti: 'ISTP',
    hobbies: const ['DIY', 'メカニック', 'プログラミング'],
    age: 33,
    job: 'エンジニア',
    nodeColor: _muted(210, 0.10, 0.70),
    activityScore: 20,
  ),
  User(
    id: 'i12',
    name: '石川 智子',
    emoji: '石',
    mbti: 'INFJ',
    hobbies: const ['瞑想', 'ハーブ', '手芸'],
    age: 30,
    job: 'ヒーラー',
    nodeColor: _muted(120, 0.18, 0.72),
    activityScore: 18,
  ),
  User(
    id: 'i13',
    name: '桑原 朔',
    emoji: '桑',
    mbti: 'ESTJ',
    hobbies: const ['写真', 'ドローン', '旅'],
    age: 24,
    job: 'フリーランサー',
    nodeColor: _muted(220, 0.18, 0.72),
    activityScore: 16,
  ),
  User(
    id: 'i14',
    name: '久保 彩',
    emoji: '久',
    mbti: 'ENFJ',
    hobbies: const ['ダンス', 'ファッション', '友達と過ごす'],
    age: 21,
    job: '学生',
    nodeColor: _muted(280, 0.18, 0.74),
    activityScore: 14,
  ),
  User(
    id: 'i15',
    name: '野田 修',
    emoji: '野',
    mbti: 'ENTJ',
    hobbies: const ['ビジネス', 'マーケティング', 'ゴルフ'],
    age: 35,
    job: 'コンサルタント',
    nodeColor: _muted(42, 0.20, 0.70),
    activityScore: 12,
  ),
  User(
    id: 'i16',
    name: '宮本 さゆ',
    emoji: '宮',
    mbti: 'ISFP',
    hobbies: const ['茶道', '書道', '和菓子'],
    age: 26,
    job: '茶道教師',
    nodeColor: _muted(105, 0.14, 0.74),
    activityScore: 10,
  ),
  User(
    id: 'i17',
    name: '竹内 亮',
    emoji: '竹',
    mbti: 'ESFP',
    hobbies: const ['サイクリング', 'マラソン', 'アウトドア'],
    age: 29,
    job: '体育教師',
    nodeColor: _muted(10, 0.20, 0.72),
    activityScore: 8,
  ),
  User(
    id: 'i18',
    name: '福田 明里',
    emoji: '福',
    mbti: 'ENFP',
    hobbies: const ['歌', 'ミュージカル', 'ポッドキャスト'],
    age: 23,
    job: 'シンガー',
    nodeColor: _muted(325, 0.20, 0.76),
    activityScore: 6,
  ),
  User(
    id: 'i19',
    name: '橋本 学',
    emoji: '橋',
    mbti: 'ISTJ',
    hobbies: const ['データ分析', '将棋', '釣り'],
    age: 34,
    job: 'アナリスト',
    nodeColor: _muted(225, 0.20, 0.70),
    activityScore: 4,
  ),
  User(
    id: 'i20',
    name: '大野 美鈴',
    emoji: '大',
    mbti: 'INTP',
    hobbies: const ['天体観測', 'SF', '哲学'],
    age: 27,
    job: '研究者',
    nodeColor: _muted(245, 0.20, 0.74),
    activityScore: 2,
  ),
];

// ---------------- Extended network (degree 3+) - procedurally generated ----------------

const _exSurnames = [
  '阿部', '森', '池田', '坂本', '太田', '近藤', '原田', '中島',
  '前田', '岡本', '工藤', '長谷川', '小野', '田村', '武田',
  '上田', '森田', '杉山', '青木', '岡田', '平野', '増田',
  '本田', '宮崎', '永井', '長田', '内田', '酒井', '森本', '関口',
];
const _exGivenNames = [
  '翼', '美穂', '修平', 'なつき', '健太', '愛', 'りく', 'みゆ',
  '凛', '陽介', '七海', '蒼', 'ゆい', '颯太', 'みき',
  '直樹', '香織', '亮', 'ゆう', 'まこと', 'さくら', '葵',
  '一馬', '純', '萌', '理沙', '優', 'はる', '智子', '誠',
];
const _exEmojis = [
  '🌙', '🌿', '📚', '🍃', '☁️', '🦋', '🌾', '🍷',
  '🪐', '🕊️', '🍂', '✒️', '🎻', '🪶', '🍀', '🌊',
  '🍇', '🔭', '🍒', '🌹', '🪷', '☕', '🌼', '🪴',
  '🎀', '🍑', '🌻', '⛅', '🌷', '🍓',
];
const _exMbtis = [
  'INFJ', 'INFP', 'INTJ', 'INTP', 'ENFJ', 'ENFP',
  'ENTJ', 'ENTP', 'ISFJ', 'ISFP', 'ISTJ', 'ISTP',
  'ESFJ', 'ESFP', 'ESTJ', 'ESTP',
];
const _exJobs = [
  '会社員', 'エンジニア', '学生', 'デザイナー', '研究者',
  'ライター', 'カメラマン', '医師', '看護師', '教師',
  'カフェ店員', 'バリスタ', 'コンサルタント', 'マーケター',
  '弁護士', 'シェフ', 'ヨガ講師', 'プロデューサー',
];
const _exHobbiePool = [
  '写真', '読書', '映画', '音楽', '料理', '旅行',
  'ヨガ', 'ランニング', 'ピアノ', 'カフェ巡り', '散歩',
  'カメラ', '陶芸', '茶道', 'ガーデニング', 'お酒',
  'アート', '美術館', '展覧会', 'ファッション',
];

List<User> _generateExtendedUsers() {
  final rng = Random(101);
  return List.generate(30, (i) {
    final surname = _exSurnames[i % _exSurnames.length];
    final given = _exGivenNames[i % _exGivenNames.length];
    final age = 19 + rng.nextInt(28);
    final hobbiesList = (List<String>.from(_exHobbiePool)..shuffle(rng))
        .take(2 + rng.nextInt(2))
        .toList();
    // Subtle muted hue based on index
    final hue = (i * 31.3) % 360;
    return User(
      id: 'e$i',
      name: '$surname $given',
      emoji: surname.substring(0, 1),
      mbti: _exMbtis[rng.nextInt(_exMbtis.length)],
      hobbies: hobbiesList,
      age: age,
      job: _exJobs[rng.nextInt(_exJobs.length)],
      nodeColor: _muted(hue, 0.14, 0.72),
      activityScore: 40 - i,
    );
  });
}

final List<User> mockExtendedUsers = _generateExtendedUsers();

// ---------------- Connections ----------------

final List<Connection> _baseConnections = [
  // self → direct
  const Connection(userId1: 'self', userId2: 'u1', level: RelationshipLevel.bestFriend),
  const Connection(userId1: 'self', userId2: 'u2', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'self', userId2: 'u3', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'self', userId2: 'u4', level: RelationshipLevel.friend),
  const Connection(userId1: 'self', userId2: 'u5', level: RelationshipLevel.friend),
  const Connection(userId1: 'self', userId2: 'u6', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'self', userId2: 'u7', level: RelationshipLevel.friend),
  const Connection(userId1: 'self', userId2: 'u8', level: RelationshipLevel.familiar),
  const Connection(userId1: 'self', userId2: 'u9', level: RelationshipLevel.friend),
  const Connection(userId1: 'self', userId2: 'u10', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'self', userId2: 'u11', level: RelationshipLevel.bestFriend),
  const Connection(userId1: 'self', userId2: 'u12', level: RelationshipLevel.familiar),
  // direct ↔ direct
  const Connection(userId1: 'u1', userId2: 'u6', level: RelationshipLevel.friend),
  const Connection(userId1: 'u2', userId2: 'u10', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'u3', userId2: 'u7', level: RelationshipLevel.bestFriend),
  const Connection(userId1: 'u4', userId2: 'u8', level: RelationshipLevel.friend),
  const Connection(userId1: 'u5', userId2: 'u9', level: RelationshipLevel.familiar),
  const Connection(userId1: 'u11', userId2: 'u12', level: RelationshipLevel.friend),
  const Connection(userId1: 'u1', userId2: 'u3', level: RelationshipLevel.familiar),
  const Connection(userId1: 'u6', userId2: 'u11', level: RelationshipLevel.friend),
  // direct → indirect
  const Connection(userId1: 'u1', userId2: 'i1', level: RelationshipLevel.friend),
  const Connection(userId1: 'u1', userId2: 'i2', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'u2', userId2: 'i3', level: RelationshipLevel.friend),
  const Connection(userId1: 'u2', userId2: 'i11', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'u3', userId2: 'i4', level: RelationshipLevel.friend),
  const Connection(userId1: 'u3', userId2: 'i12', level: RelationshipLevel.familiar),
  const Connection(userId1: 'u4', userId2: 'i5', level: RelationshipLevel.friend),
  const Connection(userId1: 'u4', userId2: 'i9', level: RelationshipLevel.familiar),
  const Connection(userId1: 'u5', userId2: 'i6', level: RelationshipLevel.friend),
  const Connection(userId1: 'u5', userId2: 'i13', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'u6', userId2: 'i7', level: RelationshipLevel.bestFriend),
  const Connection(userId1: 'u6', userId2: 'i4', level: RelationshipLevel.familiar),
  const Connection(userId1: 'u7', userId2: 'i6', level: RelationshipLevel.friend),
  const Connection(userId1: 'u7', userId2: 'i14', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'u8', userId2: 'i8', level: RelationshipLevel.friend),
  const Connection(userId1: 'u9', userId2: 'i10', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'u9', userId2: 'i14', level: RelationshipLevel.friend),
  const Connection(userId1: 'u10', userId2: 'i11', level: RelationshipLevel.friend),
  const Connection(userId1: 'u10', userId2: 'i20', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'u11', userId2: 'i15', level: RelationshipLevel.friend),
  const Connection(userId1: 'u11', userId2: 'i16', level: RelationshipLevel.familiar),
  const Connection(userId1: 'u12', userId2: 'i15', level: RelationshipLevel.bestFriend),
  const Connection(userId1: 'u12', userId2: 'i19', level: RelationshipLevel.closeFriend),
  // indirect ↔ indirect
  const Connection(userId1: 'i1', userId2: 'i5', level: RelationshipLevel.friend),
  const Connection(userId1: 'i2', userId2: 'i4', level: RelationshipLevel.friend),
  const Connection(userId1: 'i3', userId2: 'i8', level: RelationshipLevel.familiar),
  const Connection(userId1: 'i7', userId2: 'i18', level: RelationshipLevel.closeFriend),
  const Connection(userId1: 'i9', userId2: 'i17', level: RelationshipLevel.friend),
  const Connection(userId1: 'i14', userId2: 'i18', level: RelationshipLevel.bestFriend),
  const Connection(userId1: 'i15', userId2: 'i19', level: RelationshipLevel.friend),
  const Connection(userId1: 'i16', userId2: 'i12', level: RelationshipLevel.familiar),
  const Connection(userId1: 'i20', userId2: 'i11', level: RelationshipLevel.friend),
];

List<Connection> _generateExtendedConnections() {
  final rng = Random(202);
  final result = <Connection>[];
  // Helper to add unique edge
  final seen = <String>{};
  void add(String a, String b, RelationshipLevel l) {
    final k = a.compareTo(b) < 0 ? '$a-$b' : '$b-$a';
    if (seen.contains(k)) return;
    seen.add(k);
    result.add(Connection(userId1: a, userId2: b, level: l));
  }

  // e0-e9: connect to 1-2 of i* (degree 3)
  for (int i = 0; i < 10; i++) {
    final count = 1 + rng.nextInt(2);
    final picked = <int>{};
    for (int k = 0; k < count; k++) {
      var iIdx = 1 + rng.nextInt(20);
      int tries = 0;
      while (picked.contains(iIdx) && tries < 10) {
        iIdx = 1 + rng.nextInt(20);
        tries++;
      }
      picked.add(iIdx);
      add('e$i', 'i$iIdx', RelationshipLevel.values[rng.nextInt(5)]);
    }
  }

  // e10-e19: connect to 1-2 of e0-e9 (degree 4)
  for (int i = 10; i < 20; i++) {
    final count = 1 + rng.nextInt(2);
    final picked = <int>{};
    for (int k = 0; k < count; k++) {
      var j = rng.nextInt(10);
      int tries = 0;
      while (picked.contains(j) && tries < 10) {
        j = rng.nextInt(10);
        tries++;
      }
      picked.add(j);
      add('e$i', 'e$j', RelationshipLevel.values[rng.nextInt(5)]);
    }
  }

  // e20-e29: connect to 1-2 of e10-e19 (degree 5)
  for (int i = 20; i < 30; i++) {
    final count = 1 + rng.nextInt(2);
    final picked = <int>{};
    for (int k = 0; k < count; k++) {
      var j = 10 + rng.nextInt(10);
      int tries = 0;
      while (picked.contains(j) && tries < 10) {
        j = 10 + rng.nextInt(10);
        tries++;
      }
      picked.add(j);
      add('e$i', 'e$j', RelationshipLevel.values[rng.nextInt(5)]);
    }
  }

  // Some cross-connections within each band for realism
  for (int k = 0; k < 18; k++) {
    final a = rng.nextInt(30);
    final b = rng.nextInt(30);
    if (a == b) continue;
    add('e$a', 'e$b', RelationshipLevel.values[rng.nextInt(5)]);
  }

  return result;
}

final List<Connection> mockConnections = [
  ..._baseConnections,
  ..._generateExtendedConnections(),
];

// ---------------- Aggregate ----------------

List<User> get allMockUsers => [
      selfUser,
      ...mockDirectFriends,
      ...mockIndirectFriends,
      ...mockExtendedUsers,
    ];

Map<String, User> get userMap => {for (final u in allMockUsers) u.id: u};

// ---------------- Degree (BFS distance from self) ----------------

Map<String, int>? _cachedDegrees;
Map<String, int> get userDegrees {
  if (_cachedDegrees != null) return _cachedDegrees!;
  final degrees = <String, int>{'self': 0};
  final queue = <String>['self'];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    final currentDeg = degrees[current]!;
    for (final conn in mockConnections) {
      if (!conn.involves(current)) continue;
      final other = conn.otherUserId(current);
      if (!degrees.containsKey(other)) {
        degrees[other] = currentDeg + 1;
        queue.add(other);
      }
    }
  }
  _cachedDegrees = degrees;
  return degrees;
}

int degreeOf(String userId) => userDegrees[userId] ?? 99;

// ---------------- Selection helpers ----------------

List<Connection> connectionsFor(String userId) =>
    mockConnections.where((c) => c.involves(userId)).toList();

List<User> get directFriendsSorted =>
    List.from(mockDirectFriends)
      ..sort((a, b) => b.activityScore.compareTo(a.activityScore));

List<User> topDirectFriends([int n = 6]) =>
    directFriendsSorted.take(n).toList();

Connection? selfConnection(String userId) {
  try {
    return mockConnections
        .firstWhere((c) => c.involves('self') && c.involves(userId));
  } catch (_) {
    return null;
  }
}

Connection? connectionBetween(String uid1, String uid2) {
  try {
    return mockConnections
        .firstWhere((c) => c.involves(uid1) && c.involves(uid2));
  } catch (_) {
    return null;
  }
}

/// Return users whose degree from self is <= maxDegree, sorted by degree then activity.
List<User> usersUpToDegree(int maxDegree) {
  final degs = userDegrees;
  final users = allMockUsers
      .where((u) => (degs[u.id] ?? 99) <= maxDegree)
      .toList();
  users.sort((a, b) {
    final da = degs[a.id] ?? 99;
    final db = degs[b.id] ?? 99;
    if (da != db) return da.compareTo(db);
    return b.activityScore.compareTo(a.activityScore);
  });
  return users;
}

/// Return up to `count` users (excluding self and direct friends),
/// sorted by degree then activity. Used by home tab to pick which
/// indirect/extended nodes to show.
List<User> pickNonDirectByCount({required int count, required int maxDegree}) {
  if (count <= 0) return [];
  final degs = userDegrees;
  final candidates = allMockUsers
      .where((u) =>
          u.id != 'self' &&
          !u.isDirect &&
          (degs[u.id] ?? 99) <= maxDegree)
      .toList();
  candidates.sort((a, b) {
    final da = degs[a.id] ?? 99;
    final db = degs[b.id] ?? 99;
    if (da != db) return da.compareTo(db);
    return b.activityScore.compareTo(a.activityScore);
  });
  return candidates.take(count).toList();
}
