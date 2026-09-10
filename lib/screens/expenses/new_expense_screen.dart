import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/simple_option.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../utils/format.dart';
import '../../utils/invoice_ocr.dart';
import '../../utils/thousands_formatter.dart';
import '../../widgets/expense_form_widgets.dart';
import '../../widgets/photo_tile.dart';

const paymentMethods = [
  ('CREDIT_CARD', 'Credit Card'),
  ('GOPAY', 'GoPay'),
  ('SHOPEEPAY', 'ShopeePay'),
  ('DANA', 'Dana'),
  ('OVO', 'OVO'),
  ('BANK_TRANSFER', 'Bank Transfer'),
  ('CASH', 'Cash'),
  ('OTHER', 'Others'),
];

class NewExpenseScreen extends StatefulWidget {
  const NewExpenseScreen({super.key});

  @override
  State<NewExpenseScreen> createState() => _NewExpenseScreenState();
}

class _NewExpenseScreenState extends State<NewExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loadingOptions = true;
  String? _loadError;
  bool _saving = false;
  String? _saveError;

  List<SimpleOption> _departmentOptions = [];
  List<SimpleOption> _activityTypeOptions = [];
  List<SimpleOption> _advertiserOptions = [];
  List<SimpleOption> _brandOptions = [];
  List<SimpleOption> _agencyOptions = [];
  List<SimpleOption> _unitOptions = [];
  List<Map<String, String>> _creditCardOptions = []; // {id, label}

  String? _departmentId;
  List<String> _advertiserIds = [];
  List<String> _brandIds = [];
  List<String> _agencyIds = [];
  String? _activityTypeId;
  String? _paymentMethodType;
  String? _creditCardId;
  final _paymentNoteController = TextEditingController();
  final _merchantController = TextEditingController();
  final _locationController = TextEditingController();
  final _purposeController = TextEditingController();
  DateTime? _expenseDate;
  bool _locating = false;

  final List<ParticipantEntry> _agencyParticipants = [];
  final List<ParticipantEntry> _advertiserParticipants = [];
  final List<ParticipantEntry> _internalParticipants = [];

  final _picker = ImagePicker();
  final List<XFile> _activityPhotos = [];
  final List<XFile> _invoiceImages = [];
  final _invoiceTotalController = TextEditingController();
  bool _scanningInvoice = false;

  bool get _isAdmin => context.read<AuthService>().user?.hasAnyRole(['ADMIN']) ?? false;

  @override
  void initState() {
    super.initState();
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
      final results = await Future.wait([
        api.get('/departments/me'),
        api.get('/activity-types'),
        api.get('/advertisers'),
        api.get('/agencies'),
        api.get('/units'),
      ]);
      _departmentOptions = (results[0] as List).map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
      _activityTypeOptions = (results[1] as List).map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
      _advertiserOptions = (results[2] as List).map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
      _agencyOptions = (results[3] as List).map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
      _unitOptions = (results[4] as List).map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
      if (_departmentOptions.isNotEmpty) _departmentId = _departmentOptions.first.id;
    } on ApiException catch (e) {
      _loadError = e.message;
    } catch (e) {
      _loadError = 'Failed to load form data - check your connection.';
    } finally {
      if (mounted) {
        setState(() => _loadingOptions = false);
        unawaited(_loadCreditCards());
        unawaited(_useMyLocation());
      }
    }
  }

  Future<void> _loadBrandsForAdvertisers(List<String> advertiserIds) async {
    if (advertiserIds.isEmpty) {
      setState(() {
        _brandOptions = [];
        _brandIds = [];
      });
      return;
    }
    final api = context.read<ApiClient>();
    try {
      final data = await api.get('/brands?advertiserIds=${advertiserIds.join(',')}') as List;
      setState(() {
        _brandOptions = data.map((e) => SimpleOption.fromJson(e as Map<String, dynamic>)).toList();
        _brandIds = _brandIds.where((id) => _brandOptions.any((b) => b.id == id)).toList();
      });
    } catch (_) {
      setState(() => _brandOptions = []);
    }
  }

  /// 1 Department = 1 credit card (BR) - only the card(s) assigned to the selected
  /// Department may be chosen, so the dropdown is re-fetched every time Department changes.
  /// Super Admin is exempt from the Department restriction and sees every card.
  Future<void> _loadCreditCards() async {
    final api = context.read<ApiClient>();
    final admin = _isAdmin;
    if (!admin && _departmentId == null) {
      setState(() {
        _creditCardOptions = [];
        _creditCardId = null;
      });
      return;
    }
    try {
      final path = admin ? '/credit-cards' : '/credit-cards?departmentId=$_departmentId';
      final data = await api.get(path) as List;
      if (!mounted) return;
      setState(() {
        _creditCardOptions = data
            .map((e) => {
                  'id': e['id'] as String,
                  'label': '${e['bank']} •••• ${e['last4']} (${e['cardHolderName']})',
                })
            .toList();
        if (_creditCardId != null && !_creditCardOptions.any((c) => c['id'] == _creditCardId)) {
          _creditCardId = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _creditCardOptions = []);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

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
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        _locationController.text = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
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
    final hadNoInvoiceYet = _invoiceImages.isEmpty;
    XFile? firstAdded;
    if (source == ImageSource.gallery) {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isNotEmpty) {
        setState(() => _invoiceImages.addAll(files));
        firstAdded = files.first;
      }
    } else {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file != null) {
        setState(() => _invoiceImages.add(file));
        firstAdded = file;
      }
    }
    // Only auto-read the first invoice photo of the form - later ones are
    // usually extra pages/angles of the same receipt, not a new one to scan.
    if (hadNoInvoiceYet && firstAdded != null) {
      await _scanInvoice(firstAdded);
    }
  }

  /// Reads the invoice photo via the backend's OCR endpoint and pre-fills the
  /// transaction date, merchant name, and invoice total - but never
  /// overwrites a value the user already typed, and never blocks/fails the
  /// upload itself since OCR on a phone-camera receipt is best-effort.
  Future<void> _scanInvoice(XFile file) async {
    setState(() => _scanningInvoice = true);
    try {
      final api = context.read<ApiClient>();
      final result = await scanInvoiceReceipt(api, file);
      if (!mounted || result == null) return;
      setState(() {
        if (result.merchantName != null && result.merchantName!.trim().isNotEmpty && _merchantController.text.trim().isEmpty) {
          _merchantController.text = result.merchantName!.trim();
        }
        if (result.total != null && _invoiceTotalController.text.trim().isEmpty) {
          _invoiceTotalController.text = formatThousands(result.total!.toString());
        }
        if (result.invoiceDate != null && _expenseDate == null) {
          _expenseDate = result.invoiceDate;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice scanned - please review the pre-filled fields.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not auto-read the invoice - please fill the fields manually.')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanningInvoice = false);
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
    if (_expenseDate == null) {
      setState(() => _saveError = 'Pick an expense date.');
      return;
    }
    if (_advertiserIds.isEmpty || _brandIds.isEmpty || _activityTypeId == null) {
      setState(() => _saveError = 'Advertiser, Brand and Activity Type are all required.');
      return;
    }
    final unitId = context.read<AuthService>().user?.unitId;
    if (unitId == null) {
      setState(() => _saveError = 'Your account has no Unit assigned - contact an Admin.');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final api = context.read<ApiClient>();
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
        'expenseDate': dateOnlyString(_expenseDate!),
        'purpose': _purposeController.text.trim(),
        'amount': invoiceTotal,
        'unitId': unitId,
        'advertiserId': _advertiserIds.first,
        'brandId': _brandIds.first,
        'activityTypeId': _activityTypeId,
        if (_departmentId != null) 'departmentId': _departmentId,
        if (_advertiserIds.length > 1) 'extraAdvertiserIds': _advertiserIds.skip(1).toList(),
        if (_brandIds.length > 1) 'extraBrandIds': _brandIds.skip(1).toList(),
        if (_agencyIds.isNotEmpty) 'extraAgencyIds': _agencyIds,
        if (_paymentMethodType != null) 'paymentMethodType': _paymentMethodType,
        if (_paymentMethodType == 'CREDIT_CARD' && _creditCardId != null) 'creditCardId': _creditCardId,
        if (_paymentNoteController.text.trim().isNotEmpty) 'paymentMethodNote': _paymentNoteController.text.trim(),
        if (_merchantController.text.trim().isNotEmpty) 'merchantName': _merchantController.text.trim(),
        if (_locationController.text.trim().isNotEmpty) 'location': _locationController.text.trim(),
        if (participants.isNotEmpty) 'participants': participants,
      };

      final created = await api.post('/expenses', payload) as Map<String, dynamic>;
      final expenseId = created['id'] as String;

      for (final photo in _activityPhotos) {
        await api.uploadFile('/expenses/$expenseId/photos', bytes: await photo.readAsBytes(), filename: photo.name);
      }

      final invoicePayload = <String, dynamic>{'finalTotal': invoiceTotal};
      final invoice = await api.post('/expenses/$expenseId/invoices', invoicePayload) as Map<String, dynamic>;
      final invoiceId = invoice['id'] as String;
      for (final file in _invoiceImages) {
        await api.uploadFile('/invoices/$invoiceId/files', bytes: await file.readAsBytes(), filename: file.name);
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
    return Scaffold(
      appBar: AppBar(title: const Text('New Expense')),
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
                      if (_departmentOptions.isNotEmpty) _buildDepartmentDropdown(),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _activityTypeId,
                        decoration: const InputDecoration(labelText: 'Activity Type'),
                        items: _activityTypeOptions.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                        onChanged: (v) => setState(() => _activityTypeId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      buildMultiSelectField(
                        context,
                        label: 'Advertiser',
                        options: _advertiserOptions,
                        selectedIds: _advertiserIds,
                        onChanged: (ids) {
                          setState(() => _advertiserIds = ids);
                          _loadBrandsForAdvertisers(ids);
                        },
                      ),
                      const SizedBox(height: 16),
                      buildMultiSelectField(context, label: 'Brand', options: _brandOptions, selectedIds: _brandIds, onChanged: (ids) => setState(() => _brandIds = ids)),
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
                        comboOptions: _advertiserOptions.where((o) => _advertiserIds.contains(o.id)).toList(),
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
                      _buildDateField(),
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
                          Expanded(
                            child: TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(labelText: 'Location (optional)'),
                            ),
                          ),
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
                      PhotoTileRow(
                        files: _activityPhotos,
                        onAdd: _addActivityPhotos,
                        onRemove: (i) => setState(() => _activityPhotos.removeAt(i)),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _sectionTitle('Invoice / Receipt'),
                          if (_scanningInvoice) ...[
                            const SizedBox(width: 8),
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 6),
                            Text('Reading invoice...', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ],
                      ),
                      PhotoTileRow(
                        files: _invoiceImages,
                        onAdd: _addInvoicePhotos,
                        onRemove: (i) => setState(() => _invoiceImages.removeAt(i)),
                      ),
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
                            : const Text('Save Draft'),
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

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Expense Date', suffixIcon: Icon(Icons.calendar_today)),
        child: Text(_expenseDate == null ? 'Select date' : dateOnlyString(_expenseDate!)),
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _departmentId,
      decoration: const InputDecoration(labelText: 'Department'),
      items: _departmentOptions.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
      onChanged: (v) {
        setState(() => _departmentId = v);
        _loadCreditCards();
      },
    );
  }

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
