import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

const _kPrimary = Color(0xFF9333EA);

class IconManagerScreen extends StatefulWidget {
  const IconManagerScreen({super.key});

  @override
  State<IconManagerScreen> createState() => _IconManagerScreenState();
}

class _IconManagerScreenState extends State<IconManagerScreen> {
  List<Map<String, dynamic>> _categories = []; // one row per unique category
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await SupabaseService.getPriceItems();
    // Deduplicate by category, keep first row per category
    final seen = <String>{};
    final cats = <Map<String, dynamic>>[];
    for (final item in items) {
      final cat = item['category'] as String;
      if (seen.add(cat)) cats.add(item);
    }
    if (mounted) setState(() { _categories = cats; _loading = false; });
  }

  Future<void> _pickAndUpload(Map<String, dynamic> categoryRow) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (picked == null) return;

    final category = categoryRow['category'] as String;
    final ext = picked.path.split('.').last.toLowerCase();
    final fileName = '${category.toLowerCase().replaceAll(' ', '_')}.$ext';

    _snack('Uploading…');

    try {
      final bytes = await File(picked.path).readAsBytes();

      // Upload to item-icons bucket (upsert so re-upload works)
      await Supabase.instance.client.storage
          .from('item-icons')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$ext',
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('item-icons')
          .getPublicUrl(fileName);

      // Update ALL rows with this category in price_list
      await Supabase.instance.client
          .from('price_list')
          .update({'icon': publicUrl})
          .eq('category', category);

      _snack('Icon updated for $category!', success: true);
      _load();
    } catch (e) {
      _snack('Upload failed: $e');
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.black87,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Manage Item Icons',
            style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _kPrimary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _categories.isEmpty
              ? const Center(child: Text('No categories found'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CategoryIconTile(
                    row: _categories[i],
                    onTap: () => _pickAndUpload(_categories[i]),
                  ),
                ),
    );
  }
}

class _CategoryIconTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const _CategoryIconTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final category = row['category'] as String;
    final icon = row['icon'] as String?;
    final hasImage = icon != null && icon.startsWith('http');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage ? _kPrimary.withValues(alpha: 0.3) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            // Icon preview
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? Image.network(icon!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey))
                  : Center(
                      child: Text(icon ?? '?',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    hasImage ? 'Tap to change image' : 'Tap to upload image',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(hasImage ? Icons.edit : Icons.upload,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(hasImage ? 'Change' : 'Upload',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
