// lib/screens/user/dropoff_points_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const double _kRadiusKm    = 50.0;  // show only within this radius
const double _kNearbyKm    = 5.0;   // "very close" badge threshold

class DropoffPointsScreen extends StatefulWidget {
  const DropoffPointsScreen({super.key});
  @override
  State<DropoffPointsScreen> createState() => _DropoffPointsScreenState();
}

class _DropoffPointsScreenState extends State<DropoffPointsScreen> {
  Position? _userPos;
  bool _locating = true;

  // radius slider value (user can expand search)
  double _radiusKm = _kRadiusKm;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // ── Full permission-safe location fetch ───────────────────────────────────
  Future<void> _getUserLocation() async {
    setState(() => _locating = true);
    try {
      if (!kIsWeb) {
        final on = await Geolocator.isLocationServiceEnabled();
        if (!on) {
          _snack('Location services are off on your device.');
          if (mounted) setState(() => _locating = false);
          return;
        }
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Location permission denied — distances will not be shown.');
        if (mounted) setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() { _userPos = pos; _locating = false; });
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Distance helpers ──────────────────────────────────────────────────────
  double _km(dynamic rawLat, dynamic rawLng) {
    if (_userPos == null) return double.maxFinite;
    try {
      final lat = (rawLat as num).toDouble();
      final lng = (rawLng as num).toDouble();
      if (lat == 0.0 && lng == 0.0) return double.maxFinite;
      return Geolocator.distanceBetween(
              _userPos!.latitude, _userPos!.longitude, lat, lng) /
          1000;
    } catch (_) {
      return double.maxFinite;
    }
  }

  String _distLabel(double km) {
    if (km == double.maxFinite) return '';
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
    return '${km.toStringAsFixed(1)} km';
  }

  // ── Launch helpers ────────────────────────────────────────────────────────
  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: phone));
      _snack('Phone copied: $phone');
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _mapCoords(double lat, double lng, String label) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank');
  }

  Future<void> _mapAddress(String address) async {
    if (address.isEmpty) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    await launchUrl(uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Drop-Off Points'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            icon: _locating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(
                    _userPos != null
                        ? Icons.my_location
                        : Icons.location_off,
                    color: Colors.white),
            onPressed: _locating ? null : _getUserLocation,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _getUserLocation(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Location banner ─────────────────────────────────────────
              _locationBanner(),

              // ── Radius control (only when GPS is on) ────────────────────
              if (!_locating && _userPos != null) _radiusControl(),

              const SizedBox(height: 4),

              // ── Vendors ──────────────────────────────────────────────────
              _sectionHead(Icons.store_mall_directory_outlined,
                  'Registered Vendors',
                  'Approved recycling partners near you'),
              _buildVendors(),

              const SizedBox(height: 12),

              // ── Admin drop-off points ─────────────────────────────────────
              _sectionHead(Icons.location_on_outlined,
                  'Designated Drop-off Points',
                  'Fixed collection points added by our team'),
              _buildDropoffs(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Location banner ────────────────────────────────────────────────────────
  Widget _locationBanner() {
    if (_locating) {
      return _banner(Colors.blue[50]!, Colors.blue[700]!,
          Icons.location_searching, 'Getting your location…');
    }
    if (_userPos == null) {
      return _banner(Colors.orange[50]!, Colors.orange[700]!,
          Icons.location_off,
          'Location unavailable — distances hidden. Tap ⟳ to retry.');
    }
    return _banner(Colors.green[50]!, Colors.green[700]!, Icons.my_location,
        'Showing places within ${_radiusKm.toStringAsFixed(0)} km of you, sorted by distance.');
  }

  Widget _banner(Color bg, Color fg, IconData icon, String msg) =>
      Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg, style: TextStyle(fontSize: 13, color: fg))),
        ]),
      );

  // ── Radius slider ──────────────────────────────────────────────────────────
  Widget _radiusControl() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(Icons.radar, color: Colors.green[700], size: 18),
        const SizedBox(width: 8),
        Text('Search radius: ',
            style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Text('${_radiusKm.toStringAsFixed(0)} km',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green[700])),
        Expanded(
          child: Slider(
            value: _radiusKm,
            min: 5,
            max: 200,
            divisions: 39,
            activeColor: Colors.green[700],
            onChanged: (v) => setState(() => _radiusKm = v),
          ),
        ),
      ]),
    );
  }

  Widget _sectionHead(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.green[700], size: 22),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: Colors.grey[800])),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      )),
    ]),
  );

  // ── Vendors list ───────────────────────────────────────────────────────────
  Widget _buildVendors() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendors')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _emptyMsg('Could not load vendors.');
        }

        final all = snap.data?.docs ?? [];

        // ── Filter & sort ─────────────────────────────────────────────────
        final withDist = all.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return _Located(doc: d, data: data,
              km: _km(data['latitude'], data['longitude']));
        }).toList()
          ..sort((a, b) => a.km.compareTo(b.km));

        // Within radius
        final nearby = withDist.where((e) => e.km <= _radiusKm).toList();
        // Outside radius but still have coords (show as fallback if nearby empty)
        final outside = withDist.where((e) =>
            e.km > _radiusKm && e.km != double.maxFinite).toList();
        // No coords at all
        final noCoords = withDist.where((e) =>
            e.km == double.maxFinite).toList();

        if (all.isEmpty) {
          return _emptyMsg('No approved vendors yet.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nearby.isEmpty && _userPos != null) ...[
              _noneNearbyBanner('vendor', outside),
            ],
            // Show nearby first
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: nearby.length,
              itemBuilder: (_, i) => _vendorCard(nearby[i]),
            ),
            // If no GPS, show all
            if (_userPos == null)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: withDist.length,
                itemBuilder: (_, i) => _vendorCard(withDist[i]),
              ),
            // Show no-coords vendors at the bottom always
            if (noCoords.isNotEmpty && _userPos != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Other vendors (no location data)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: noCoords.length,
                itemBuilder: (_, i) => _vendorCard(noCoords[i]),
              ),
            ],
          ],
        );
      },
    );
  }

  // ── Admin drop-off list ────────────────────────────────────────────────────
  Widget _buildDropoffs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dropoffs')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) return _emptyMsg('Could not load drop-off points.');

        final all = snap.data?.docs ?? [];
        if (all.isEmpty) return _emptyMsg('No drop-off points added yet.');

        final withDist = all.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return _Located(doc: d, data: data,
              km: _km(data['latitude'], data['longitude']));
        }).toList()
          ..sort((a, b) => a.km.compareTo(b.km));

        final nearby  = withDist.where((e) => e.km <= _radiusKm).toList();
        final outside = withDist.where((e) =>
            e.km > _radiusKm && e.km != double.maxFinite).toList();
        final noCoords = withDist.where((e) =>
            e.km == double.maxFinite).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nearby.isEmpty && _userPos != null)
              _noneNearbyBanner('drop-off point', outside),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: nearby.length,
              itemBuilder: (_, i) => _dropoffCard(nearby[i]),
            ),
            if (_userPos == null)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: withDist.length,
                itemBuilder: (_, i) => _dropoffCard(withDist[i]),
              ),
            if (noCoords.isNotEmpty && _userPos != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Other drop-off points (no location data)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: noCoords.length,
                itemBuilder: (_, i) => _dropoffCard(noCoords[i]),
              ),
            ],
          ],
        );
      },
    );
  }

  // ── "None nearby" banner with closest suggestion ──────────────────────────
  Widget _noneNearbyBanner(String type, List<_Located> outside) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.search_off, color: Colors.amber[700], size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'No $type within ${_radiusKm.toStringAsFixed(0)} km.',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[800], fontSize: 13),
            )),
          ]),
          if (outside.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Nearest is ${_distLabel(outside.first.km)} away — '
              'drag the radius slider above to include it.',
              style: TextStyle(fontSize: 12, color: Colors.amber[700]),
            ),
            const SizedBox(height: 8),
            // Show the single nearest as a preview card
            _nearestPreview(outside.first, type == 'vendor'),
          ] else ...[
            const SizedBox(height: 4),
            Text('No locations with GPS coordinates in the database yet.',
                style: TextStyle(fontSize: 12, color: Colors.amber[700])),
          ],
        ],
      ),
    );
  }

  // ── Compact preview of the nearest out-of-range item ─────────────────────
  Widget _nearestPreview(_Located loc, bool isVendor) {
    final name = isVendor
        ? (loc.data['shopName'] ?? 'Vendor').toString()
        : (loc.data['area'] ?? 'Drop-off Point').toString();
    final address = (loc.data['address'] ?? '').toString();
    final lat = loc.data['latitude'];
    final lng = loc.data['longitude'];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(children: [
        Icon(isVendor ? Icons.store : Icons.location_on,
            color: Colors.amber[600], size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
            if (address.isNotEmpty)
              Text(address, style: TextStyle(
                  fontSize: 12, color: Colors.grey[600])),
            Text(_distLabel(loc.km),
                style: TextStyle(
                    fontSize: 12, color: Colors.amber[700],
                    fontWeight: FontWeight.w600)),
          ],
        )),
        TextButton(
          onPressed: () {
            if (lat != null && lng != null) {
              _mapCoords((lat as num).toDouble(),
                  (lng as num).toDouble(), name);
            } else {
              _mapAddress(address);
            }
          },
          child: const Text('Maps', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  // ── Vendor card ────────────────────────────────────────────────────────────
  Widget _vendorCard(_Located loc) {
    final data    = loc.data;
    final name    = (data['shopName'] ?? 'Vendor').toString();
    final address = (data['address']  ?? '').toString();
    final area    = (data['serviceArea'] ?? '').toString();
    final phone   = (data['phone']    ?? '').toString();
    final lat     = data['latitude'];
    final lng     = data['longitude'];
    final hasCoords = lat != null && lng != null &&
        (lat as num) != 0 && (lng as num) != 0;
    final dist    = loc.km;
    final isVeryClose = dist < _kNearbyKm && dist != double.maxFinite;

    return _locationCard(
      icon: Icons.store,
      iconColor: Colors.blue[700]!,
      title: name,
      subtitle: address,
      extra: area.isNotEmpty ? 'Serves: $area' : null,
      distKm: dist,
      isVeryClose: isVeryClose,
      phone: phone,
      onMap: hasCoords
          ? () => _mapCoords((lat as num).toDouble(),
              (lng as num).toDouble(), name)
          : address.isNotEmpty ? () => _mapAddress(address) : null,
      hasRealCoords: hasCoords,
    );
  }

  // ── Drop-off card ──────────────────────────────────────────────────────────
  Widget _dropoffCard(_Located loc) {
    final data    = loc.data;
    final area    = (data['area']    ?? 'Drop-off Point').toString();
    final address = (data['address'] ?? '').toString();
    final phone   = (data['contact'] ?? '').toString();
    final lat     = data['latitude'];
    final lng     = data['longitude'];
    final hasCoords = lat != null && lng != null &&
        (lat as num) != 0 && (lng as num) != 0;
    final dist    = loc.km;
    final isVeryClose = dist < _kNearbyKm && dist != double.maxFinite;

    // Show coords if available
    String? coordStr;
    if (hasCoords) {
      coordStr = '${(lat as num).toStringAsFixed(5)}, '
          '${(lng as num).toStringAsFixed(5)}';
    }

    return _locationCard(
      icon: Icons.location_on,
      iconColor: Colors.red[400]!,
      title: area,
      subtitle: address,
      extra: coordStr != null ? '📍 $coordStr' : null,
      distKm: dist,
      isVeryClose: isVeryClose,
      phone: phone,
      onMap: hasCoords
          ? () => _mapCoords((lat as num).toDouble(),
              (lng as num).toDouble(), area)
          : address.isNotEmpty ? () => _mapAddress(address) : null,
      hasRealCoords: hasCoords,
    );
  }

  // ── Shared card widget ─────────────────────────────────────────────────────
  Widget _locationCard({
    required IconData icon,
    required Color    iconColor,
    required String   title,
    required String   subtitle,
    String?           extra,
    required double   distKm,
    required bool     isVeryClose,
    required String   phone,
    VoidCallback?     onMap,
    required bool     hasRealCoords,
  }) {
    final distStr = _distLabel(distKm);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15))),
              // Distance badge
              if (distStr.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVeryClose
                        ? Colors.green[100]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isVeryClose
                            ? Colors.green.shade400
                            : Colors.grey.shade300),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isVeryClose)
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(Icons.near_me,
                            size: 11, color: Colors.green[700]),
                      ),
                    Text(distStr,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isVeryClose
                                ? Colors.green[800]
                                : Colors.grey[700])),
                  ]),
                ),
            ]),

            // ── Details ───────────────────────────────────────────────────
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const SizedBox(width: 34),
                Icon(Icons.place_outlined,
                    size: 13, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Expanded(child: Text(subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
              ]),
            ],
            if (extra != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const SizedBox(width: 34),
                Expanded(child: Text(extra,
                    style: TextStyle(fontSize: 11,
                        color: Colors.grey[500],
                        fontFamily: extra.startsWith('📍')
                            ? 'monospace' : null))),
              ]),
            ],

            const SizedBox(height: 10),

            // ── Action buttons ────────────────────────────────────────────
            Row(children: [
              if (phone.isNotEmpty) ...[
                _btn(Icons.phone, 'Call', Colors.green,
                    () => _call(phone)),
                const SizedBox(width: 8),
              ],
              if (onMap != null)
                _btn(
                  hasRealCoords ? Icons.directions : Icons.search,
                  hasRealCoords ? 'Directions' : 'Search on Map',
                  Colors.blue,
                  onMap,
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String label, Color color, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: color),
        label: Text(label, style: TextStyle(fontSize: 12, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );

  Widget _emptyMsg(String msg) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    child: Row(children: [
      Icon(Icons.info_outline, color: Colors.grey[400], size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg,
          style: TextStyle(color: Colors.grey[500], fontSize: 13))),
    ]),
  );
}

// ── Simple data holder ─────────────────────────────────────────────────────
class _Located {
  final DocumentSnapshot       doc;
  final Map<String, dynamic>   data;
  final double                 km;
  const _Located({required this.doc, required this.data, required this.km});
}
