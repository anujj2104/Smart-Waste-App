import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../common.dart';

class ComplaintsPage extends StatelessWidget {
  const ComplaintsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New complaint'),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const _NewComplaint())),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('complaints').where('userId', isEqualTo: uid).snapshots(),
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final docs = newestFirst(s.data!.docs);
          if (docs.isEmpty) return const Center(child: Text('No complaints filed.'));
          return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
            for (final d in docs)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                          child: Text(d['category'],
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                      statusChip(d['status']),
                    ]),
                    Text(d['description'] ?? ''),
                    if (d['photoUrl'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Image.network(d['photoUrl'], height: 120),
                      ),
                    if ((d['resolutionNote'] ?? '').toString().isNotEmpty)
                      Text('Resolution: ${d['resolutionNote']}',
                          style: const TextStyle(color: Colors.green)),
                    if (d['status'] == 'resolved')
                      Row(children: [
                        const Text('Rate: '),
                        for (var i = 1; i <= 5; i++)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                                i <= (d['rating'] ?? 0) ? Icons.star : Icons.star_border,
                                color: Colors.amber),
                            onPressed: () => d.reference.update({'rating': i}),
                          ),
                      ]),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _NewComplaint extends StatefulWidget {
  const _NewComplaint();
  @override
  State<_NewComplaint> createState() => _NewComplaintState();
}

class _NewComplaintState extends State<_NewComplaint> {
  String _cat = complaintCategories.first;
  final _desc = TextEditingController();
  XFile? _photo;
  bool _busy = false;

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (f != null) setState(() => _photo = f);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      String? url;
      if (_photo != null) {
        final ref = FirebaseStorage.instance
            .ref('complaints/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(File(_photo!.path));
        url = await ref.getDownloadURL();
      }
      GeoPoint? gp;
      try {
        final p = await Geolocator.getCurrentPosition();
        gp = GeoPoint(p.latitude, p.longitude);
      } catch (_) {}
      await db.collection('complaints').add({
        'userId': uid,
        'category': _cat,
        'description': _desc.text.trim(),
        'photoUrl': url,
        'location': gp,
        'status': 'open',
        'resolutionNote': '',
        'rating': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        snack(context, 'Complaint submitted');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) snack(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New complaint')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          value: _cat,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final t in complaintCategories) DropdownMenuItem(value: t, child: Text(t))],
          onChanged: (v) => setState(() => _cat = v!),
        ),
        TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Describe the problem')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.camera_alt),
            label: Text(_photo == null ? 'Add photo' : 'Photo added ✓')),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Submit')),
      ]),
    );
  }
}
