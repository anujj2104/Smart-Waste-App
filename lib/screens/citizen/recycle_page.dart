import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../common.dart';

const _guide = <Map<String, String>>[
  {'item': 'Plastic bottle', 'bin': 'Dry / Recyclable (Blue)', 'tip': 'Rinse and crush before disposal.'},
  {'item': 'Newspaper', 'bin': 'Dry / Recyclable (Blue)', 'tip': 'Keep dry; bundle together.'},
  {'item': 'Cardboard box', 'bin': 'Dry / Recyclable (Blue)', 'tip': 'Flatten it to save space.'},
  {'item': 'Glass bottle', 'bin': 'Dry / Recyclable (Blue)', 'tip': 'Do not mix with broken window glass.'},
  {'item': 'Metal can', 'bin': 'Dry / Recyclable (Blue)', 'tip': 'Rinse out food residue.'},
  {'item': 'Vegetable peels', 'bin': 'Wet / Organic (Green)', 'tip': 'Great for home composting.'},
  {'item': 'Leftover food', 'bin': 'Wet / Organic (Green)', 'tip': 'Drain liquids first.'},
  {'item': 'Garden waste', 'bin': 'Wet / Organic (Green)', 'tip': 'Compost leaves and grass.'},
  {'item': 'Battery', 'bin': 'Hazardous (Red)', 'tip': 'Drop at an e-waste collection point.'},
  {'item': 'Mobile phone', 'bin': 'E-waste', 'tip': 'Request an e-waste pickup.'},
  {'item': 'CFL / tube light', 'bin': 'Hazardous (Red)', 'tip': 'Contains mercury; never break it.'},
  {'item': 'Medicine / syringe', 'bin': 'Hazardous (Red)', 'tip': 'Wrap safely; never mix with dry waste.'},
  {'item': 'Sanitary waste', 'bin': 'Sanitary (Black)', 'tip': 'Wrap in paper and mark it.'},
];

const _tips = [
  'Segregate waste at source: wet, dry and hazardous.',
  'Carry a cloth bag; refuse single-use plastic.',
  'Compost kitchen waste to cut landfill volume by up to 40%.',
  'Rinse recyclables; dirty items spoil a whole batch.',
  'Donate old clothes and furniture instead of dumping them.',
];

class RecyclePage extends StatefulWidget {
  const RecyclePage({super.key});
  @override
  State<RecyclePage> createState() => _RecyclePageState();
}

class _RecyclePageState extends State<RecyclePage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final results = _guide
        .where((g) => g['item']!.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.doc('users/$uid').snapshots(),
        builder: (c, s) {
          final pts = s.data?.data()?['points'] ?? 0;
          return Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber, size: 36),
              title: Text('$pts reward points'),
              subtitle: const Text('Earn points for every completed pickup'),
            ),
          );
        },
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tip of the day', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_tips[DateTime.now().day % _tips.length]),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Where does this go? (e.g. battery)',
            border: OutlineInputBorder()),
        onChanged: (v) => setState(() => _q = v),
      ),
      const SizedBox(height: 8),
      for (final g in results)
        Card(
          child: ListTile(
            title: Text(g['item']!),
            subtitle: Text('${g['bin']}\n${g['tip']}'),
            isThreeLine: true,
          ),
        ),
      if (results.isEmpty) const Center(child: Text('No match found.')),
    ]);
  }
}
