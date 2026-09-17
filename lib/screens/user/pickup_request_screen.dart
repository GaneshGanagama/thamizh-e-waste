// lib/screens/user/pickup_request_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/pickup_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/notification_service.dart';
import '../../services/location_service.dart';
import '../../routes/app_routes.dart';

class PickupRequestScreen extends StatefulWidget {
  const PickupRequestScreen({super.key});
  @override
  State<PickupRequestScreen> createState() => _PickupRequestScreenState();
}

class _PickupRequestScreenState extends State<PickupRequestScreen> {
  final _houseCtrl    = TextEditingController();
  final _areaCtrl     = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _pinCtrl      = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _mapLinkCtrl  = TextEditingController();
  final _pageCtrl     = PageController();

  final _pickupService   = PickupService();
  final _locationService = LocationService();

  List<Map<String, dynamic>> scrapPrices = [];
  List<Map<String, dynamic>> items = [
    {'wasteType': null, 'weight': '', 'reward': 0.0}
  ];
  double totalReward = 0.0;

  Map<String, dynamic>? _capturedGps;
  bool _isLocating = false;

  DateTime?  _scheduledDate;
  TimeOfDay? _scheduledTime;
  String _priority = 'Normal';

  Uint8List? imageBytes;
  XFile?     pickedImage;
  bool   _isUploading   = false;
  double _uploadProgress = 0.0;

  bool _loadingPrices = true;
  bool _submitting    = false;
  int  _step          = 0;

