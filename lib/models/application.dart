class Application {
  final int id;
  final String vrchatId;
  final String xId;
  final int? eventId;
  final String status;
  final String createdAt;

  const Application({
    required this.id,
    required this.vrchatId,
    required this.xId,
    required this.eventId,
    required this.status,
    required this.createdAt,
  });

  factory Application.fromJson(Map<String, dynamic> j) => Application(
    id: j['id'] as int,
    vrchatId: j['vrchat_id'] as String,
    xId: j['x_id'] as String,
    eventId: j['event_id'] as int?,
    status: j['status'] as String,
    createdAt: j['created_at'] as String,
  );
}
