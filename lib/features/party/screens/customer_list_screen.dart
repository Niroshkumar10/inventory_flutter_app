import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';
import 'add_edit_customer_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final String userMobile;
  
  const CustomerListScreen({super.key, required this.userMobile});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  late final CustomerService _customerService;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _customerService = CustomerService(widget.userMobile);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Open Google Maps navigation ─────────────────────────────────────────
  Future<void> _navigateToCustomer(Customer customer) async {
    final lat = customer.latitude!;
    final lng = customer.longitude!;
    final label = Uri.encodeComponent(customer.name);

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
  void _showMapPreview(Customer customer) {
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
                              colorScheme.primary,
                              colorScheme.primary.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            customer.name[0].toUpperCase(),
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
                              customer.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (customer.locationAddress != null &&
                                customer.locationAddress!.isNotEmpty)
                              Text(
                                customer.locationAddress!,
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
                    target: LatLng(customer.latitude!, customer.longitude!),
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
                      position: LatLng(customer.latitude!, customer.longitude!),
                      infoWindow: InfoWindow(title: customer.name),
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
                        _openInGoogleMaps(customer);
                      },
                      icon: Icon(Icons.open_in_new,
                          size: 16, color: colorScheme.primary),
                      label: Text(
                        'Open in Maps',
                        style: TextStyle(color: colorScheme.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: colorScheme.primary),
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
                        _navigateToCustomer(customer);
                      },
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
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
  Future<void> _openInGoogleMaps(Customer customer) async {
    final lat = customer.latitude!;
    final lng = customer.longitude!;
    final label = Uri.encodeComponent(customer.name);
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
      backgroundColor: isDark ? colorScheme.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          'Customers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
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
        backgroundColor: colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Customer',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () => _openCustomerModal(),
      ),

      body: Column(
        children: [
          // ── Search + stats bar ────────────────────────────────────────
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Stats Row - Now shows Total and With Location
                StreamBuilder<List<Customer>>(
                  stream: _customerService.getCustomers(),
                  builder: (context, snapshot) {
                    final totalCustomers = snapshot.data?.length ?? 0;
                    final withLocation = snapshot.data
                            ?.where((c) => c.hasLocation)
                            .length ??
                        0;
                    return Row(
                      children: [
                        _buildStatCard('Total', totalCustomers.toString(),
                            Icons.people, colorScheme.secondary),
                        const SizedBox(width: 10),
                        _buildStatCard('With Location', withLocation.toString(),
                            Icons.location_on, colorScheme.primary),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Search Field
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search by name, mobile, or address',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.5)),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: colorScheme.onSurface.withOpacity(0.5)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _search = value.toLowerCase());
                  },
                ),
              ],
            ),
          ),

          // Customers List/Grid
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: _customerService.getCustomers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                }
                
                if (snapshot.hasError) {
                  return _errorState();
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _emptyState();
                }

                // Filter customers by search
                final customers = snapshot.data!
                    .where((c) =>
                        c.name.toLowerCase().contains(_search) ||
                        c.mobile.contains(_search) ||
                        c.address.toLowerCase().contains(_search))
                    .toList();

                if (customers.isEmpty) {
                  return _emptyState(search: _search);
                }

                // Sort customers by name
                customers.sort((a, b) => a.name.compareTo(b.name));

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.surface,
                  child: _isGridView
                      ? _buildGridView(customers)
                      : _buildListView(customers),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat card ────────────────────────────────────────────────────────────
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2), width: 1),
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

  Widget _buildListView(List<Customer> customers) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        return _customerCard(customers[index]);
      },
    );
  }

  Widget _buildGridView(List<Customer> customers) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        return _customerGridCard(customers[index]);
      },
    );
  }

  // ─── List card ────────────────────────────────────────────────────────────
  Widget _customerCard(Customer customer) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 4 : 2,
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCustomerModal(customer: customer),
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
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          customer.name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),

    const SizedBox(width: 12),

    // ✅ ALL CONTENT HERE
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customer.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 3),
          _infoRow(Icons.phone, customer.mobile, colorScheme),

          if (customer.address.isNotEmpty)
            _infoRow(Icons.location_on, customer.address, colorScheme),

          // Location badge
          if (customer.hasLocation) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on,
                      size: 11, color: colorScheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    'Location saved',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ✅🔥 ACTION ICON GRID (BOTTOM)
          const SizedBox(height: 8),

          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (customer.hasLocation) ...[
                _actionIconBtn(
                  icon: Icons.navigation,
                  color: colorScheme.primary,
                  tooltip: 'Navigate',
                  onTap: () => _navigateToCustomer(customer),
                ),

                _actionIconBtn(
                  icon: Icons.location_on,
                  color: colorScheme.primary,
                  tooltip: 'View on map',
                  onTap: () => _showMapPreview(customer),
                ),
              ],

              _actionIconBtn(
                icon: Icons.edit,
                color: colorScheme.primary,
                tooltip: 'Edit',
                onTap: () => _openCustomerModal(customer: customer),
              ),

              _actionIconBtn(
                icon: Icons.delete,
                color: colorScheme.error,
                tooltip: 'Delete',
                onTap: () => _confirmDelete(customer),
              ),
            ],
          ),
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
  Widget _customerGridCard(Customer customer) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isDark ? 4 : 2,
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCustomerModal(customer: customer),
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
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    customer.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                customer.name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                customer.mobile,
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              if (customer.hasLocation) ...[
                const SizedBox(height: 5),
                Icon(Icons.location_on, size: 13, color: colorScheme.primary),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (customer.hasLocation) ...[
                    _gridActionBtn(
                      icon: Icons.navigation,
                      color: colorScheme.primary,
                      onTap: () => _navigateToCustomer(customer),
                    ),
                    const SizedBox(width: 6),
                    _gridActionBtn(
                      icon: Icons.map_outlined,
                      color: colorScheme.primary,
                      onTap: () => _showMapPreview(customer),
                    ),
                    const SizedBox(width: 6),
                  ],
                  _gridActionBtn(
                    icon: Icons.edit,
                    color: colorScheme.primary,
                    onTap: () => _openCustomerModal(customer: customer),
                  ),
                  const SizedBox(width: 6),
                  _gridActionBtn(
                    icon: Icons.delete,
                    color: colorScheme.error,
                    onTap: () => _confirmDelete(customer),
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
  void _openCustomerModal({Customer? customer}) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AddEditCustomerScreen(
          userMobile: widget.userMobile,
          customer: customer,
        ),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  // ─── Delete confirmation ──────────────────────────────────────────────────
  void _confirmDelete(Customer customer) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Delete Customer',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${customer.name}"?',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12, 
                color: colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await _customerService.deleteCustomer(customer.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${customer.name} deleted successfully'),
                      backgroundColor: colorScheme.secondary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
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
          Text('Error loading customers',
              style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                search.isEmpty ? Icons.person_add : Icons.search_off,
                size: 64,
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              search.isEmpty ? 'No Customers Yet' : 'No Results Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              search.isEmpty
                  ? 'Start by adding your first customer'
                  : 'No customers match "$search"',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (search.isEmpty)
              ElevatedButton.icon(
                onPressed: () => _openCustomerModal(),
                icon: const Icon(Icons.add),
                label: const Text('Add Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
                icon: Icon(Icons.clear, color: colorScheme.primary),
                label: Text(
                  'Clear Search',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}