import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sale_sync_service.dart';

/// Widget to display offline sales sync status
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final saleSyncService = Provider.of<SaleSyncService>(context, listen: false);

    return FutureBuilder<int>(
      future: Future.value(saleSyncService.getUnsyncedCount()),
      builder: (context, snapshot) {
        final unsyncedCount = snapshot.data ?? 0;

        if (unsyncedCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.sync_problem, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unsyncedCount sale${unsyncedCount > 1 ? 's' : ''} pending sync',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    Text(
                      'Will sync automatically when online',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  // Manual sync trigger
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Attempting to sync...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  await saleSyncService.syncAll();
                },
                child: const Text('Sync Now'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dialog to show detailed sync status
class SyncStatusDialog extends StatelessWidget {
  const SyncStatusDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final saleSyncService = Provider.of<SaleSyncService>(context, listen: false);
    final unsyncedSales = saleSyncService.getUnsyncedSales();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Sync Status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (unsyncedSales.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'All sales synced!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${unsyncedSales.length} sale${unsyncedSales.length > 1 ? 's' : ''} pending sync:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: unsyncedSales.length,
                      itemBuilder: (context, index) {
                        final sale = unsyncedSales[index];
                        final hasError = sale.syncError != null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: hasError ? Colors.red.shade50 : null,
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              hasError ? Icons.error : Icons.pending,
                              color: hasError ? Colors.red : Colors.orange,
                            ),
                            title: Text('Invoice: ${sale.id}'),
                            subtitle: Text(
                              hasError
                                ? 'Error: ${sale.syncError}'
                                : 'Created: ${sale.createdAt.toString().split('.')[0]}',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasError ? Colors.red.shade700 : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Syncing sales...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        await saleSyncService.syncAll();
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync All Now'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SyncStatusDialog(),
    );
  }
}

