import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_model.dart';
import '../services/feedback_service.dart';

class AddFeedbackScreen extends StatefulWidget {
  final FeedbackService feedbackService;
  final FeedbackType? initialType;
  final String? clientName;
  final String? supplierName;

  const AddFeedbackScreen({
    super.key,
    required this.feedbackService,
    this.initialType,
    this.clientName,
    this.supplierName,
  });

  @override
  State<AddFeedbackScreen> createState() => _AddFeedbackScreenState();
}

class _AddFeedbackScreenState extends State<AddFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  late FeedbackType _selectedType;
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _messageController;
  int _rating = 5;
  bool _isAnonymous = false;
  bool _isLoading = false;
  
  // Party selection
  String? _selectedPartyId;
  String? _selectedPartyName;
  String? _selectedPartyContact;
  List<Map<String, dynamic>> _parties = [];
  bool _isLoadingParties = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? FeedbackType.client;
    _nameController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _messageController = TextEditingController();
    
    _loadParties();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    setState(() => _isLoadingParties = true);
    try {
      final userMobile = widget.feedbackService.userMobile;
      final collectionRef = _selectedType == FeedbackType.client
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(userMobile)
              .collection('customers')
          : FirebaseFirestore.instance
              .collection('users')
              .doc(userMobile)
              .collection('suppliers');

      final snapshot = await collectionRef
          // .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      setState(() {
        _parties = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'mobile': data['mobile'] ?? '',
            'email': data['email'] ?? '',
          };
        }).toList();
        _isLoadingParties = false;
      });
    } catch (e) {
      print('Error loading parties: $e');
      setState(() => _isLoadingParties = false);
    }
  }

  void _onPartySelected(Map<String, dynamic>? party) {
    setState(() {
      if (party != null) {
        _selectedPartyId = party['id'];
        _selectedPartyName = party['name'];
        _selectedPartyContact = party['mobile'];
        _nameController.text = party['name'];
        _mobileController.text = party['mobile'] ?? '';
        _emailController.text = party['email'] ?? '';
      } else {
        _selectedPartyId = null;
        _selectedPartyName = null;
        _selectedPartyContact = null;
        _nameController.clear();
        _mobileController.clear();
        _emailController.clear();
      }
    });
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate that a party is selected
    if (_selectedPartyId == null) {
      // ✅ FIXED: Removed const keyword
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a ${_selectedType == FeedbackType.client ? "customer" : "supplier"}'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final feedback = FeedbackItem(
        id: '',
        userMobile: widget.feedbackService.userMobile,
        type: _selectedType,
        name: _isAnonymous ? 'Anonymous' : _selectedPartyName!,
        mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        message: _messageController.text.trim(),
        rating: _rating,
        createdAt: DateTime.now(),
        tags: [_selectedPartyId!],
      );

      await widget.feedbackService.addFeedback(feedback);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Feedback'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Feedback Type Selection
                    _buildSectionCard(
                      icon: Icons.people,
                      title: 'Feedback Type',
                      color: colorScheme.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select feedback type',
                            style: TextStyle(
                              fontSize: 13, 
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTypeChip(
                                  FeedbackType.client, 
                                  'Client', 
                                  Icons.person,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTypeChip(
                                  FeedbackType.supplier, 
                                  'Supplier', 
                                  Icons.local_shipping,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Party Selection Dropdown
                    _buildSectionCard(
                      icon: _selectedType == FeedbackType.client ? Icons.people : Icons.store,
                      title: _selectedType == FeedbackType.client ? 'Select Customer' : 'Select Supplier',
                      color: _selectedType == FeedbackType.client ? Colors.blue : Colors.orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedType == FeedbackType.client 
                                ? 'Choose a customer to give feedback'
                                : 'Choose a supplier to give feedback',
                            style: TextStyle(
                              fontSize: 13, 
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _isLoadingParties
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _buildPartyDropdown(),
                          if (_selectedPartyId != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 20,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Selected: $_selectedPartyName',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rating Section
                    _buildSectionCard(
                      icon: Icons.star,
                      title: 'Rating',
                      color: Colors.amber,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                icon: Icon(
                                  index < _rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 32,
                                  color: Colors.amber,
                                ),
                                onPressed: () {
                                  setState(() => _rating = index + 1);
                                },
                              );
                            }),
                          ),
                          Center(
                            child: Text(
                              _getRatingText(),
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Contact Details (Auto-filled from selection)
                    _buildSectionCard(
                      icon: Icons.contact_phone,
                      title: 'Contact Details',
                      color: Colors.teal,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              hintText: 'Name will be auto-filled',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _mobileController,
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Mobile (Auto-filled)',
                              prefixIcon: const Icon(Icons.phone),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Email (Auto-filled)',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Anonymous Switch
                    _buildSectionCard(
                      icon: Icons.visibility_off,
                      title: 'Privacy',
                      color: Colors.purple,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Submit Anonymously',
                                  style: TextStyle(fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Your name will not be shown publicly',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isAnonymous,
                            onChanged: (value) {
                              setState(() {
                                _isAnonymous = value;
                              });
                            },
                            activeColor: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Message Field
                    _buildSectionCard(
                      icon: Icons.message,
                      title: 'Your Feedback',
                      color: Colors.orange,
                      child: TextFormField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Please share your feedback, suggestions, or concerns...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your feedback';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Submit Feedback',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 2 : 1,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(FeedbackType type, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedType == type;
    
    return FilterChip(
      label: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: isSelected ? color : colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedType = type;
          _selectedPartyId = null;
          _selectedPartyName = null;
          _selectedPartyContact = null;
          _nameController.clear();
          _mobileController.clear();
          _emailController.clear();
          _loadParties();
        });
      },
      backgroundColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
      selectedColor: color.withOpacity(0.15),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : colorScheme.onSurface.withOpacity(0.7),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: isSelected ? color : colorScheme.outline,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildPartyDropdown() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_parties.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 40,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No ${_selectedType == FeedbackType.client ? "customers" : "suppliers"} found',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadParties,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline, width: 1),
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedPartyId != null
              ? _parties.firstWhere(
                  (party) => party['id'] == _selectedPartyId,
                  orElse: () => _parties.first,
                )
              : null,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select ${_selectedType == FeedbackType.client ? "customer" : "supplier"}',
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              Icons.arrow_drop_down,
              color: colorScheme.onSurface.withOpacity(0.5),
              size: 28,
            ),
          ),
          items: _parties.map((party) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: party,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (party['mobile'] != null && party['mobile'].isNotEmpty)
                      Text(
                        party['mobile'],
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (selectedParty) {
            if (selectedParty != null) {
              _onPartySelected(selectedParty);
            }
          },
          dropdownColor: colorScheme.surface,
          elevation: isDark ? 8 : 4,
          borderRadius: BorderRadius.circular(12),
          menuMaxHeight: 300,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 5:
        return 'Excellent!';
      case 4:
        return 'Very Good';
      case 3:
        return 'Good';
      case 2:
        return 'Fair';
      case 1:
        return 'Poor';
      default:
        return '';
    }
  }
}