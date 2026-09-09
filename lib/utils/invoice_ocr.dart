import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';

/// Result of a `POST /invoices/ocr-scan` call - mirrors the backend's
/// `ParsedReceipt` (see digital_settlement_be OcrService), trimmed to the
/// three fields the expense form pre-fills: transaction date, merchant name,
/// and grand total (never subtotal - the backend's `total` field already
/// excludes it, see OcrService.TOTAL_RE / SUBTOTAL_RE).
class InvoiceScanResult {
  final String? merchantName;
  final DateTime? invoiceDate;
  final num? total;
  final List<String> warnings;

  const InvoiceScanResult({this.merchantName, this.invoiceDate, this.total, this.warnings = const []});
}

/// Uploads a picked invoice/receipt photo for OCR and returns the parsed
/// fields, or null if the backend couldn't read anything useful. Never
/// throws for a bad scan - OCR on phone-camera receipts is inherently
/// imperfect, so the caller always falls back to manual entry.
Future<InvoiceScanResult?> scanInvoiceReceipt(ApiClient api, XFile file) async {
  final bytes = await file.readAsBytes();
  final res = await api.uploadFile('/invoices/ocr-scan', bytes: bytes, filename: file.name);
  if (res is! Map<String, dynamic>) return null;

  final merchantName = res['merchantName'] as String?;
  final totalRaw = res['total'];
  final total = totalRaw is num ? totalRaw : num.tryParse('$totalRaw');
  final dateRaw = res['invoiceDate'] as String?;
  final invoiceDate = dateRaw != null ? DateTime.tryParse(dateRaw) : null;
  final warnings = (res['warnings'] as List?)?.map((w) => w.toString()).toList() ?? const <String>[];

  return InvoiceScanResult(merchantName: merchantName, invoiceDate: invoiceDate, total: total, warnings: warnings);
}
