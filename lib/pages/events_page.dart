import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_client.dart';
import '../models/event.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.client});

  final ApiClient client;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<Event> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.client.getEvents();
      if (mounted) setState(() => _events = events);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showDialog({Event? event}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _EventDialog(client: widget.client, event: event),
    );
    if (result == true) _fetch();
  }

  Future<void> _delete(Event event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${event.title}」を削除しますか？'),
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
      await widget.client.deleteEvent(event.id);
      _fetch();
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
          'イベント管理',
          style: GoogleFonts.raleway(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        backgroundColor: const Color(0xFFB38246),
        icon: const Icon(Icons.add),
        label: const Text('新規作成'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF6B6B)),
              ),
            )
          : _events.isEmpty
          ? const Center(child: Text('イベントがありません'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final ev = _events[i];
                return _EventTile(
                  event: ev,
                  onEdit: () => _showDialog(event: ev),
                  onDelete: () => _delete(ev),
                );
              },
            ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final Event event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _statusColor() {
    switch (event.status) {
      case 'upcoming':
        return const Color(0xFF5B7DE8);
      case 'completed':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF8C90A1);
    }
  }

  String _statusLabel() {
    switch (event.status) {
      case 'upcoming':
        return '開催予定';
      case 'completed':
        return '終了';
      default:
        return 'キャンセル';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.eventDate != null
                      ? _formatDate(event.eventDate!)
                      : '日付未定',
                  style: const TextStyle(
                    color: Color(0xFF8C90A1),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor().withAlpha(40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor().withAlpha(120)),
            ),
            child: Text(
              _statusLabel(),
              style: TextStyle(color: _statusColor(), fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: Colors.white70,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outlined,
              size: 20,
              color: Color(0xFFFF6B6B),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(String iso) {
  try {
    final dt = DateTime.parse(iso);
    return '${dt.year}年${dt.month}月${dt.day}日'
        '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

// ─── 作成/編集ダイアログ ────────────────────────────────────────────────────

class _EventDialog extends StatefulWidget {
  const _EventDialog({required this.client, this.event});

  final ApiClient client;
  final Event? event;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final TextEditingController _titleCtrl;
  DateTime? _pickedDt;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    _titleCtrl = TextEditingController(text: ev?.title ?? '');
    _status = ev?.status ?? 'upcoming';
    if (ev?.eventDate != null) {
      _pickedDt = DateTime.tryParse(ev!.eventDate!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _pickedDt ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickedDt ?? DateTime.now()),
    );
    if (!mounted) return;
    setState(() {
      _pickedDt = time != null
          ? DateTime(date.year, date.month, date.day, time.hour, time.minute)
          : DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final body = {
        'title': _titleCtrl.text.trim(),
        'event_date': _pickedDt?.toIso8601String(),
        'status': _status,
      };
      if (widget.event == null) {
        await widget.client.createEvent(body);
      } else {
        await widget.client.updateEvent(widget.event!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF111850),
      title: Text(isEdit ? 'イベントを編集' : '新規イベント'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'タイトル'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _pickedDt != null
                        ? _formatDate(_pickedDt!.toIso8601String())
                        : '開催日時を選択',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('選択'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ignore: deprecated_member_use
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _status,
              dropdownColor: const Color(0xFF111850),
              decoration: const InputDecoration(labelText: 'ステータス'),
              items: const [
                DropdownMenuItem(value: 'upcoming', child: Text('開催予定')),
                DropdownMenuItem(value: 'completed', child: Text('終了')),
                DropdownMenuItem(value: 'cancelled', child: Text('キャンセル')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB38246),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(isEdit ? '保存' : '作成'),
        ),
      ],
    );
  }
}
