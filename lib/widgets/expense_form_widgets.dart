import 'package:flutter/material.dart';
import '../models/simple_option.dart';

/// A single Agency/Advertiser attendee row (name + jabatan) - shared between
/// New Expense and Edit Expense, which both need "add/remove a participant
/// row" with its own controllers that survive list rebuilds.
class ParticipantEntry {
  final TextEditingController nameController;
  final TextEditingController positionController;

  ParticipantEntry({String name = '', String position = ''})
      : nameController = TextEditingController(text: name),
        positionController = TextEditingController(text: position);

  void dispose() {
    nameController.dispose();
    positionController.dispose();
  }
}

/// Generic searchable multi-select bottom sheet over an option list (Agency/
/// Advertiser/Brand) - shared between New Expense and Edit Expense.
Future<List<String>> pickMultiOptions(
  BuildContext context, {
  required String title,
  required List<SimpleOption> options,
  required List<String> selected,
}) async {
  final result = await showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final localSelected = Set<String>.from(selected);
      var filtered = options;
      return StatefulBuilder(
        builder: (context, setModalState) {
          void applyFilter(String term) {
            final t = term.trim().toLowerCase();
            setModalState(() => filtered = t.isEmpty ? options : options.where((o) => o.name.toLowerCase().contains(t)).toList());
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'),
                      onChanged: applyFilter,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: options.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No options available', style: TextStyle(color: Colors.grey))))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final o = filtered[i];
                              final checked = localSelected.contains(o.id);
                              return CheckboxListTile(
                                value: checked,
                                title: Text(o.name),
                                onChanged: (v) => setModalState(() {
                                  if (v == true) {
                                    localSelected.add(o.id);
                                  } else {
                                    localSelected.remove(o.id);
                                  }
                                }),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, localSelected.toList()),
                      child: Text('Done (${localSelected.length} selected)'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  return result ?? selected;
}

/// Selected-chips + "Select" button for a multi-select field - shared between
/// New Expense and Edit Expense (Agency/Advertiser/Brand pickers).
Widget buildMultiSelectField(
  BuildContext context, {
  required String label,
  required List<SimpleOption> options,
  required List<String> selectedIds,
  required void Function(List<String>) onChanged,
}) {
  final selectedOptions = selectedIds.map((id) => options.where((o) => o.id == id).firstOrNull).whereType<SimpleOption>().toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          TextButton.icon(
            onPressed: () async {
              final result = await pickMultiOptions(context, title: 'Select $label', options: options, selected: selectedIds);
              onChanged(result);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Select'),
          ),
        ],
      ),
      if (selectedOptions.isEmpty)
        Text('None selected', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey))
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in selectedOptions)
              Chip(
                label: Text(o.name),
                onDeleted: () => onChanged(selectedIds.where((id) => id != o.id).toList()),
              ),
          ],
        ),
    ],
  );
}

/// "+ Add" header plus a name/position row per entry - shared between New
/// Expense and Edit Expense (Agency/Advertiser Participants sections).
Widget buildParticipantsSection(
  BuildContext context, {
  required String title,
  required List<ParticipantEntry> entries,
  required VoidCallback onAdd,
  required void Function(int index) onRemove,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
        ],
      ),
      for (var i = 0; i < entries.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: TextFormField(controller: entries[i].nameController, decoration: const InputDecoration(labelText: 'Name'))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: entries[i].positionController, decoration: const InputDecoration(labelText: 'Position / Jabatan'))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => onRemove(i)),
            ],
          ),
        ),
    ],
  );
}
