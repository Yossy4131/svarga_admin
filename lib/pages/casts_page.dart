import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_client.dart';
import '../models/cast_model.dart';

class CastsPage extends StatefulWidget {
  const CastsPage({super.key, required this.client});

  final ApiClient client;

  @override
  State<CastsPage> createState() => _CastsPageState();
}

class _CastsPageState extends State<CastsPage> {
  List<CastModel> _casts = [];
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
      final casts = await widget.client.getCasts();
      if (mounted) setState(() => _casts = casts);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showDialog({CastModel? cast}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _CastDialog(client: widget.client, cast: cast),
    );
    if (result == true) _fetch();
  }

  Future<void> _delete(CastModel cast) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${cast.name}」を削除しますか？'),
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
      await widget.client.deleteCast(cast.id);
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
          'キャスト管理',
          style: GoogleFonts.raleway(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        backgroundColor: const Color(0xFFB38246),
        icon: const Icon(Icons.person_add),
        label: const Text('追加'),
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
          : _casts.isEmpty
          ? const Center(child: Text('キャストが登録されていません'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _casts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = _casts[i];
                return _CastTile(
                  cast: c,
                  onEdit: () => _showDialog(cast: c),
                  onDelete: () => _delete(c),
                );
              },
            ),
    );
  }
}

class _CastTile extends StatelessWidget {
  const _CastTile({
    required this.cast,
    required this.onEdit,
    required this.onDelete,
  });

  final CastModel cast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0x44B38246),
            child: Text(
              cast.name.isNotEmpty ? cast.name[0] : '?',
              style: GoogleFonts.raleway(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cast.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  cast.role,
                  style: const TextStyle(
                    color: Color(0xFFD4A870),
                    fontSize: 12,
                  ),
                ),
                if (cast.message.isNotEmpty)
                  Text(
                    cast.message,
                    style: const TextStyle(
                      color: Color(0xFF8C90A1),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
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

// ─── 作成/編集ダイアログ ────────────────────────────────────────────────────

class _CastDialog extends StatefulWidget {
  const _CastDialog({required this.client, this.cast});

  final ApiClient client;
  final CastModel? cast;

  @override
  State<_CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<_CastDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _roleCtrl;
  late final TextEditingController _msgCtrl;
  late final TextEditingController _urlCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cast;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _roleCtrl = TextEditingController(text: c?.role ?? 'キャスト');
    _msgCtrl = TextEditingController(text: c?.message ?? '');
    _urlCtrl = TextEditingController(text: c?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _msgCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'role': _roleCtrl.text.trim().isEmpty ? 'キャスト' : _roleCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        'avatar_url': _urlCtrl.text.trim().isEmpty
            ? null
            : _urlCtrl.text.trim(),
      };
      if (widget.cast == null) {
        await widget.client.createCast(body);
      } else {
        await widget.client.updateCast(widget.cast!.id, body);
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
    final isEdit = widget.cast != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF111850),
      title: Text(isEdit ? 'キャストを編集' : 'キャストを追加'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '名前 *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleCtrl,
              decoration: const InputDecoration(labelText: '役職'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              decoration: const InputDecoration(labelText: 'メッセージ'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(labelText: 'アバター画像URL（任意）'),
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
              : Text(isEdit ? '保存' : '追加'),
        ),
      ],
    );
  }
}
