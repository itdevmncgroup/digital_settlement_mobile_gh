import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bank_statement.dart';
import '../../services/api_client.dart';
import '../../utils/format.dart';
import '../../widgets/error_view.dart';
import 'statement_detail_screen.dart';

class StatementsScreen extends StatefulWidget {
  const StatementsScreen({super.key});

  @override
  State<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends State<StatementsScreen> {
  late Future<List<StatementBatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<StatementBatch>> _load() async {
    final api = context.read<ApiClient>();
    final data = await api.get('/bank-settlements') as List;
    return data.map((e) => StatementBatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settlement')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<StatementBatch>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(message: '${snapshot.error}', onRetry: _refresh);
            }
            final batches = snapshot.data ?? [];
            if (batches.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(child: Text('No bank statements uploaded yet', style: TextStyle(color: Colors.grey))),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: batches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = batches[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.description_outlined),
                    ),
                    title: Text(b.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${formatDate(b.createdAt)} · ${b.transactionCount} transactions · ${b.uploadedByName}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StatementDetailScreen(batchId: b.id)));
                      _refresh();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
