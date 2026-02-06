// colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // 🌈 Primary Palette (Option 1 - Blue-Teal)
  static const Color primary = Color(0xFF1E3A8A);     // Deep Blue
  static const Color secondary = Color(0xFF0D9488);   // Teal
  static const Color accent = Color(0xFF3B82F6);      // Light Blue
  
  // 🎨 Functional Colors
  static const Color success = Color(0xFF10B981);     // Emerald Green
  static const Color warning = Color(0xFFF59E0B);     // Amber
  static const Color error = Color(0xFFEF4444);       // Red
  static const Color info = Color(0xFF3B82F6);        // Blue Info
  
  // 🏗️ Surface & Background
  static const Color background = Color(0xFFF9FAFB);  // Light Gray
  static const Color surface = Colors.white;          // White
  static const Color card = Color(0xFFFFFFFF);        // White Cards
  
  // 📝 Text Colors
  static const Color textPrimary = Color(0xFF111827);   // Gray 900
  static const Color textSecondary = Color(0xFF6B7280); // Gray 500
  static const Color textHint = Color(0xFF9CA3AF);      // Gray 400
  static const Color textLight = Color(0xFFF9FAFB);     // For dark backgrounds
  
  // 📊 Data Visualization (For Charts/Reports)
  static const Color chart1 = Color(0xFF1E3A8A);       // Primary Blue
  static const Color chart2 = Color(0xFF0D9488);       // Teal
  static const Color chart3 = Color(0xFF3B82F6);       // Light Blue
  static const Color chart4 = Color(0xFF10B981);       // Green
  static const Color chart5 = Color(0xFFF59E0B);       // Amber
  
  // 📱 Status Colors for Inventory
  static const Color stockHigh = Color(0xFF10B981);    // Green
  static const Color stockMedium = Color(0xFFF59E0B);  // Amber
  static const Color stockLow = Color(0xFFEF4444);     // Red
  static const Color stockOut = Color(0xFFDC2626);     // Dark Red
  
  // 💰 Financial Status
  static const Color paid = Color(0xFF10B981);         // Green
  static const Color pending = Color(0xFFF59E0B);      // Amber
  static const Color overdue = Color(0xFFEF4444);      // Red
  
  // 🎯 Module Specific Accents (Optional)
  static const Color customerColor = Color(0xFF3B82F6);   // Blue
  static const Color supplierColor = Color(0xFF0D9488);   // Teal
  static const Color inventoryColor = Color(0xFF1E3A8A);  // Deep Blue
  static const Color ledgerColor = Color(0xFF8B5CF6);     // Violet
  static const Color billColor = Color(0xFF10B981);       // Green
  static const Color reportColor = Color(0xFFF59E0B);     // Amber
  
  // 🔘 Button States
  static const Color buttonPressed = Color(0xFF1E40AF);   // Darker Blue
  static const Color buttonDisabled = Color(0xFF9CA3AF);  // Gray
  
  // 🌓 Dark Theme Colors
  static const Color darkBackground = Color(0xFF111827);  // Gray 900
  static const Color darkSurface = Color(0xFF1F2937);     // Gray 800
  static const Color darkTextPrimary = Color(0xFFF9FAFB); // Light Text
  static const Color darkTextSecondary = Color(0xFFD1D5DB); // Gray 300
}