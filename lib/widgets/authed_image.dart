import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

/// A thumbnail for an already-uploaded file behind an authenticated download
/// endpoint (`/expenses/photos/:id/download`, `/invoices/files/:id/download`).
/// Tapping an image opens a full-screen pinch-to-zoom viewer; a non-image
/// just shows a document icon (no inline preview for PDFs).
class AuthedThumb extends StatelessWidget {
  final String path;
  final String fileName;
  final bool isImage;

  const AuthedThumb({super.key, required this.path, required this.fileName, required this.isImage});

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthService>().accessToken;
    final url = '$apiBaseUrl$path';
    final headers = token != null ? {'Authorization': 'Bearer $token'} : null;

    return InkWell(
      onTap: isImage ? () => _openViewer(context, url, headers, fileName) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: isImage
            ? Image.network(
                url,
                headers: headers,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: Colors.grey),
              )
            : const Center(child: Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 30)),
      ),
    );
  }

  void _openViewer(BuildContext context, String url, Map<String, String>? headers, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title)),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.network(url, headers: headers, errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48)),
            ),
          ),
        ),
      ),
    );
  }
}
