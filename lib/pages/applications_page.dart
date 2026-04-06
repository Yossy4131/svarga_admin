import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_client.dart';
import '../models/application.dart';
import '../models/event.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key, required this.client});

  final ApiClient client;

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  List<Application> _apps = [];
  List<Event> _events = [];
  Event? _filterEvent;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.client.getEvents(),
        widget.client.getApplications(eventId: _filterEvent?.id),
      ]);
      if (!mounted) return;
      setState(() {
        _events = results[0] as List<Event>;
        _apps = results[1] as List<Application>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patchStatus(Application app, String status) async {
    try {
      final updated = await widget.client.patchApplicationStatus(
        app.id,
        status,
      );
      if (!mounted) return;
      setState(() {
        final idx = _apps.indexWhere((a) => a.id == app.id);
        if (idx != -1) _apps[idx] = updated;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(Application app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('応募 #${app.id} (${app.vrchatId}) を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.client.deleteApplication(app.id);
      if (mounted) setState(() => _apps.removeWhere((a) => a.id == app.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111850),
        title: Text(
          '応募一覧',
          style: GoogleFonts.raleway(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(onPressed: _fetchAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // イベントフィルター
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            // ignore: deprecated_member_use
            child: DropdownButtonFormField<Event?>(
              // ignore: deprecated_member_use
              value: _filterEvent,
              dropdownColor: const Color(0xFF111850),
              decoration: InputDecoration(
                labelText: 'イベントで絞り込み',
                filled: true,
                fillColor: const Color(0x1AFFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0x44FFFFFF)),
                ),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('すべて')),
                ..._events.map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e.eventDate != null
                          ? _formatDateShort(e.eventDate!)
                          : 'イベント #${e.id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _filterEvent = v);
                _fetchAll();
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF6B6B)),
                    ),
                  )
                : _apps.isEmpty
                ? const Center(child: Text('応募がありません'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _apps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final app = _apps[i];
                      return _AppTile(
                        app: app,
                        onStatus: (s) => _patchStatus(app, s),
                        onDelete: () => _delete(app),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.onStatus,
    required this.onDelete,
  });

  final Application app;
  final void Function(String) onStatus;
  final VoidCallback onDelete;

  Color _statusColor() {
    switch (app.status) {
      case 'approved':
        return const Color(0xFF4CAF50);
      case 'rejected':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFFB38246);
    }
  }

  String _statusLabel() {
    switch (app.status) {
      case 'approved':
        return '承認';
      case 'rejected':
        return '拒否';
      default:
        return '未処理';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Color(0xFF93ABE8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      app.vrchatId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.alternate_email,
                      size: 14,
                      color: Color(0xFFD4A870),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      app.xId,
                      style: const TextStyle(
                        color: Color(0xFF8C90A1),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCreatedAt(app.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF5A5F72),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            initialValue: app.status,
            onSelected: onStatus,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pending', child: Text('未処理')),
              PopupMenuItem(value: 'approved', child: Text('承認')),
              PopupMenuItem(value: 'rejected', child: Text('拒否')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor().withAlpha(40),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor().withAlpha(120)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusLabel(),
                    style: TextStyle(color: _statusColor(), fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: _statusColor(), size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outlined,
              size: 18,
              color: Color(0xFFFF6B6B),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCreatedAt(String iso) {
  try {
    final dt = DateTime.parse(iso);
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

String _formatDateShort(String iso) {
  try {
    final dt = DateTime.parse(iso);
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}
