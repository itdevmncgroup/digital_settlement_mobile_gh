import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A horizontal row of picked-photo thumbnails plus an "add" tile, used for
/// both activity photos and invoice photos on the New Expense form. Only
/// images can ever end up here (image_picker camera/gallery only - no PDF
/// upload), so every tile always renders as an image preview.
class PhotoTileRow extends StatelessWidget {
  final List<XFile> files;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const PhotoTileRow({
    super.key,
    required this.files,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < files.length; i++) _tile(context, files[i], i),
        _addTile(context, Icons.add_a_photo_outlined, 'Photo', onAdd),
      ],
    );
  }

  Widget _tile(BuildContext context, XFile file, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
              }
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            },
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            onTap: () => onRemove(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addTile(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
