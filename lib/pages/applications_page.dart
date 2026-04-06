import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> _showLotteryDialog() async {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('イベントがありません')));
      return;
    }
    final winners = await showDialog<List<Application>>(
      context: context,
      builder: (_) => _LotteryDialog(events: _events, apps: _apps),
    );
    if (winners == null || winners.isEmpty || !mounted) return;
    // 一括承認
    for (final w in winners) {
      await _patchStatus(w, 'approved');
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${winners.length}名を承認しました')));
    }
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
        // _filterEvent を新しいリストのインスタンスで再マッチ（参照ズレ防止）
        if (_filterEvent != null) {
          _filterEvent = (_events.cast<Event?>()).firstWhere(
            (e) => e?.id == _filterEvent!.id,
            orElse: () => null,
          );
        }
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
          style: GoogleFonts.shipporiMincho(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _showLotteryDialog,
            icon: const Icon(Icons.casino_outlined),
            tooltip: '抽選',
          ),
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
                labelText: '開催日で絞り込み',
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

// ─── 抽選ダイアログ ────────────────────────────────────────────────────────────

class _LotteryDialog extends StatefulWidget {
  const _LotteryDialog({required this.events, required this.apps});

  final List<Event> events;
  final List<Application> apps;

  @override
  State<_LotteryDialog> createState() => _LotteryDialogState();
}

class _LotteryDialogState extends State<_LotteryDialog> {
  Event? _selectedEvent;
  final _countCtrl = TextEditingController(text: '1');
  List<Application>? _winners;

  @override
  void initState() {
    super.initState();
    _selectedEvent = widget.events.isNotEmpty ? widget.events.first : null;
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  List<Application> get _candidates {
    return widget.apps.where((a) {
      if (a.status != 'pending') return false;
      if (_selectedEvent != null && a.eventId != _selectedEvent!.id) {
        return false;
      }
      return true;
    }).toList();
  }

  void _runLottery() {
    final count = int.tryParse(_countCtrl.text.trim()) ?? 1;
    final pool = List<Application>.from(_candidates)..shuffle(Random());
    setState(() {
      _winners = pool.take(count.clamp(1, pool.length)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    final hasWinners = _winners != null && _winners!.isNotEmpty;

    return AlertDialog(
      backgroundColor: const Color(0xFF111850),
      title: Row(
        children: [
          const Icon(Icons.casino_outlined, color: Color(0xFFD4A870)),
          const SizedBox(width: 8),
          Text(
            '抽選',
            style: GoogleFonts.shipporiMincho(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // イベント選択
              DropdownButtonFormField<Event?>(
                value: _selectedEvent,
                dropdownColor: const Color(0xFF1a2060),
                decoration: InputDecoration(
                  labelText: '対象開催日',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: [
                  ...widget.events.map(
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
                onChanged: (v) => setState(() {
                  _selectedEvent = v;
                  _winners = null;
                }),
              ),
              const SizedBox(height: 12),
              // 人数
              TextField(
                controller: _countCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '当選人数',
                  helperText: '対象: ${candidates.length}名 (pending)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => setState(() => _winners = null),
              ),
              const SizedBox(height: 16),
              // 抽選ボタン
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: candidates.isEmpty ? null : _runLottery,
                  icon: const Icon(Icons.shuffle),
                  label: const Text('抽選する'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB38246),
                  ),
                ),
              ),
              // 結果
              if (hasWinners) ...[
                const SizedBox(height: 20),
                Text(
                  '当選者 ${_winners!.length}名',
                  style: const TextStyle(
                    color: Color(0xFFD4A870),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...(_winners!.map(
                  (w) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x2244BB44),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x6644BB44)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          size: 16,
                          color: Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.vrchatId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '@${w.xId}',
                                style: const TextStyle(
                                  color: Color(0xFF8C90A1),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
              if (_winners != null && _winners!.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    '対象の応募者がいません',
                    style: TextStyle(color: Color(0xFFFF6B6B)),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('キャンセル'),
        ),
        if (hasWinners)
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _winners),
            icon: const Icon(Icons.check),
            label: const Text('当選者を承認'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
          ),
      ],
    );
  }
}
