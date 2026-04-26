class CastModel {
  final int id;
  final String name;
  final String? alias;
  final String role;
  final String message;
  final String? avatarUrl;
  final String? avatarFullUrl;
  final int sortOrder;
  final bool isVisible;
  final String updatedAt;

  const CastModel({
    required this.id,
    required this.name,
    this.alias,
    required this.role,
    required this.message,
    required this.avatarUrl,
    required this.avatarFullUrl,
    required this.sortOrder,
    required this.isVisible,
    required this.updatedAt,
  });

  /// 表示名: 源氏名 > 本名
  String get displayName => (alias?.isNotEmpty == true) ? alias! : name;

  factory CastModel.fromJson(Map<String, dynamic> j) => CastModel(
    id: j['id'] as int,
    name: j['name'] as String,
    alias: j['alias'] as String?,
    role: j['role'] as String,
    message: j['message'] as String,
    avatarUrl: j['avatar_url'] as String?,
    avatarFullUrl: j['avatar_full_url'] as String?,
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
    isVisible: ((j['is_visible'] as num?)?.toInt() ?? 1) != 0,
    updatedAt: j['updated_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'alias': alias,
    'role': role,
    'message': message,
    'avatar_url': avatarUrl,
    'avatar_full_url': avatarFullUrl,
  };
}
