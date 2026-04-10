// lib/features/party/screens/location_picker.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class LocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final Function(double lat, double lng, String address) onLocationSelected;

  const LocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    required this.onLocationSelected,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  // ── Map ──────────────────────────────────────────────────────────────────
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  Set<Marker> _markers = {};

  // ── Search ───────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;
  bool _isSearching = false;

  // ── Loading states ────────────────────────────────────────────────────────
  bool _isLoadingAddress = false;
  bool _isLoadingGPS = false;

  // ── Replace with your actual API key ─────────────────────────────────────
  static const String _apiKey = 'AIzaSyBIGPfna9mxSXpAJOhp0xigKhyZeeU0L0I';

  static const LatLng _indiaCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation =
          LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _selectedAddress = widget.initialAddress ?? '';
      _updateMarker(_selectedLocation!);
    }

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        // hide suggestions when focus lost
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ─── Update pin ───────────────────────────────────────────────────────────
  void _updateMarker(LatLng position) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('supplier_location'),
          position: position,
          draggable: true,
          infoWindow: InfoWindow(
            title: 'Supplier Location',
            snippet:
                _selectedAddress.isNotEmpty ? _selectedAddress : null,
          ),
          onDragEnd: (newPos) {
            _selectedLocation = newPos;
            _getAddressFromLatLng(newPos);
          },
        ),
      };
    });
  }

  // ─── Reverse geocode ──────────────────────────────────────────────────────
  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isLoadingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.postalCode,
          p.country,
        ].where((x) => x != null && x.isNotEmpty).toList();
        setState(() {
          _selectedAddress = parts.join(', ');
          _selectedLocation = position;
        });
      }
    } catch (_) {
      setState(() {
        _selectedAddress =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _selectedLocation = position;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
        _updateMarker(_selectedLocation!);
      }
    }
  }

  // ─── Places Autocomplete API ──────────────────────────────────────────────
  Future<void> _onSearchChanged(String query) async {
    _debounceTimer?.cancel();

    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$_apiKey'
          '&language=en',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            final predictions =
                data['predictions'] as List<dynamic>;
            if (mounted) {
              setState(() {
                _suggestions = predictions
                    .map((p) => {
                          'place_id': p['place_id'] as String,
                          'description':
                              p['description'] as String,
                          'main_text': p['structured_formatting']
                              ['main_text'] as String,
                          'secondary_text': (p['structured_formatting']
                                  ['secondary_text'] ??
                              '') as String,
                        })
                    .toList();
                _showSuggestions = _suggestions.isNotEmpty;
                _isSearching = false;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _suggestions = [];
                _showSuggestions = false;
                _isSearching = false;
              });
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _showSuggestions = false;
          });
        }
      }
    });
  }

  // ─── Get lat/lng from place_id ────────────────────────────────────────────
  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    // Hide keyboard and suggestions
    _searchFocusNode.unfocus();
    setState(() {
      _showSuggestions = false;
      _isSearching = true;
      _searchController.text = suggestion['description'];
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${suggestion['place_id']}'
        '&fields=geometry,formatted_address'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location =
              data['result']['geometry']['location'];
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          final address =
              data['result']['formatted_address'] as String;

          final latLng = LatLng(lat, lng);

          // Move camera
          final controller = await _mapControllerCompleter.future;
          await controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 16.0),
            ),
          );

          setState(() {
            _selectedLocation = latLng;
            _selectedAddress = address;
            _isSearching = false;
          });

          _updateMarker(latLng);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not find location: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── GPS ──────────────────────────────────────────────────────────────────
  Future<void> _goToMyLocation() async {
    setState(() => _isLoadingGPS = true);
    try {
      PermissionStatus status =
          await Permission.locationWhenInUse.status;
      if (status.isDenied) {
        status = await Permission.locationWhenInUse.request();
      }
      if (status.isPermanentlyDenied) {
        if (mounted) _showPermissionDialog();
        return;
      }
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Please enable location services'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final loc = LatLng(position.latitude, position.longitude);
      final controller = await _mapControllerCompleter.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: loc, zoom: 16.0),
        ),
      );
      await _getAddressFromLatLng(loc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get location: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGPS = false);
    }
  }

  void _showPermissionDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('Location Permission',
            style: TextStyle(color: colorScheme.onSurface)),
        content: Text(
          'Location permission is permanently denied. '
          'Please enable it from app settings.',
          style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.tertiary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ─── Confirm ──────────────────────────────────────────────────────────────
  void _confirmLocation() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select a location on the map'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.onLocationSelected(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
      _selectedAddress,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pick Location',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_selectedLocation != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed:
                    _isLoadingAddress ? null : _confirmLocation,
                child: Text(
                  'Confirm',
                  style: TextStyle(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
        ],
      ),

      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ?? _indiaCenter,
              zoom: _selectedLocation != null ? 15.0 : 5.0,
            ),
            onMapCreated: (controller) {
              if (!_mapControllerCompleter.isCompleted) {
                _mapControllerCompleter.complete(controller);
              }
            },
            onTap: (latLng) {
              // Dismiss search when tapping map
              _searchFocusNode.unfocus();
              setState(() => _showSuggestions = false);
              _selectedLocation = latLng;
              _getAddressFromLatLng(latLng);
            },
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),

          // ── Search bar + suggestions (top) ────────────────────────────
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Column(
              children: [
                // Search input
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(isDark ? 0.4 : 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search for a place or address...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.45),
                        fontSize: 14,
                      ),
                      prefixIcon: _isSearching
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.tertiary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.search,
                              color: colorScheme.tertiary,
                              size: 22,
                            ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: colorScheme.onSurface
                                    .withOpacity(0.5),
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _suggestions = [];
                                  _showSuggestions = false;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 4),
                    ),
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                  ),
                ),

                // Suggestions dropdown
                if (_showSuggestions && _suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(isDark ? 0.4 : 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        itemCount: _suggestions.length > 5
                            ? 5
                            : _suggestions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: colorScheme.outline
                              .withOpacity(0.15),
                        ),
                        itemBuilder: (context, index) {
                          final s = _suggestions[index];
                          return InkWell(
                            onTap: () => _selectSuggestion(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: colorScheme.tertiary
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: colorScheme.tertiary,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s['main_text'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight.w600,
                                            color:
                                                colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        if ((s['secondary_text']
                                                as String)
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            s['secondary_text'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme
                                                  .onSurface
                                                  .withOpacity(0.55),
                                            ),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.north_west,
                                    size: 14,
                                    color: colorScheme.onSurface
                                        .withOpacity(0.3),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Tap hint (only when no location selected yet) ─────────────
          if (_selectedLocation == null && !_showSuggestions)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app,
                          size: 15, color: colorScheme.tertiary),
                      const SizedBox(width: 6),
                      Text(
                        'Search above or tap map to set location',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Address loading spinner ───────────────────────────────────
          if (_isLoadingAddress)
            Positioned(
              bottom: _selectedLocation != null ? 172 : 40,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.tertiary,
                  ),
                ),
              ),
            ),

          // ── GPS button ────────────────────────────────────────────────
          Positioned(
            bottom: _selectedLocation != null ? 172 : 80,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'gps_btn',
              backgroundColor: colorScheme.surface,
              elevation: 4,
              onPressed: _isLoadingGPS ? null : _goToMyLocation,
              tooltip: 'My location',
              child: _isLoadingGPS
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.tertiary,
                      ),
                    )
                  : Icon(Icons.my_location,
                      color: colorScheme.tertiary, size: 20),
            ),
          ),

          // ── Bottom confirm bar ────────────────────────────────────────
          if (_selectedLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(16, 14, 16, 24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(isDark ? 0.4 : 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color:
                              colorScheme.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                colorScheme.tertiary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.location_on,
                              color: colorScheme.tertiary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Location',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.tertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _isLoadingAddress
                                  ? Text(
                                      'Getting address...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.5),
                                      ),
                                    )
                                  : Text(
                                      _selectedAddress.isNotEmpty
                                          ? _selectedAddress
                                          : '${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                                              '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurface,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingAddress
                            ? null
                            : _confirmLocation,
                        icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18),
                        label: Text(
                          _isLoadingAddress
                              ? 'Getting address...'
                              : 'Confirm Location',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.tertiary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              colorScheme.tertiary.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}