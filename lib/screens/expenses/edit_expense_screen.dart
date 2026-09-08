import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/expense_detail.dart';
import '../../models/simple_option.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../utils/thousands_formatter.dart';
import '../../widgets/authed_image.dart';
import '../../widgets/expense_form_widgets.dart';
import '../../widgets/photo_tile.dart';
import 'new_expense_screen.dart' show paymentMethods;

/// Mirrors New Expense's layout, pre-filled with the existing Expense's
/// values. Unit/Advertiser(primary)/Brand(primary)/Activity Type/POD are
/// locked once created (UpdateExpenseDto doesn't accept them - see
/// ExpensesService.update) and shown read-only; everything else (payment,
/// additional Agency/Advertiser/Brand, participants, photos, invoice total)
/// is editable, same as New Expense.
class EditExpenseScreen extends StatefulWidget {
  final ExpenseDetail expense;
  const EditExpenseScreen({super.key, required this.expense});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loadingOptions = true;
  String? _loadError;
  bool _saving = false;
  String? _saveError;

  List<SimpleOption> _advertiserOptions = [];
  List<SimpleOption> _brandOptions = [];
  List<SimpleOption> _agencyOptions = [];
  List<SimpleOption> _unitOptions = [];
  List<Map<String, String>> _creditCardOptions = [];

  late List<String> _advertiserIds; // additional advertisers only (primary is locked)
  late List<String> _brandIds; // additional brands only (primary is locked)
  late List<String> _agencyIds;
  String? _paymentMethodType;
  String? _creditCardId;
  late final TextEditingController _paymentNoteController;
  late final TextEditingController _merchantController;
  late final TextEditingController _locationController;
  late final TextEditingController _purposeController;
  late final TextEditingController _invoiceTotalController;
  DateTime? _expenseDate;
  bool _locating = false;

  late final List<ParticipantEntry> _agencyParticipants;
  late final List<ParticipantEntry> _advertiserParticipants;
  late final List<ParticipantEntry> _internalParticipants;

  final _picker = ImagePicker();
  final List<XFile> _activityPhotos = [];
  final List<XFile> _invoiceImages = [];

