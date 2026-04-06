class Event {
  final int id;
  final String title;
  final String? eventDate;
  final String status;
  final String createdAt;

  const Event({
    required this.id,
    required this.title,
    required this.eventDate,
    required this.status,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> j) => Event(
    id: j['id'] as int,
    title: j['title'] as String,
    eventDate: j['event_date'] as String?,
    status: j['status'] as String,
    createdAt: j['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'event_date': eventDate,
    'status': status,
  };

  Event copyWith({String? title, String? eventDate, String? status}) => Event(
    id: id,
    title: title ?? this.title,
    eventDate: eventDate ?? this.eventDate,
    status: status ?? this.status,
    createdAt: createdAt,
  );
}
