import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/blocked_app.dart';
import '../widgets.dart';

class AddAppsScreen extends ConsumerStatefulWidget {
  const AddAppsScreen({super.key});

  @override
  ConsumerState<AddAppsScreen> createState() => _AddAppsScreenState();
}

class _AddAppsScreenState extends ConsumerState<AddAppsScreen> {
  final _selected = <String>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final installed = ref.watch(installedAppsProvider);
    final blocked = ref.watch(blockedAppsProvider).map((a) => a.packageName).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add apps to block', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: cs.surface,
      ),
      body: installed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load apps: $e')),
        data: (all) {
          final q = _query.trim().toLowerCase();
          final available = [
            for (final a in all)
              if (!blocked.contains(a.packageName) && (q.isEmpty || a.name.toLowerCase().contains(q))) a,
          ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SearchBar(
                  hintText: 'Search apps',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: available.isEmpty
                    ? Center(
                        child: Text(all.isEmpty ? 'No apps found.' : 'Nothing to add.',
                            style: TextStyle(color: cs.onSurfaceVariant)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: available.length,
                        itemBuilder: (_, i) {
                          final app = available[i];
                          final on = _selected.contains(app.packageName);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            leading: AppAvatar(app.name.isEmpty ? '?' : app.name[0].toUpperCase()),
                            title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: on ? cs.primary : Colors.transparent,
                                border: Border.all(color: on ? cs.primary : cs.outline, width: 2),
                              ),
                              child: on ? Icon(Icons.check, size: 14, color: cs.onPrimary) : null,
                            ),
                            onTap: () => setState(
                                () => on ? _selected.remove(app.packageName) : _selected.add(app.packageName)),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: FilledButton(
                  onPressed: _selected.isEmpty ? null : () => _confirm(all),
                  child: Text(_selected.isEmpty ? 'Add selected' : 'Add selected (${_selected.length})'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirm(List<InstalledApp> all) async {
    final chosen = [
      for (final a in all)
        if (_selected.contains(a.packageName)) BlockedApp(packageName: a.packageName, name: a.name),
    ];
    await ref.read(blockedAppsProvider.notifier).addAll(chosen);
    if (mounted) Navigator.of(context).pop();
  }
}
