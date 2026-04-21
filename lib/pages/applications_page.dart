import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_client.dart';
import '../constants/app_colors.dart';
import '../models/application.dart';
import '../models/event.dart';
import '../utils/dialogs.dart';
import '../utils/format_util.dart';

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
    final result = await showDialog<_LotteryResult>(
      context: context,
      builder: (_) => _LotteryDialog(events: _events, apps: _apps),
    );
    if (result == null || !mounted) return;
    // 当選者を approved に
    for (final w in result.winners) {
      await _patchStatus(w, 'approved');
    }
    // 再抽選時は落選者のステータスは変更しない
    if (!result.isReDraw) {
      // 同開催日の残りの pending を rejected に
      for (final l in result.losers) {
        await _patchStatus(l, 'rejected');
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isReDraw
                ? '再抽選: 当選 ${result.winners.length}名'
                : '当選: ${result.winners.length}名、落選: ${result.losers.length}名',
          ),
        ),
      );
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
    final confirmed = await showConfirmDeleteDialog(
      context,
      '応募 #${app.id} (${app.vrchatId}) を削除しますか？',
    );
    if (!confirmed) return;
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
        backgroundColor: AppColors.navyMid,
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
              dropdownColor: AppColors.navyMid,
              decoration: InputDecoration(
                labelText: '開催日で絞り込み',
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
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
                      style: const TextStyle(color: AppColors.red),
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
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      case 'skipped':
        return const Color(0xFFFF9800); // orange
      default:
        return AppColors.gold;
    }
  }

  String _statusLabel() {
    switch (app.status) {
      case 'approved':
        return '当選';
      case 'rejected':
        return '落選';
      case 'skipped':
        return '見送り';
      default:
        return '抽選前';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
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
                      color: AppColors.blueLight,
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
                      color: AppColors.goldLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      app.xId,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCreatedAt(app.createdAt),
                  style: const TextStyle(
                    color: AppColors.mutedDark,
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
              PopupMenuItem(value: 'pending', child: Text('抽選前')),
              PopupMenuItem(value: 'approved', child: Text('当選')),
              PopupMenuItem(value: 'rejected', child: Text('落選')),
              PopupMenuItem(value: 'skipped', child: Text('見送り')),
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
              color: AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCreatedAt(String iso) => formatDateTime(iso);

String _formatDateShort(String iso) => formatDate(iso);

// ─── 抽選結果 ─────────────────────────────────────────────────────────────────

class _LotteryResult {
  const _LotteryResult({
    required this.winners,
    required this.losers,
    this.isReDraw = false,
  });
  final List<Application> winners;
  final List<Application> losers;
  final bool isReDraw;
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
  bool _reDrawMode = false; // true: 落選者から再抽選

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
      if (a.status != (_reDrawMode ? 'rejected' : 'pending')) return false;
      if (_selectedEvent != null && a.eventId != _selectedEvent!.id) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 当選者以外で、同開催日の pending アプリ = 落選対象
  List<Application> get _losers {
    if (_winners == null || _selectedEvent == null) return [];
    final winnerIds = _winners!.map((w) => w.id).toSet();
    if (_reDrawMode) {
      // 再抽選時は落選者のステータスを変更しない
      return [];
    }
    return widget.apps.where((a) {
      return a.status == 'pending' &&
          a.eventId == _selectedEvent!.id &&
          !winnerIds.contains(a.id);
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
      backgroundColor: AppColors.navyMid,
      title: Row(
        children: [
          const Icon(Icons.casino_outlined, color: AppColors.goldLight),
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
                dropdownColor: AppColors.navyLight,
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
                  helperText:
                      '対象: ${candidates.length}名 (${_reDrawMode ? '落選者' : '抽選前'})',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => setState(() => _winners = null),
              ),
              const SizedBox(height: 12),
              // 再抽選モードトグル
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _reDrawMode
                      ? const Color(0x22FF9800)
                      : AppColors.navyLight.withAlpha(80),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _reDrawMode
                        ? const Color(0x66FF9800)
                        : AppColors.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.replay,
                      size: 16,
                      color: Color(0xFFFF9800),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('落選者から再抽選', style: TextStyle(fontSize: 13)),
                    ),
                    Switch(
                      value: _reDrawMode,
                      onChanged: (v) => setState(() {
                        _reDrawMode = v;
                        _winners = null;
                      }),
                      activeColor: const Color(0xFFFF9800),
                    ),
                  ],
                ),
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
                    backgroundColor: AppColors.gold,
                  ),
                ),
              ),
              // 結果
              if (hasWinners) ...[
                const SizedBox(height: 20),
                Text(
                  '当選者 ${_winners!.length}名',
                  style: const TextStyle(
                    color: AppColors.goldLight,
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
                          color: AppColors.green,
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
                                  color: AppColors.muted,
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
                    style: TextStyle(color: AppColors.red),
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
            onPressed: () => Navigator.pop(
              context,
              _LotteryResult(
                winners: _winners!,
                losers: _losers,
                isReDraw: _reDrawMode,
              ),
            ),
            icon: const Icon(Icons.check),
            label: Text(_reDrawMode ? '再抽選を確定する' : '当選を確定する'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          ),
      ],
    );
  }
}
