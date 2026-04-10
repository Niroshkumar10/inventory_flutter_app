// lib/features/party/screens/supplier_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import 'supplier_form_modal.dart';

class SupplierListScreen extends StatefulWidget {
  final String userMobile;

  const SupplierListScreen({super.key, required this.userMobile});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  late final SupplierService _supplierService;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _supplierService = SupplierService(widget.userMobile);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Open Google Maps navigation ─────────────────────────────────────────
  Future<void> _navigateToSupplier(Supplier supplier) async {
    final lat = supplier.latitude!;
    final lng = supplier.longitude!;
    final label = Uri.encodeComponent(supplier.name);

    // Google Maps turn-by-turn navigation
    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$label';
    final uri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: open location in maps
        final fallback = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
        if (await canLaunchUrl(fallback)) {
          await launchUrl(fallback);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open Maps app'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── Show map preview bottom sheet ───────────────────────────────────────
  void _showMapPreview(Supplier supplier) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Completer<GoogleMapController> controllerCompleter = Completer();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.tertiary,
                              colorScheme.tertiary.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            supplier.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (supplier.locationAddress != null &&
                                supplier.locationAddress!.isNotEmpty)
                              Text(
                                supplier.locationAddress!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withOpacity(0.55),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: colorScheme.onSurface.withOpacity(0.6)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(supplier.latitude!, supplier.longitude!),
                    zoom: 15.0,
                  ),
                  onMapCreated: (c) {
                    if (!controllerCompleter.isCompleted) {
                      controllerCompleter.complete(c);
                    }
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('preview'),
                      position: LatLng(supplier.latitude!, supplier.longitude!),
                      infoWindow: InfoWindow(title: supplier.name),
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(
                children: [
                  // View larger map
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openInGoogleMaps(supplier);
                      },
                      icon: Icon(Icons.open_in_new,
                          size: 16, color: colorScheme.tertiary),
                      label: Text(
                        'Open in Maps',
                        style: TextStyle(color: colorScheme.tertiary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: colorScheme.tertiary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Navigate
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToSupplier(supplier);
                      },
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.tertiary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Open location in Google Maps (view only, no navigation) ─────────────
  Future<void> _openInGoogleMaps(Supplier supplier) async {
    final lat = supplier.latitude!;
    final lng = supplier.longitude!;
    final label = Uri.encodeComponent(supplier.name);
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$label');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? colorScheme.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          'Suppliers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            color: colorScheme.onSurface,
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.tertiary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Supplier',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        onPressed: () => _openSupplierModal(),
      ),

      body: Column(
        children: [
          // ── Search + stats bar ────────────────────────────────────────
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Stats
                StreamBuilder<List<Supplier>>(
                  stream: _supplierService.getSuppliers(),
                  builder: (context, snapshot) {
                    final total = snapshot.data?.length ?? 0;
                    final withLocation = snapshot.data
                            ?.where((s) => s.hasLocation)
                            .length ??
                        0;
                    return Row(
                      children: [
                        _buildStatCard('Total', total.toString(),
                            Icons.store, colorScheme.secondary),
                        const SizedBox(width: 10),
                        _buildStatCard('With Location', withLocation.toString(),
                            Icons.location_on, colorScheme.tertiary),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Search field
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or address',
                    hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search,
                        color: colorScheme.onSurface.withOpacity(0.5)),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: colorScheme.onSurface.withOpacity(0.5)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? colorScheme.surfaceContainerHighest
                        : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: colorScheme.tertiary, width: 1.5),
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ],
            ),
          ),

          // ── Supplier list / grid ──────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Supplier>>(
              stream: _supplierService.getSuppliers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: colorScheme.tertiary));
                }
                if (snapshot.hasError) {
                  return _errorState();
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _emptyState();
                }

                final suppliers = snapshot.data!
                    .where((s) =>
                        s.name.toLowerCase().contains(_search) ||
                        s.phone.contains(_search) ||
                        s.email.toLowerCase().contains(_search) ||
                        s.address.toLowerCase().contains(_search))
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

                if (suppliers.isEmpty) return _emptyState(search: _search);

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: colorScheme.tertiary,
                  child: _isGridView
                      ? _buildGridView(suppliers)
                      : _buildListView(suppliers),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat card ────────────────────────────────────────────────────────────
  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withOpacity(isDark ? 0.3 : 0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w500)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<Supplier> suppliers) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: suppliers.length,
      itemBuilder: (_, i) => _supplierCard(suppliers[i]),
    );
  }

