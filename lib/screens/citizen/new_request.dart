import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../common.dart';

class NewRequestPage extends StatefulWidget {
  const NewRequestPage({super.key});
  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends State<NewRequestPage> {
  LatLng _pin = const LatLng(defaultLat, defaultLng);
  GoogleMapController? _map;
  String _type = wasteTypes.first, _slot = timeSlots.first;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  final _addr = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = ll);
      _map?.animateCamera(CameraUpdate.newLatLngZoom(ll, 16));
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 60)));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await db.collection('requests').add({
        'userId': uid,
        'wasteType': _type,
        'timeSlot': _slot,
        'scheduledDate':
            Timestamp.fromDate(DateTime(_date.year, _date.month, _date.day)),
        'location': GeoPoint(_pin.latitude, _pin.longitude),
        'address': _addr.text.trim(),
        'status': 'pending',
        'driverId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        snack(context, 'Pickup requested');
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
      appBar: AppBar(title: const Text('New pickup request')),
      body: Column(children: [
        SizedBox(
          height: 260,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _pin, zoom: 14),
            onMapCreated: (c) => _map = c,
            myLocationEnabled: true,
            onTap: (p) => setState(() => _pin = p),
            markers: {Marker(markerId: const MarkerId('pin'), position: _pin)},
          ),
        ),
        const Padding(
            padding: EdgeInsets.all(8), child: Text('Tap the map to drop a pin')),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Waste type'),
              items: [for (final t in wasteTypes) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => _type = v!),
            ),
            DropdownButtonFormField<String>(
              value: _slot,
              decoration: const InputDecoration(labelText: 'Time slot'),
              items: [for (final t in timeSlots) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => _slot = v!),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date: ${_date.day}/${_date.month}/${_date.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            TextField(
                controller: _addr,
                decoration: const InputDecoration(labelText: 'Address / landmark')),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _busy ? null : _submit, child: const Text('Submit request')),
          ]),
        ),
      ]),
    );
  }
}
