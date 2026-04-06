class Event {
  final int id;
  final String? title;
  final String? eventDate;
  final String? recruitmentStart;
  final String? recruitmentEnd;
  final int? recruitmentCount;
  final int? venueCapacity;
  final String status;
  final String createdAt;

  const Event({
    required this.id,
    this.title,
    required this.eventDate,
    this.recruitmentStart,
    this.recruitmentEnd,
    this.recruitmentCount,
    this.venueCapacity,
    required this.status,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> j) => Event(
    id: j['id'] as int,
    title: j['title'] as String?,
    eventDate: j['event_date'] as String?,
    recruitmentStart: j['recruitment_start'] as String?,
    recruitmentEnd: j['recruitment_end'] as String?,
    recruitmentCount: j['recruitment_count'] as int?,
    venueCapacity: j['venue_capacity'] as int?,
    status: j['status'] as String,
    createdAt: j['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'event_date': eventDate,
    'recruitment_start': recruitmentStart,
    'recruitment_end': recruitmentEnd,
    'recruitment_count': recruitmentCount,
    'venue_capacity': venueCapacity,
    'status': status,
  };
}
