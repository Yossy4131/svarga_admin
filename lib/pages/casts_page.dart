import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../constants/app_colors.dart';
import '../models/cast_model.dart';
import '../utils/dialogs.dart';

const _roleOptions = ['オーナー','店長', 'キャスト', 'スタッフ', 'バーテンダー'];

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
    final confirmed = await showConfirmDeleteDialog(
      context,
      '「${cast.name}」を削除しますか？',
    );
    if (!confirmed) return;
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

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _casts.removeAt(oldIndex);
      _casts.insert(newIndex, item);
    });
    try {
      await widget.client.reorderCasts(_casts.map((c) => c.id).toList());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      _fetch(); // ロールバック
    }
  }

  Future<void> _toggleVisibility(CastModel cast) async {
    try {
      final updated = await widget.client.patchCastVisibility(
        cast.id,
        !cast.isVisible,
      );
      setState(() {
        final idx = _casts.indexWhere((c) => c.id == cast.id);
        if (idx != -1) _casts[idx] = updated;
      });
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
          'キャスト管理',
          style: GoogleFonts.shipporiMincho(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        backgroundColor: AppColors.gold,
        icon: const Icon(Icons.person_add),
        label: const Text('追加'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.red),
              ),
            )
          : _casts.isEmpty
          ? const Center(child: Text('キャストが登録されていません'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _casts.length,
              onReorder: _reorder,
              itemBuilder: (_, i) {
                final c = _casts[i];
                return Padding(
                  key: ValueKey(c.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CastTile(
                    cast: c,
                    onEdit: () => _showDialog(cast: c),
                    onDelete: () => _delete(c),
                    onToggleVisibility: () => _toggleVisibility(c),
                  ),
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
    required this.onToggleVisibility,
  });

  final CastModel cast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cast.isVisible
              ? AppColors.cardBorder
              : Colors.red.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0x44B38246),
            backgroundImage: _resolveImage(
              cast.avatarUrl ?? cast.avatarFullUrl,
            ),
            child: (cast.avatarUrl == null && cast.avatarFullUrl == null)
                ? Text(
                    cast.name.isNotEmpty ? cast.name[0] : '?',
                    style: GoogleFonts.shipporiMincho(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
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
                    color: AppColors.goldLight,
                    fontSize: 12,
                  ),
                ),
                if (!cast.isVisible)
                  const Text(
                    '非表示',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
          Switch(
            value: cast.isVisible,
            onChanged: (_) => onToggleVisibility(),
            activeColor: AppColors.gold,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              color: AppColors.red,
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

ImageProvider? _resolveImage(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:')) {
    final comma = url.indexOf(',');
    if (comma != -1) {
      try {
        return MemoryImage(base64Decode(url.substring(comma + 1)));
      } catch (_) {}
    }
  }
  return NetworkImage(url);
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
  late final TextEditingController _msgCtrl;
  List<String> _selectedRoles = [];
  String _pendingRole = _roleOptions.first;

  // 胸上画像
  Uint8List? _bustBytes;
  String _bustMime = 'image/jpeg';
  String? _existingBustUrl;
  bool _clearBust = false;

  // 全身画像
  Uint8List? _fullBytes;
  String _fullMime = 'image/jpeg';
  String? _existingFullUrl;
  bool _clearFull = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cast;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _msgCtrl = TextEditingController(text: c?.message ?? '');
    _selectedRoles = (c?.role ?? '')
        .split(',')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
    // 役職未設定の場合は空のまま（ユーザーが選択する）
    _existingBustUrl = c?.avatarUrl;
    _existingFullUrl = c?.avatarFullUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isFull}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? 'image/jpeg';
    setState(() {
      if (isFull) {
        _fullBytes = bytes;
        _fullMime = mime;
        _clearFull = false;
      } else {
        _bustBytes = bytes;
        _bustMime = mime;
        _clearBust = false;
      }
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      // 胸上画像
      String? bustUrl;
      if (_bustBytes != null) {
        bustUrl = await widget.client.uploadImage(_bustBytes!, _bustMime);
      } else if (_clearBust) {
        bustUrl = null;
      } else {
        bustUrl = _existingBustUrl;
      }

      // 全身画像
      String? fullUrl;
      if (_fullBytes != null) {
        fullUrl = await widget.client.uploadImage(_fullBytes!, _fullMime);
      } else if (_clearFull) {
        fullUrl = null;
      } else {
        fullUrl = _existingFullUrl;
      }

      final body = {
        'name': _nameCtrl.text.trim(),
        'role': _selectedRoles.join(','),
        'message': _msgCtrl.text.trim(),
        'avatar_url': bustUrl,
        'avatar_full_url': fullUrl,
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

  Widget _imagePicker({
    required String label,
    required bool isFull,
    required Uint8List? bytes,
    required String? existingUrl,
    required bool cleared,
  }) {
    final bool hasImage = bytes != null || (existingUrl != null && !cleared);
    final ImageProvider? provider = bytes != null
        ? MemoryImage(bytes)
        : _resolveImage(existingUrl);

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD4A870),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _pick(isFull: isFull),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110,
                height: 196,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0x22B38246),
                  border: Border.all(color: const Color(0x44B38246)),
                  image: hasImage && provider != null
                      ? DecorationImage(image: provider, fit: BoxFit.cover)
                      : null,
                ),
                child: !hasImage
                    ? const Icon(
                        Icons.add_a_photo,
                        color: Colors.white38,
                        size: 32,
                      )
                    : null,
              ),
              if (hasImage)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      if (isFull) {
                        _fullBytes = null;
                        _clearFull = true;
                      } else {
                        _bustBytes = null;
                        _clearBust = true;
                      }
                    }),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF6B6B),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => _pick(isFull: isFull),
          icon: const Icon(Icons.upload, size: 14),
          label: Text(
            hasImage ? '変更' : '選択',
            style: const TextStyle(fontSize: 11),
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.goldLight,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cast != null;
    return AlertDialog(
      backgroundColor: AppColors.navyMid,
      title: Text(isEdit ? 'キャストを編集' : 'キャストを追加'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 画像ピッカー 2枚並べ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _imagePicker(
                    label: '胸上画像',
                    isFull: false,
                    bytes: _bustBytes,
                    existingUrl: _existingBustUrl,
                    cleared: _clearBust,
                  ),
                  const SizedBox(width: 12),
                  _imagePicker(
                    label: '全身画像',
                    isFull: true,
                    bytes: _fullBytes,
                    existingUrl: _existingFullUrl,
                    cleared: _clearFull,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '名前 *'),
              ),
              const SizedBox(height: 12),
              // 役職選択
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _pendingRole,
                      items: _roleOptions
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _pendingRole = v ?? _roleOptions.first,
                      ),
                      decoration: const InputDecoration(labelText: '役職を選択'),
                      dropdownColor: AppColors.navyLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFFD4A870),
                    ),
                    tooltip: '追加',
                    onPressed: () {
                      if (!_selectedRoles.contains(_pendingRole)) {
                        setState(() => _selectedRoles.add(_pendingRole));
                      }
                    },
                  ),
                ],
              ),
              if (_selectedRoles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selectedRoles
                      .map(
                        (r) => Chip(
                          label: Text(r, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _selectedRoles.remove(r)),
                          backgroundColor: AppColors.navyLight,
                          deleteIconColor: AppColors.red,
                          side: const BorderSide(color: Color(0x44B38246)),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _msgCtrl,
                decoration: const InputDecoration(labelText: 'メッセージ'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
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