  @override
  void initState() {
    super.initState();
    _loadScrapPrices();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber?.isNotEmpty == true) {
      _phoneCtrl.text = user!.phoneNumber!;
    }
  }

  @override
  void dispose() {
    for (final c in [_houseCtrl,_areaCtrl,_cityCtrl,_pinCtrl,_landmarkCtrl,
                     _phoneCtrl,_notesCtrl,_mapLinkCtrl]) { c.dispose(); }
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadScrapPrices() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('scrap_prices').get();
      if (mounted) setState(() {
        scrapPrices = snap.docs.map((d) => d.data()).toList();
        _loadingPrices = false;
      });
    } catch (e) {
      _showSnack('Could not load prices: $e');
      if (mounted) setState(() => _loadingPrices = false);
    }
  }

  double _calcReward(String type, double weight) {
    final m = scrapPrices.firstWhere((p) => p['wasteType'] == type, orElse: () => {});
    if (m.isEmpty) return 0.0;
    final avg = ((m['minPrice'] ?? 0).toDouble() + (m['maxPrice'] ?? 0).toDouble()) / 2;
    return avg * weight;
  }

  void _updateRewards() {
    double sum = 0;
    for (final item in items) {
      if (item['wasteType'] != null && item['weight'].toString().isNotEmpty) {
        final w = double.tryParse(item['weight'].toString()) ?? 0;
        item['reward'] = _calcReward(item['wasteType'], w);
        sum += item['reward'] as double;
      } else {
        item['reward'] = 0.0;
      }
    }
    setState(() => totalReward = sum);
  }

  Future<void> _autoFillGps() async {
    setState(() => _isLocating = true);
    try {
      final ok = await _locationService.ensurePermission();
      if (!ok) { _showSnack('Location permission denied — type address manually.'); return; }
      final loc = await _locationService.captureLocation();
      if (loc == null) { _showSnack('GPS failed — type address manually.'); return; }
      setState(() {
        _capturedGps = loc;
        if (_areaCtrl.text.isEmpty) _areaCtrl.text = loc['readable'] ?? '';
        _mapLinkCtrl.text = loc['mapLink'] ?? '';
      });
      _showSnack('GPS captured! Edit address fields if needed.');
    } catch (e) {
      _showSnack('GPS error — type address manually.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() { pickedImage = file; imageBytes = bytes; });
  }

  Future<String?> _uploadImage(Uint8List bytes) async {
    try {
      setState(() { _isUploading = true; _uploadProgress = 0.2; });
      final url = await CloudinaryService.uploadImage(
        bytes,
        folder: 'ecomeel/pickups',
      );
      setState(() { _uploadProgress = 1.0; _isUploading = false; });
      if (url == null) _showSnack('Image upload failed — continuing without image.');
      return url;
    } catch (e) {
      _showSnack('Image upload error: $e');
      setState(() => _isUploading = false);
      return null;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now, lastDate: now.add(const Duration(days: 30)));
    if (d != null) setState(() => _scheduledDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t != null) setState(() => _scheduledTime = t);
  }

  String? _validateStep(int step) {
    if (step == 0) {
      final valid = items.where((it) => it['wasteType'] != null).toList();
      if (valid.isEmpty) return 'Add at least one waste item.';
      for (final it in valid) {
        final w = double.tryParse(it['weight'].toString()) ?? 0;
        if (w <= 0) return 'Enter weight (kg) for every selected item.';
      }
    }
    if (step == 1) {
      if (_houseCtrl.text.trim().isEmpty) return 'Enter house / building name.';
      if (_areaCtrl.text.trim().isEmpty)  return 'Enter area / street.';
      if (_cityCtrl.text.trim().isEmpty)  return 'Enter city / village.';
      if (_phoneCtrl.text.trim().isEmpty) return 'Enter contact phone number.';
    }
    return null;
  }

  void _goToStep(int s) {
    if (s > _step) {
      final err = _validateStep(_step);
      if (err != null) { _showSnack(err); return; }
    }
    setState(() => _step = s);
    _pageCtrl.animateToPage(s,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _submitRequest() async {
    for (int i = 0; i <= 1; i++) {
      final e = _validateStep(i);
      if (e != null) { _showSnack(e); _goToStep(i); return; }
    }
    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      String imageUrl = '';
      if (imageBytes != null) imageUrl = await _uploadImage(imageBytes!) ?? '';

      final user = FirebaseAuth.instance.currentUser!;
      final addr = {
        'house':    _houseCtrl.text.trim(),
        'area':     _areaCtrl.text.trim(),
        'city':     _cityCtrl.text.trim(),
        'pincode':  _pinCtrl.text.trim(),
        'landmark': _landmarkCtrl.text.trim(),
        'readable': [_houseCtrl.text.trim(), _areaCtrl.text.trim(),
                     _cityCtrl.text.trim(), _pinCtrl.text.trim()]
            .where((s) => s.isNotEmpty).join(', '),
      };

      final location = _capturedGps != null
          ? { 'latitude': _capturedGps!['latitude'], 'longitude': _capturedGps!['longitude'],
              'readable': _capturedGps!['readable'], 'mapLink': _capturedGps!['mapLink'] }
          : _mapLinkCtrl.text.trim().isNotEmpty
              ? { 'mapLink': _mapLinkCtrl.text.trim(), 'readable': addr['readable'] }
              : null;

      String? scheduledAt;
      if (_scheduledDate != null) {
        final d = _scheduledDate!; final t = _scheduledTime;
        scheduledAt = t != null
            ? '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(t.hour)}:${_p(t.minute)}'
            : '${d.year}-${_p(d.month)}-${_p(d.day)}';
      }

      final data = {
        'userId':       user.uid,
        'userName':     user.displayName ?? '',
        'userEmail':    user.email ?? '',
        'contactPhone': _phoneCtrl.text.trim(),
        'address':      addr,
        'location':     location,
        'items': items.where((it) => it['wasteType'] != null).map((it) => {
          'wasteType': it['wasteType'],
          'weight':    double.tryParse(it['weight'].toString()) ?? 0,
          'reward':    it['reward'] ?? 0.0,
        }).toList(),
        'totalReward':  totalReward,
        'imageUrl':     imageUrl,
        'status':       'Pending',
        'priority':     _priority,
        'scheduledAt':  scheduledAt,
        'notes':        _notesCtrl.text.trim(),
        'timestamp':    FieldValue.serverTimestamp(),
        'device':       kIsWeb ? 'web' : 'mobile',
      };

      final err = await _pickupService.createPickupRequest(data);
      if (err != null) { _showSnack('Submit failed: $err'); return; }

      // Notify admin of new pickup (in-app notification)
      await NotificationService.notifyAdminNewPickup(
        requestId: user.uid + DateTime.now().millisecondsSinceEpoch.toString(),
        userName: user.displayName ?? user.email ?? 'User',
        address: addr['readable'] ?? '',
        totalReward: totalReward,
      );

      // NOTE: points are no longer granted here. They're credited by the
      // admin panel (requests_tab.dart) only when a pickup is confirmed
      // "Completed" — granting them on submit let users farm points with
      // fake/never-collected requests.

      if (mounted) _showSuccessSheet();
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Pickup Request'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row('Items', '${items.where((i) => i['wasteType'] != null).length} item(s)'),
          _row('Reward', '₹${totalReward.toStringAsFixed(0)}'),
          _row('Address', '${_houseCtrl.text}, ${_areaCtrl.text}, ${_cityCtrl.text}'),
          _row('Phone', _phoneCtrl.text),
          if (_priority == 'Urgent') _row('Priority', '🔴 Urgent'),
          if (_scheduledDate != null) _row('Schedule',
              '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
              '${_scheduledTime != null ? "  ${_scheduledTime!.format(context)}" : ""}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Edit')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context, isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 12),
          const Text('Request Submitted!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('You\'ll earn +50 points once pickup is completed.\nEstimated reward: ₹${totalReward.toStringAsFixed(0)}',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () { Navigator.pop(context); _resetForm(); },
              child: const Text('New Request'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
              onPressed: () { Navigator.pop(context); Navigator.pushNamed(context, AppRoutes.track); },
              child: const Text('Track'))),
          ]),
        ]),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      items = [{'wasteType': null, 'weight': '', 'reward': 0.0}];
      totalReward = 0; imageBytes = null; pickedImage = null;
      _capturedGps = null; _scheduledDate = null; _scheduledTime = null;
      _priority = 'Normal'; _uploadProgress = 0; _step = 0;
    });
    for (final c in [_houseCtrl,_areaCtrl,_cityCtrl,_pinCtrl,
                     _landmarkCtrl,_notesCtrl,_mapLinkCtrl]) { c.clear(); }
    _pageCtrl.jumpToPage(0);
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ════════════════════════════════ BUILD ════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Request E-Waste Pickup'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loadingPrices
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _buildStepBar(),
              Expanded(child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildStep0(), _buildStep1(), _buildStep2()],
              )),
              _buildBottomNav(),
            ]),
    );
  }

  // ── Step bar ───────────────────────────────────────────────────────────────
  Widget _buildStepBar() {
    const labels = ['Items', 'Address', 'Details'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(children: List.generate(3, (i) {
        final done = i < _step; final active = i == _step;
        return Expanded(child: Row(children: [
          if (i > 0) Expanded(child: Container(height: 2,
              color: done ? Colors.green[700] : Colors.grey[300])),
          Column(children: [
            CircleAvatar(radius: 14,
              backgroundColor: (done || active) ? Colors.green[700] : Colors.grey[300],
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text('${i+1}', style: TextStyle(
                      color: active ? Colors.white : Colors.grey[600],
                      fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Text(labels[i], style: TextStyle(fontSize: 11,
                color: active ? Colors.green[700] : Colors.grey[500],
                fontWeight: active ? FontWeight.bold : FontWeight.normal)),
          ]),
          if (i < 2) const Expanded(child: SizedBox()),
        ]));
      })),
    );
  }

  // ── Step 0 : Items ─────────────────────────────────────────────────────────
  Widget _buildStep0() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead(Icons.recycling, 'What are you recycling?'),
      const SizedBox(height: 4),
      Text('Select each item and enter its approximate weight.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      const SizedBox(height: 16),
      ...items.asMap().entries.map((e) => _buildItemCard(e.key, e.value)),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => setState(() =>
            items.add({'wasteType': null, 'weight': '', 'reward': 0.0})),
        icon: const Icon(Icons.add),
        label: const Text('Add Another Item'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
      ),
      if (totalReward > 0) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200)),
          child: Row(children: [
            Icon(Icons.monetization_on, color: Colors.green[700]),
            const SizedBox(width: 10),
            Text('Estimated Reward: ₹${totalReward.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: Colors.green[800])),
          ]),
        ),
      ],
    ]),
  );

  Widget _buildItemCard(int i, Map<String, dynamic> item) {
    final info = item['wasteType'] != null
        ? scrapPrices.firstWhere((p) => p['wasteType'] == item['wasteType'], orElse: () => {})
        : <String, dynamic>{};
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Item ${i+1}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            if (items.length > 1) IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
              onPressed: () { setState(() => items.removeAt(i)); _updateRewards(); },
              padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: item['wasteType'],
            hint: const Text('Select waste type'),
            isExpanded: true,
            items: scrapPrices.map((p) => DropdownMenuItem<String>(
              value: p['wasteType'].toString(),
              child: Text(p['wasteType'].toString()))).toList(),
            onChanged: (val) { setState(() => item['wasteType'] = val); _updateRewards(); },
            decoration: const InputDecoration(border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextFormField(
              initialValue: item['weight'].toString().isEmpty ? '' : item['weight'].toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), suffixText: 'kg'),
              onChanged: (val) { setState(() => item['weight'] = val); _updateRewards(); },
            )),
            if (info.isNotEmpty) ...[
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${info['minPrice']}–₹${info['maxPrice']}',
                    style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.bold)),
                Text('per ${info['unit'] ?? 'kg'}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ],
          ]),
          if ((item['reward'] as double? ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Text('→ Reward: ₹${(item['reward'] as double).toStringAsFixed(0)}',
                style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
          ],
        ],
      )),
    );
  }

  // ── Step 1 : Address ───────────────────────────────────────────────────────
  Widget _buildStep1() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead(Icons.location_on, 'Pickup Address'),
      const SizedBox(height: 4),
      Text('Type your address. GPS auto-fill is optional.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      const SizedBox(height: 12),

      // GPS button
      ElevatedButton.icon(
        onPressed: _isLocating ? null : _autoFillGps,
        icon: _isLocating
            ? const SizedBox(width:16,height:16, child: CircularProgressIndicator(strokeWidth:2,color:Colors.white))
            : const Icon(Icons.my_location),
        label: Text(_isLocating ? 'Getting GPS...' : 'Auto-fill from GPS (optional)'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 46)),
      ),

      if (_capturedGps != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.check_circle, color: Colors.blue[700], size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text('GPS: ${_capturedGps!['readable']}',
                style: TextStyle(fontSize: 12, color: Colors.blue[800]))),
            GestureDetector(onTap: () => setState(() => _capturedGps = null),
                child: const Icon(Icons.close, size: 16)),
          ]),
        ),
      ],

      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 8),

      _field(_houseCtrl,    'House / Flat / Building *', Icons.home),
      const SizedBox(height: 12),
      _field(_areaCtrl,     'Area / Street / Colony *',  Icons.map_outlined),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(flex:3, child: _field(_cityCtrl, 'City / Village *', Icons.location_city)),
        const SizedBox(width: 10),
        Expanded(flex:2, child: _field(_pinCtrl, 'Pincode', Icons.pin_drop,
            type: TextInputType.number)),
      ]),
      const SizedBox(height: 12),
      _field(_landmarkCtrl, 'Landmark (optional)', Icons.place_outlined),
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 8),

      Text('Or paste a Google Maps link',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
      const SizedBox(height: 4),
      Text('Open Maps → long-press your location → Share → Copy link.',
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      const SizedBox(height: 8),
      TextField(
        controller: _mapLinkCtrl,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: 'Google Maps link (optional)',
          prefixIcon: const Icon(Icons.link),
          border: const OutlineInputBorder(),
          filled: true, fillColor: Colors.white,
          hintText: 'https://maps.google.com/...',
        ),
        onChanged: (_) => setState(() {}),
      ),

      const SizedBox(height: 16),
      _field(_phoneCtrl, 'Contact Phone *', Icons.phone, type: TextInputType.phone),
    ]),
  );

  // ── Step 2 : Details ───────────────────────────────────────────────────────
  Widget _buildStep2() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead(Icons.tune, 'Pickup Details'),
      const SizedBox(height: 16),

      Text('Preferred Pickup Date & Time (optional)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _tile(Icons.calendar_today,
          _scheduledDate != null
              ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
              : 'Pick Date',
          _pickDate, _scheduledDate != null)),
        const SizedBox(width: 10),
        Expanded(child: _tile(Icons.access_time,
          _scheduledTime != null ? _scheduledTime!.format(context) : 'Pick Time',
          _pickTime, _scheduledTime != null)),
      ]),
      if (_scheduledDate != null) TextButton.icon(
        onPressed: () => setState(() { _scheduledDate = null; _scheduledTime = null; }),
        icon: const Icon(Icons.clear, size: 14),
        label: const Text('Clear schedule'),
        style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: EdgeInsets.zero),
      ),

      const SizedBox(height: 16),
      Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
      const SizedBox(height: 8),
      Row(children: [
        _priorityBtn('Normal', Icons.schedule, Colors.grey),
        const SizedBox(width: 10),
        _priorityBtn('Urgent', Icons.priority_high, Colors.red),
      ]),

      const SizedBox(height: 16),
      Text('Photo of E-Waste (optional)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _isUploading ? null : _pickImage,
        child: Container(height: 150, width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300)),
          child: imageBytes == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.camera_alt, size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 6),
                  Text('Tap to add photo', style: TextStyle(color: Colors.grey[500])),
                ])
              : Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: Image.memory(imageBytes!, fit: BoxFit.cover,
                        width: double.infinity, height: double.infinity)),
                  Positioned(top: 6, right: 6, child: GestureDetector(
                    onTap: () => setState(() { imageBytes = null; pickedImage = null; }),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close, color: Colors.white, size: 16)),
                  )),
                ]),
        ),
      ),
      if (_isUploading) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _uploadProgress,
            color: Colors.green[700], backgroundColor: Colors.grey[200]),
      ],

      const SizedBox(height: 16),
      Text('Special Instructions (optional)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
      const SizedBox(height: 8),
      TextField(
        controller: _notesCtrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'e.g. Call before arriving, items on 2nd floor, gate code 1234...',
          border: const OutlineInputBorder(),
          filled: true, fillColor: Colors.white),
      ),
      const SizedBox(height: 32),
    ]),
  );

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: Row(children: [
      if (_step > 0) ...[
        Expanded(child: OutlinedButton(
          onPressed: () => _goToStep(_step - 1),
          child: const Text('Back'))),
        const SizedBox(width: 12),
      ],
      Expanded(flex: 2, child: ElevatedButton(
        onPressed: (_submitting || _isUploading) ? null : () {
          if (_step < 2) _goToStep(_step + 1); else _submitRequest();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700], foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: _submitting
            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 10), Text('Submitting...'),
              ])
            : Text(_step < 2 ? 'Next →' : 'Submit Request'),
      )),
    ]),
  );

  // ── Reusable widgets ───────────────────────────────────────────────────────
  Widget _sectionHead(IconData icon, String title) => Row(children: [
    Icon(icon, color: Colors.green[700], size: 20), const SizedBox(width: 8),
    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800])),
  ]);

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType type = TextInputType.text}) =>
    TextField(controller: c, keyboardType: type, decoration: InputDecoration(
      labelText: label, prefixIcon: Icon(icon),
      border: const OutlineInputBorder(), filled: true, fillColor: Colors.white));

  Widget _tile(IconData icon, String label, VoidCallback onTap, bool active) =>
    GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: active ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? Colors.green.shade400 : Colors.grey.shade300)),
      child: Row(children: [
        Icon(icon, size: 18, color: active ? Colors.green[700] : Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13,
            color: active ? Colors.green[800] : Colors.grey[700]))),
      ]),
    ));

  Widget _priorityBtn(String label, IconData icon, Color color) {
    final sel = _priority == label;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _priority = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? color : Colors.grey.shade300, width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: sel ? color : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600,
              color: sel ? color : Colors.grey[600])),
        ]),
      ),
    ));
  }
}