  Widget _buildGridView(List<Supplier> suppliers) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: suppliers.length,
      itemBuilder: (_, i) => _supplierGridCard(suppliers[i]),
    );
  }

  // ─── List card ────────────────────────────────────────────────────────────
  Widget _supplierCard(Supplier supplier) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 4 : 2,
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openSupplierModal(supplier: supplier),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
       Row(
  children: [
    // Avatar
    Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.tertiary,
            colorScheme.tertiary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          supplier.name[0].toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
      ),
    ),

    const SizedBox(width: 12),

    // ✅ ALL CONTENT INSIDE THIS COLUMN
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supplier.name,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface),
          ),

          const SizedBox(height: 3),
          _infoRow(Icons.phone, supplier.phone, colorScheme),

          if (supplier.email.isNotEmpty)
            _infoRow(Icons.email, supplier.email, colorScheme),

          if (supplier.address.isNotEmpty)
            _infoRow(Icons.location_on, supplier.address, colorScheme),

          // Location badge
          if (supplier.hasLocation) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on,
                      size: 11, color: colorScheme.tertiary),
                  const SizedBox(width: 3),
                  Text(
                    'Location saved',
                    style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],

          // ✅🔥 THIS IS THE IMPORTANT PART
          const SizedBox(height: 8),

      Wrap(
  spacing: 12, // horizontal space
  runSpacing: 8, // vertical space (if it wraps)
  alignment: WrapAlignment.spaceBetween,
  children: [
    if (supplier.hasLocation) ...[
      _actionIconBtn(
        icon: Icons.navigation,
        color: colorScheme.tertiary,
        tooltip: 'Navigate',
        onTap: () => _navigateToSupplier(supplier),
      ),

      _actionIconBtn(
        icon: Icons.location_on,
        color: colorScheme.primary,
        tooltip: 'View on map',
        onTap: () => _showMapPreview(supplier),
      ),
    ],

    _actionIconBtn(
      icon: Icons.edit,
      color: colorScheme.primary,
      tooltip: 'Edit',
      onTap: () => _openSupplierModal(supplier: supplier),
    ),

    _actionIconBtn(
      icon: Icons.delete,
      color: colorScheme.error,
      tooltip: 'Delete',
      onTap: () => _confirmDelete(supplier),
    ),
  ],
)
        ],
      ),
    ),
  ],
)
        ),
      ),
    );
  }


  Widget _infoRow(IconData icon, String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: cs.onSurface.withOpacity(0.45)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 11, color: cs.onSurface.withOpacity(0.6)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      onPressed: onTap,
      tooltip: tooltip,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(5),
    );
  }

  // ─── Grid card ────────────────────────────────────────────────────────────
  Widget _supplierGridCard(Supplier supplier) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isDark ? 4 : 2,
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openSupplierModal(supplier: supplier),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.tertiary,
                      colorScheme.tertiary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    supplier.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                supplier.name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                supplier.phone,
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              if (supplier.hasLocation) ...[
                const SizedBox(height: 5),
                Icon(Icons.location_on, size: 13, color: colorScheme.tertiary),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (supplier.hasLocation) ...[
                    _gridActionBtn(
                      icon: Icons.navigation,
                      color: colorScheme.tertiary,
                      onTap: () => _navigateToSupplier(supplier),
                    ),
                    const SizedBox(width: 6),
                    _gridActionBtn(
                      icon: Icons.map_outlined,
                      color: colorScheme.primary,
                      onTap: () => _showMapPreview(supplier),
                    ),
                    const SizedBox(width: 6),
                  ],
                  _gridActionBtn(
                    icon: Icons.edit,
                    color: colorScheme.primary,
                    onTap: () => _openSupplierModal(supplier: supplier),
                  ),
                  const SizedBox(width: 6),
                  _gridActionBtn(
                    icon: Icons.delete,
                    color: colorScheme.error,
                    onTap: () => _confirmDelete(supplier),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridActionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }

  // ─── Open add/edit modal ──────────────────────────────────────────────────
  void _openSupplierModal({Supplier? supplier}) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SupplierFormModal(
          userMobile: widget.userMobile,
          supplier: supplier,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  // ─── Delete confirmation ──────────────────────────────────────────────────
  void _confirmDelete(Supplier supplier) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('Delete Supplier',
            style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${supplier.name}"?',
                style: TextStyle(color: colorScheme.onSurface)),
            const SizedBox(height: 6),
            Text('This action cannot be undone.',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.55))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: colorScheme.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await _supplierService.deleteSupplier(supplier.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${supplier.name} deleted'),
                      backgroundColor: colorScheme.secondary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────
  Widget _errorState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 12),
          Text('Error loading suppliers',
              style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.tertiary,
                foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _emptyState({String search = ''}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                search.isEmpty ? Icons.store : Icons.search_off,
                size: 64,
                color: colorScheme.tertiary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              search.isEmpty ? 'No Suppliers Yet' : 'No Results Found',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              search.isEmpty
                  ? 'Start by adding your first supplier'
                  : 'No suppliers match "$search"',
              style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (search.isEmpty)
              ElevatedButton.icon(
                onPressed: () => _openSupplierModal(),
                icon: const Icon(Icons.add),
                label: const Text('Add Supplier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.tertiary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
                icon: Icon(Icons.clear, color: colorScheme.tertiary),
                label: Text('Clear Search',
                    style: TextStyle(color: colorScheme.tertiary)),
              ),
          ],
        ),
      ),
    );
  }
}