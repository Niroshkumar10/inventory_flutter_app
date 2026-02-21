// lib/core/theme/colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // 🌈 Primary Palette
  static const Color primary = Color(0xFF1E3A8A);     // Deep Blue
  static const Color secondary = Color(0xFF0D9488);   // Teal
  static const Color accent = Color(0xFF3B82F6);      // Light Blue
  
  // 🎨 Functional Colors
  static const Color success = Color(0xFF10B981);     // Emerald Green
  static const Color warning = Color(0xFFF59E0B);     // Amber
  static const Color error = Color(0xFFEF4444);       // Red
  static const Color info = Color(0xFF3B82F6);        // Blue Info
  
  // 🏗️ Light Theme Surface & Background
  static const Color background = Color(0xFFF9FAFB);  // Light Gray
  static const Color surface = Colors.white;          // White
  static const Color card = Color(0xFFFFFFFF);        // White Cards
  
  // 📝 Light Theme Text Colors
  static const Color textPrimary = Color(0xFF111827);   // Gray 900
  static const Color textSecondary = Color(0xFF6B7280); // Gray 500
  static const Color textHint = Color(0xFF9CA3AF);      // Gray 400
  static const Color textLight = Color(0xFFF9FAFB);     // For dark backgrounds
  static const Color textDisabled = Color(0xFFD1D5DB);  // Gray 300
  
  // 🌓 Dark Theme Colors
  static const Color darkBackground = Color(0xFF111827);  // Gray 900
  static const Color darkSurface = Color(0xFF1F2937);     // Gray 800
  static const Color darkCard = Color(0xFF374151);        // Gray 700 (for cards in dark mode)
  
  // 📝 Dark Theme Text Colors
  static const Color darkTextPrimary = Color(0xFFF9FAFB);   // Light Text
  static const Color darkTextSecondary = Color(0xFFD1D5DB); // Gray 300
  static const Color darkTextHint = Color(0xFF9CA3AF);      // Gray 400
  static const Color darkTextDisabled = Color(0xFF6B7280);  // Gray 500
  
  // 🔘 Common UI Elements
  static const Color divider = Color(0xFFE5E7EB);        // Light divider
  static const Color darkDivider = Color(0xFF374151);    // Dark divider
  
  static const Color border = Color(0xFFE5E7EB);         // Light border
  static const Color darkBorder = Color(0xFF4B5563);     // Dark border
  
  // 🔘 Button States
  static const Color buttonPressed = Color(0xFF1E40AF);   // Darker Blue
  static const Color buttonDisabled = Color(0xFF9CA3AF);  // Gray
  static const Color darkButtonDisabled = Color(0xFF4B5563); // Dark gray
  
  // 📊 Data Visualization (For Charts/Reports)
  static const Color chart1 = Color(0xFF1E3A8A);       // Primary Blue
  static const Color chart2 = Color(0xFF0D9488);       // Teal
  static const Color chart3 = Color(0xFF3B82F6);       // Light Blue
  static const Color chart4 = Color(0xFF10B981);       // Green
  static const Color chart5 = Color(0xFFF59E0B);       // Amber
  
  // Dark mode chart colors (slightly brighter for dark backgrounds)
  static const Color darkChart1 = Color(0xFF3B82F6);    // Brighter Blue
  static const Color darkChart2 = Color(0xFF14B8A6);    // Brighter Teal
  static const Color darkChart3 = Color(0xFF60A5FA);    // Brighter Light Blue
  static const Color darkChart4 = Color(0xFF34D399);    // Brighter Green
  static const Color darkChart5 = Color(0xFFFBBF24);    // Brighter Amber
  
  // 📱 Status Colors for Inventory
  static const Color stockHigh = Color(0xFF10B981);    // Green
  static const Color stockMedium = Color(0xFFF59E0B);  // Amber
  static const Color stockLow = Color(0xFFEF4444);     // Red
  static const Color stockOut = Color(0xFFDC2626);     // Dark Red
  
  // 💰 Financial Status
  static const Color paid = Color(0xFF10B981);         // Green
  static const Color pending = Color(0xFFF59E0B);      // Amber
  static const Color overdue = Color(0xFFEF4444);      // Red
  static const Color partial = Color(0xFF3B82F6);      // Blue
  
  // 🎯 Module Specific Accents
  static const Color customerColor = Color(0xFF3B82F6);   // Blue
  static const Color supplierColor = Color(0xFF0D9488);   // Teal
  static const Color inventoryColor = Color(0xFF1E3A8A);  // Deep Blue
  static const Color ledgerColor = Color(0xFF8B5CF6);     // Violet
  static const Color billColor = Color(0xFF10B981);       // Green
  static const Color reportColor = Color(0xFFF59E0B);     // Amber
  
  // 🎨 Gradient Colors
  static const gradientStart = primary;
  static const gradientEnd = Color(0xFF2563EB);        // Lighter Blue
  
  // 🌟 Opacity Values (for reuse)
  static const double lowOpacity = 0.1;
  static const double mediumOpacity = 0.5;
  static const double highOpacity = 0.8;
  
  // Helper method to get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  // Helper method to get appropriate chart color based on theme
  static Color getChartColor(int index, bool isDarkMode) {
    final List<Color> lightColors = [chart1, chart2, chart3, chart4, chart5];
    final List<Color> darkColors = [darkChart1, darkChart2, darkChart3, darkChart4, darkChart5];
    
    final colors = isDarkMode ? darkColors : lightColors;
    return colors[index % colors.length];
  }
  
  // Helper method to get status color with proper contrast
  static Color getStatusColor(String status, bool isDarkMode) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'high':
        return paid;
      case 'pending':
      case 'medium':
        return pending;
      case 'overdue':
      case 'low':
        return overdue;
      case 'out':
        return stockOut;
      case 'partial':
        return partial;
      default:
        return isDarkMode ? darkTextSecondary : textSecondary;
    }
  }
}