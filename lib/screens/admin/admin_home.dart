import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../common.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  Future<void> _optimize(BuildContext context) async {
    try {
      final r = await FirebaseFunctions.instance
          .httpsCallable('optimizeRoutes')
          .call({'date': DateTime.now().toIso8601String()});
      if (context.mounted) snack(context, 'Routes optimized: ${r.data['routes']} route(s)');
    } catch (e) {
      if (context.mounted) snack(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
                tooltip: 'Optimize today\'s routes',
                icon: const Icon(Icons.route),
                onPressed: () => _optimize(context)),
            logoutButton(),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Requests'),
            Tab(text: 'Complaints'),
            Tab(text: 'Stats'),
          ]),
        ),
        body: const TabBarView(children: [_Requests(), _Complaints(), _Stats()]),
      ),
    );
  }
}

class _Requests extends StatelessWidget {
  const _Requests();

  Future<void> _assign(BuildContext context, DocumentReference ref) async {
    final drivers = await db.collection('users').where('role', isEqualTo: 'driver').get();
    if (!context.mounted) return;
    if (drivers.docs.isEmpty) {
      snack(context, 'No drivers yet. Set a user\'s role to "driver" in Firestore.');
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(title: const Text('Assign driver'), children: [
        for (final d in drivers.docs)
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d.id),
              child: Text(d['name'] ?? d['email'])),
      ]),
    );
    if (picked != null) {
      await ref.update({'driverId': picked, 'status': 'scheduled'});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('requests').snapshots(),
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = newestFirst(s.data!.docs);
        if (docs.isEmpty) return const Center(child: Text('No requests.'));
        return ListView(children: [
          for (final d in docs)
            Card(
              child: ListTile(
                title: Text('${d['wasteType']} • ${fmtDate(d['scheduledDate'])} ${d['timeSlot']}'),
                subtitle: Text('${d['address'] ?? ''}\nDriver: ${d['driverId'] ?? 'unassigned'}'),
                isThreeLine: true,
                leading: statusChip(d['status']),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'assign') {
                      _assign(context, d.reference);
                    } else {
                      d.reference.update({'status': v});
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'assign', child: Text('Assign driver')),
                    PopupMenuItem(value: 'pending', child: Text('Mark pending')),
                    PopupMenuItem(value: 'in_progress', child: Text('Mark in progress')),
                    PopupMenuItem(value: 'completed', child: Text('Mark completed')),
                    PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
                  ],
                ),
              ),
            ),
        ]);
      },
    );
  }
}

class _Complaints extends StatelessWidget {
  const _Complaints();

  Future<void> _resolve(BuildContext context, DocumentReference ref) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resolve complaint'),
        content: TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'Resolution note')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (ok == true) {
      await ref.update({'status': 'resolved', 'resolutionNote': note.text.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('complaints').snapshots(),
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = newestFirst(s.data!.docs);
        if (docs.isEmpty) return const Center(child: Text('No complaints.'));
        return ListView(children: [
          for (final d in docs)
            Card(
              child: ListTile(
                title: Text(d['category']),
                subtitle: Text(d['description'] ?? ''),
                leading: d['photoUrl'] != null
                    ? Image.network(d['photoUrl'], width: 48, height: 48, fit: BoxFit.cover)
                    : const Icon(Icons.report),
                trailing: d['status'] == 'resolved'
                    ? statusChip('resolved')
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        statusChip(d['status']),
                        IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () => _resolve(context, d.reference)),
                      ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('requests').snapshots(),
      builder: (c, rs) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('complaints').snapshots(),
        builder: (c, cs) {
          if (!rs.hasData || !cs.hasData) return const Center(child: CircularProgressIndicator());
          final r = rs.data!.docs, k = cs.data!.docs;
          Map<String, int> count(List<QueryDocumentSnapshot<Map<String, dynamic>>> l, String f) {
            final m = <String, int>{};
            for (final d in l) {
              final v = '${d[f]}';
              m[v] = (m[v] ?? 0) + 1;
            }
            return m;
          }

          final resolved = k.where((d) => d['status'] == 'resolved').length;
          Widget bars(String title, Map<String, int> m, int total) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    for (final e in m.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${e.key}: ${e.value}'),
                          LinearProgressIndicator(
                              value: total == 0 ? 0 : e.value / total,
                              minHeight: 8,
                              color: statusColor(e.key)),
                        ]),
                      ),
                  ]),
                ),
              );
          return ListView(padding: const EdgeInsets.all(12), children: [
            Row(children: [
              _tile('Requests', '${r.length}'),
              _tile('Complaints', '${k.length}'),
              _tile('Resolved', k.isEmpty ? '0%' : '${(resolved * 100 / k.length).round()}%'),
            ]),
            bars('Requests by status', count(r, 'status'), r.length),
            bars('Requests by waste type', count(r, 'wasteType'), r.length),
            bars('Complaints by category', count(k, 'category'), k.length),
          ]);
        },
      ),
    );
  }

  Widget _tile(String t, String v) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Text(t),
            ]),
          ),
        ),
      );
}
