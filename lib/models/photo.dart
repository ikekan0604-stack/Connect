class MockPhoto {
  final String id;
  final String? thumbnailUrl;
  final List<String> participantIds;
  final DateTime takenAt;

  const MockPhoto({
    required this.id,
    this.thumbnailUrl,
    required this.participantIds,
    required this.takenAt,
  });
}
