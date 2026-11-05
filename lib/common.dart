import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final db = FirebaseFirestore.instance;
String get uid => FirebaseAuth.instance.currentUser!.uid;

const wasteTypes = ['Household', 'Recyclable', 'Bulk', 'E-waste', 'Hazardous'];
const timeSlots = ['8-10 AM', '10-12 PM', '2-4 PM', '4-6 PM'];
const complaintCategories = [
  'Missed pickup',
  'Overflowing bin',
  'Illegal dumping',
  'Other'
];
// Default map centre (Ludhiana). Change to your city.
const defaultLat = 30.9010;
const defaultLng = 75.8573;

Color statusColor(String s) {
  switch (s) {
    case 'pending':
    case 'open':
      return Colors.orange;
    case 'scheduled':
      return Colors.blue;
    case 'in_progress':
      return Colors.purple;
    case 'completed':
    case 'resolved':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

Widget statusChip(String s) => Chip(
      label: Text(s.replaceAll('_', ' ')),
      backgroundColor: statusColor(s).withOpacity(.15),
      side: BorderSide(color: statusColor(s)),
      visualDensity: VisualDensity.compact,
    );

Widget logoutButton() => IconButton(
      tooltip: 'Logout',
      icon: const Icon(Icons.logout),
      onPressed: () => FirebaseAuth.instance.signOut(),
    );

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

String fmtDate(dynamic t) {
  if (t is! Timestamp) return '';
  final d = t.toDate();
  return '${d.day}/${d.month}/${d.year}';
}

/// Sort docs by createdAt descending on the client (avoids composite indexes).
List<QueryDocumentSnapshot<Map<String, dynamic>>> newestFirst(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  final l = [...docs];
  l.sort((a, b) {
    final x = a.data()['createdAt'] as Timestamp?;
    final y = b.data()['createdAt'] as Timestamp?;
    if (x == null) return -1;
    if (y == null) return 1;
    return y.compareTo(x);
  });
  return l;
}

Widget loader() =>
    const Scaffold(body: Center(child: CircularProgressIndicator()));
