import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../common.dart';
import 'complaints_page.dart';
import 'new_request.dart';
import 'recycle_page.dart';

class CitizenHome extends StatefulWidget {
  const CitizenHome({super.key});
  @override
  State<CitizenHome> createState() => _CitizenHomeState();
}

class _CitizenHomeState extends State<CitizenHome> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _saveToken();
  }

  /// Store the FCM token so Cloud Functions can push status updates.
  Future<void> _saveToken() async {
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      final t = await m.getToken();
      if (t != null) await db.doc('users/$uid').update({'fcmToken': t});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const _RequestsPage(), const ComplaintsPage(), const RecyclePage()];
    const titles = ['My Pickups', 'Complaints', 'Recycle & Rewards'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_i]), actions: [logoutButton()]),
      body: pages[_i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_shipping), label: 'Pickups'),
          NavigationDestination(icon: Icon(Icons.report_problem), label: 'Complaints'),
          NavigationDestination(icon: Icon(Icons.recycling), label: 'Recycle'),
        ],
      ),
    );
  }
}

class _RequestsPage extends StatelessWidget {
  const _RequestsPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Request pickup'),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const NewRequestPage())),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('requests').where('userId', isEqualTo: uid).snapshots(),
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final docs = newestFirst(s.data!.docs);
          if (docs.isEmpty) {
            return const Center(child: Text('No pickups yet. Tap "Request pickup".'));
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              for (final d in docs)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text('${d['wasteType']} • ${d['timeSlot']}'),
                    subtitle: Text('${fmtDate(d['scheduledDate'])}\n${d['address'] ?? ''}'),
                    isThreeLine: true,
                    trailing: statusChip(d['status']),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