  bool get _isAdmin => context.read<AuthService>().user?.hasAnyRole(['ADMIN']) ?? false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _advertiserIds = e.extraAdvertisers.map((a) => a.id).toList();
    _brandIds = e.extraBrands.map((b) => b.id).toList();
    _agencyIds = e.extraAgencies.map((a) => a.id).toList();
    _paymentMethodType = e.paymentMethodType;
    _creditCardId = e.creditCardId;
    _paymentNoteController = TextEditingController(text: e.paymentMethodNote ?? '');
    _merchantController = TextEditingController(text: e.merchantName ?? '');
    _locationController = TextEditingController(text: e.location ?? '');
    _purposeController = TextEditingController(text: e.purpose);
    final invoiceTotal = e.invoices.isNotEmpty ? e.invoices.first.total : null;
    _invoiceTotalController = TextEditingController(text: invoiceTotal != null ? formatThousands(invoiceTotal) : '');
    _expenseDate = DateTime.tryParse(e.expenseDate);
    _agencyParticipants = e.participants
        .where((p) => p.category == 'AGENCY')
        .map((p) => ParticipantEntry(name: p.name, position: p.position ?? '', selectedId: p.agencyId))
        .toList();
    _advertiserParticipants = e.participants
        .where((p) => p.category == 'ADVERTISER')
        .map((p) => ParticipantEntry(name: p.name, position: p.position ?? '', selectedId: p.advertiserId))
        .toList();
    _internalParticipants = e.participants
        .where((p) => p.category == 'EMPLOYEE')
        .map((p) => ParticipantEntry(name: p.name, position: p.position ?? '', selectedId: p.unitId))
        .toList();
    _loadOptions();
  }

  @override
  void dispose() {
    _paymentNoteController.dispose();
    _merchantController.dispose();
    _locationController.dispose();
    _purposeController.dispose();
    _invoiceTotalController.dispose();
    for (final p in _agencyParticipants) {
      p.dispose();
    }
    for (final p in _advertiserParticipants) {
      p.dispose();
    }
    for (final p in _internalParticipants) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _loadError = null;
    });
    final api = context.read<ApiClient>();
    try {
      final results = await Future.wait([api.get('/advertisers'), api.get('/agencies'), api.get('/units')]);
      _advertiserOptions = (results[0] as List).map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
      _agencyOptions = (results[1] as List).map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
      _unitOptions = (results[2] as List).map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      _loadError = e.message;
    } catch (e) {
      _loadError = 'Failed to load form data - check your connection.';
    } finally {
      if (mounted) {
        setState(() => _loadingOptions = false);
        unawaited(_loadBrandsForAdvertisers(_advertiserIds));
        unawaited(_loadCreditCards());
      }
    }
  }

  Future<void> _loadBrandsForAdvertisers(List<String> extraAdvertiserIds) async {
    final ids = {widget.expense.advertiserId, ...extraAdvertiserIds}.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) {
      setState(() {
        _brandOptions = [];
        _brandIds = [];
      });
      return;
    }
    final api = context.read<ApiClient>();
    try {
      final data = await api.get('/brands?advertiserIds=${ids.join(',')}') as List;
      setState(() {
        _brandOptions = data.map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
        _brandIds = _brandIds.where((id) => _brandOptions.any((b) => b.id == id)).toList();
      });
    } catch (_) {
      setState(() => _brandOptions = []);
    }
  }

  /// 1 POD = 1 credit card (BR) - only the card(s) assigned to this expense's
  /// POD may be picked. Super Admin is exempt and sees every card.
  Future<void> _loadCreditCards() async {
    final admin = _isAdmin;
    final podId = widget.expense.podId;
    if (!admin && podId == null) {
      if (mounted) setState(() => _creditCardOptions = []);
      return;
    }
    final api = context.read<ApiClient>();
    try {
      final path = admin ? '/credit-cards' : '/credit-cards?podId=$podId';
      final data = await api.get(path) as List;
      if (!mounted) return;
      setState(() {
        _creditCardOptions = data
            .map((e) => {'id': e['id'] as String, 'label': '${e['bank']} •••• ${e['last4']} (${e['cardHolderName']})'})
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _creditCardOptions = []);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _expenseDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _expenseDate = picked);
  }

  // Only fetched on explicit button tap (unlike New Expense's auto-fetch on
  // load) - re-fetching automatically here would silently overwrite an
  // already-saved location as soon as the Edit screen opens.
  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are off.');
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
        _locationController.text = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addActivityPhotos() async {
    final source = await _pickSource();
    if (source == null) return;
    if (source == ImageSource.gallery) {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isNotEmpty) setState(() => _activityPhotos.addAll(files));
    } else {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file != null) setState(() => _activityPhotos.add(file));
    }
  }

  Future<void> _addInvoicePhotos() async {
    final source = await _pickSource();
    if (source == null) return;
    if (source == ImageSource.gallery) {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isNotEmpty) setState(() => _invoiceImages.addAll(files));
    } else {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file != null) setState(() => _invoiceImages.add(file));
    }
  }

  Future<ImageSource?> _pickSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery (pick one or more)'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final api = context.read<ApiClient>();
    final expenseId = widget.expense.id;
    try {
      final participants = [
        for (final p in _agencyParticipants)
          if (p.nameController.text.trim().isNotEmpty)
            {
              'category': 'AGENCY',
              'name': p.nameController.text.trim(),
              if (p.positionController.text.trim().isNotEmpty) 'position': p.positionController.text.trim(),
              if (p.selectedId != null) 'agencyId': p.selectedId,
            },
        for (final p in _advertiserParticipants)
          if (p.nameController.text.trim().isNotEmpty)
            {
              'category': 'ADVERTISER',
              'name': p.nameController.text.trim(),
              if (p.positionController.text.trim().isNotEmpty) 'position': p.positionController.text.trim(),
              if (p.selectedId != null) 'advertiserId': p.selectedId,
            },
        for (final p in _internalParticipants)
          if (p.nameController.text.trim().isNotEmpty)
            {
              'category': 'EMPLOYEE',
              'name': p.nameController.text.trim(),
              if (p.positionController.text.trim().isNotEmpty) 'position': p.positionController.text.trim(),
              if (p.selectedId != null) 'unitId': p.selectedId,
            },
      ];

      final invoiceTotal = unformatNumber(_invoiceTotalController.text) ?? 0;

      final payload = <String, dynamic>{
        if (_expenseDate != null) 'expenseDate': _expenseDate!.toIso8601String(),
        'purpose': _purposeController.text.trim(),
        'amount': invoiceTotal,
        'paymentMethodType': _paymentMethodType,
        if (_paymentMethodType == 'CREDIT_CARD') 'creditCardId': _creditCardId,
        'paymentMethodNote': _paymentNoteController.text.trim().isEmpty ? null : _paymentNoteController.text.trim(),
        'merchantName': _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
        'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        'extraAgencyIds': _agencyIds,
        'extraAdvertiserIds': _advertiserIds,
        'extraBrandIds': _brandIds,
        'participants': participants,
      };
      await api.patch('/expenses/$expenseId', payload);

      for (final photo in _activityPhotos) {
        await api.uploadFile('/expenses/$expenseId/photos', bytes: await photo.readAsBytes(), filename: photo.name);
      }

      if (widget.expense.invoices.isNotEmpty) {
        final invoiceId = widget.expense.invoices.first.id;
        await api.patch('/invoices/$invoiceId', {'finalTotal': invoiceTotal});
        for (final file in _invoiceImages) {
          await api.uploadFile('/invoices/$invoiceId/files', bytes: await file.readAsBytes(), filename: file.name);
        }
      } else if (invoiceTotal > 0) {
        final invoice = await api.post('/expenses/$expenseId/invoices', {'finalTotal': invoiceTotal}) as Map<String, dynamic>;
        final invoiceId = invoice['id'] as String;
        for (final file in _invoiceImages) {
          await api.uploadFile('/invoices/$invoiceId/files', bytes: await file.readAsBytes(), filename: file.name);
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _saveError = e.message);
    } catch (e) {
      setState(() => _saveError = 'Save failed - check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${e.expenseNo}')),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _loadOptions, child: const Text('Retry')),
                    ]),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _lockedFieldsCard(e),
                      const SizedBox(height: 16),
                      buildMultiSelectField(
                        context,
                        label: 'Additional Advertisers',
                        options: _advertiserOptions,
                        selectedIds: _advertiserIds,
                        onChanged: (ids) {
                          setState(() => _advertiserIds = ids);
                          _loadBrandsForAdvertisers(ids);
                        },
                      ),
                      const SizedBox(height: 16),
                      buildMultiSelectField(context, label: 'Additional Brands', options: _brandOptions, selectedIds: _brandIds, onChanged: (ids) => setState(() => _brandIds = ids)),
                      const SizedBox(height: 20),
                      _sectionTitle('Agency'),
                      buildMultiSelectField(context, label: 'Agency (optional)', options: _agencyOptions, selectedIds: _agencyIds, onChanged: (ids) => setState(() => _agencyIds = ids)),
                      const SizedBox(height: 8),
                      buildParticipantsSection(
                        context,
                        title: 'Agency Participants',
                        entries: _agencyParticipants,
                        comboLabel: 'Agency',
                        comboOptions: _agencyOptions.where((o) => _agencyIds.contains(o.id)).toList(),
                        onComboChanged: (i, id) => setState(() => _agencyParticipants[i].selectedId = id),
                        onAdd: () => setState(() => _agencyParticipants.add(ParticipantEntry())),
                        onRemove: (i) => setState(() {
                          _agencyParticipants[i].dispose();
                          _agencyParticipants.removeAt(i);
                        }),
                      ),
                      const SizedBox(height: 16),
                      buildParticipantsSection(
                        context,
                        title: 'Advertiser Participants',
                        entries: _advertiserParticipants,
                        comboLabel: 'Advertiser',
                        // _advertiserIds only tracks the *additional* advertisers here
                        // (the primary is locked, e.advertiserId) - the combobox should
                        // still offer it since it's clearly "selected" for this expense.
                        comboOptions: _advertiserOptions
                            .where((o) => o.id == widget.expense.advertiserId || _advertiserIds.contains(o.id))
                            .toList(),
                        onComboChanged: (i, id) => setState(() => _advertiserParticipants[i].selectedId = id),
                        onAdd: () => setState(() => _advertiserParticipants.add(ParticipantEntry())),
                        onRemove: (i) => setState(() {
                          _advertiserParticipants[i].dispose();
                          _advertiserParticipants.removeAt(i);
                        }),
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('Internal Participant'),
                      buildParticipantsSection(
                        context,
                        title: 'Internal Participants',
                        entries: _internalParticipants,
                        comboLabel: 'Unit',
                        comboOptions: _unitOptions,
                        onComboChanged: (i, id) => setState(() => _internalParticipants[i].selectedId = id),
                        onAdd: () => setState(() => _internalParticipants.add(ParticipantEntry())),
                        onRemove: (i) => setState(() {
                          _internalParticipants[i].dispose();
                          _internalParticipants.removeAt(i);
                        }),
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Expense Date', suffixIcon: Icon(Icons.calendar_today)),
                          child: Text(_expenseDate == null
                              ? 'Select date'
                              : '${_expenseDate!.year}-${_expenseDate!.month.toString().padLeft(2, '0')}-${_expenseDate!.day.toString().padLeft(2, '0')}'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _purposeController,
                        decoration: const InputDecoration(labelText: 'Purpose'),
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Purpose is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _merchantController, decoration: const InputDecoration(labelText: 'Merchant (optional)')),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location (optional)'))),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _locating ? null : _useMyLocation,
                            icon: _locating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
                            tooltip: 'Use my location',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentMethod(),
                      const SizedBox(height: 24),
                      _sectionTitle('Foto Kegiatan'),
                      if (e.photos.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final p in e.photos) AuthedThumb(path: '/expenses/photos/${p.id}/download', fileName: p.fileName, isImage: p.mimeType.startsWith('image/'))],
                        ),
                        const SizedBox(height: 8),
                      ],
                      PhotoTileRow(files: _activityPhotos, onAdd: _addActivityPhotos, onRemove: (i) => setState(() => _activityPhotos.removeAt(i))),
                      const SizedBox(height: 24),
                      _sectionTitle('Invoice / Receipt'),
                      if (e.invoices.isNotEmpty && e.invoices.first.files.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final f in e.invoices.first.files)
                              AuthedThumb(path: '/invoices/files/${f.id}/download', fileName: f.fileName, isImage: f.mimeType.startsWith('image/')),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      PhotoTileRow(files: _invoiceImages, onAdd: _addInvoicePhotos, onRemove: (i) => setState(() => _invoiceImages.removeAt(i))),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _invoiceTotalController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsInputFormatter()],
                        decoration: const InputDecoration(labelText: 'Invoice Total (IDR)'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Invoice total is required' : null,
                      ),
                      if (_saveError != null) ...[
                        const SizedBox(height: 16),
                        Text(_saveError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes'),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _lockedFieldsCard(ExpenseDetail e) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Locked (set at creation, cannot be changed)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            if (e.podName != null) _lockedRow('POD', e.podName!),
            _lockedRow('Unit', e.unitName),
            _lockedRow('Advertiser', e.advertiserName),
            _lockedRow('Brand', e.brandName),
            _lockedRow('Activity Type', e.activityTypeName),
          ],
        ),
      ),
    );
  }

  Widget _lockedRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _paymentMethodType,
          decoration: const InputDecoration(labelText: 'Payment Method (optional)'),
          items: paymentMethods.map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2))).toList(),
          onChanged: (v) => setState(() {
            _paymentMethodType = v;
            _creditCardId = null;
            _paymentNoteController.clear();
          }),
        ),
        if (_paymentMethodType == 'CREDIT_CARD') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _creditCardId,
            decoration: const InputDecoration(labelText: 'Credit Card'),
            items: _creditCardOptions.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['label']!, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _creditCardId = v),
          ),
        ],
        if (_paymentMethodType != null && _paymentMethodType != 'CREDIT_CARD' && _paymentMethodType != 'CASH' && _paymentMethodType != 'BANK_TRANSFER') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _paymentNoteController,
            decoration: InputDecoration(labelText: _paymentMethodType == 'OTHER' ? 'Please specify' : 'Account / Phone Number (optional)'),
          ),
        ],
      ],
    );
  }
}
