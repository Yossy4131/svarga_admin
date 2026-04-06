import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/event.dart';
import '../models/application.dart';
import '../models/cast_model.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  final String token;

  const ApiClient({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Admin-Token': token,
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _parse(http.Response res) {
    if (res.statusCode == 401) throw const ApiException('トークンが正しくありません');
    if (res.statusCode == 404) throw const ApiException('データが見つかりません');
    if (res.statusCode >= 400) {
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error']?.toString() ?? 'エラーが発生しました');
    }
    return Future.value(jsonDecode(res.body));
  }

  // Token 検証
  Future<void> verifyToken() async {
    final res = await http.get(_uri('/api/admin/events'), headers: _headers);
    await _parse(res);
  }

  // ── Events ──────────────────────────────────────────────────────────────
  Future<List<Event>> getEvents() async {
    final res = await http.get(_uri('/api/admin/events'), headers: _headers);
    final list = await _parse(res) as List<dynamic>;
    return list.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Event> createEvent(Map<String, dynamic> body) async {
    final res = await http.post(
      _uri('/api/admin/events'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return Event.fromJson(await _parse(res) as Map<String, dynamic>);
  }

  Future<Event> updateEvent(int id, Map<String, dynamic> body) async {
    final res = await http.put(
      _uri('/api/admin/events/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return Event.fromJson(await _parse(res) as Map<String, dynamic>);
  }

  Future<void> deleteEvent(int id) async {
    final res = await http.delete(
      _uri('/api/admin/events/$id'),
      headers: _headers,
    );
    await _parse(res);
  }

  // ── Applications ────────────────────────────────────────────────────────
  Future<List<Application>> getApplications({int? eventId}) async {
    final path = eventId != null
        ? '/api/admin/applications?event_id=$eventId'
        : '/api/admin/applications';
    final res = await http.get(_uri(path), headers: _headers);
    final list = await _parse(res) as List<dynamic>;
    return list
        .map((e) => Application.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Application> patchApplicationStatus(int id, String status) async {
    final res = await http.patch(
      _uri('/api/admin/applications/$id'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return Application.fromJson(await _parse(res) as Map<String, dynamic>);
  }

  Future<void> deleteApplication(int id) async {
    final res = await http.delete(
      _uri('/api/admin/applications/$id'),
      headers: _headers,
    );
    await _parse(res);
  }

  // ── Casts ────────────────────────────────────────────────────────────────
  /// 画像を R2 にアップロードして URL を返す
  Future<String> uploadImage(Uint8List bytes, String mimeType) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/admin/upload-image'),
    );
    request.headers['X-Admin-Token'] = token;
    final ext = mimeType.contains('/')
        ? mimeType.split('/').last.replaceAll('jpeg', 'jpg')
        : 'jpg';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload.$ext',
        contentType: MediaType.parse(mimeType),
      ),
    );
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final data = await _parse(res) as Map<String, dynamic>;
    return data['url'] as String;
  }

  Future<List<CastModel>> getCasts() async {
    final res = await http.get(_uri('/api/admin/casts'), headers: _headers);
    final list = await _parse(res) as List<dynamic>;
    return list
        .map((e) => CastModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CastModel> createCast(Map<String, dynamic> body) async {
    final res = await http.post(
      _uri('/api/admin/casts'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return CastModel.fromJson(await _parse(res) as Map<String, dynamic>);
  }

  Future<CastModel> updateCast(int id, Map<String, dynamic> body) async {
    final res = await http.put(
      _uri('/api/admin/casts/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return CastModel.fromJson(await _parse(res) as Map<String, dynamic>);
  }

  Future<void> reorderCasts(List<int> ids) async {
    final res = await http.put(
      _uri('/api/admin/casts/reorder'),
      headers: _headers,
      body: jsonEncode({'ids': ids}),
    );
    await _parse(res);
  }

  Future<void> deleteCast(int id) async {
    final res = await http.delete(
      _uri('/api/admin/casts/$id'),
      headers: _headers,
    );
    await _parse(res);
  }
}
