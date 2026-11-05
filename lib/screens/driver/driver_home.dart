import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../common.dart';

class DriverHome extends StatelessWidget {
  const DriverHome({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Route'), actions: [logoutButton()]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('requests').where('driverId', isEqualTo: uid).snapshots(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final docs = s.data!.docs
              .where((d) => d['status'] == 'scheduled' || d['status'] == 'in_progress')
              .toList()
            ..sort((a, b) =>
                ((a.data()['stopOrder'] ?? 999) as int).compareTo((b.data()['stopOrder'] ?? 999) as int));
          if (docs.isEmpty) return const Center(child: Text('No pending stops. 🎉'));
          return ListView(children: [
            for (var i = 0; i < docs.length; i++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text('${docs[i]['wasteType']} • ${docs[i]['timeSlot']}'),
                  subtitle: Text('${docs[i]['address'] ?? ''}\n'
                      '${(docs[i]['location'] as GeoPoint).latitude.toStringAsFixed(5)}, '
                      '${(docs[i]['location'] as GeoPoint).longitude.toStringAsFixed(5)}'),
                  isThreeLine: true,
                  trailing: docs[i]['status'] == 'scheduled'
                      ? FilledButton(
                          onPressed: () => docs[i].reference.update({'status': 'in_progress'}),
                          child: const Text('Start'))
                      : FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () => docs[i].reference.update({'status': 'completed'}),
                          child: const Text('Done')),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
