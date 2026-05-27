# 🏪 Kadai - Inventory Management App

A mobile-first Flutter application designed for small and medium-sized businesses to manage inventory, billing, accounting, customer/supplier relationships, reports, and business operations in one place.

---

## 📌 Overview

Kadai helps shop owners digitize and streamline their daily business activities with real-time data synchronization powered by Firebase.

### Key Highlights

- 📦 Inventory Management
- 🧾 Sales & Purchase Billing
- 💰 Ledger / Accounts Book
- 👥 Customer & Supplier Management
- 📊 Business Reports & Analytics
- 🔔 Expiry & Low Stock Notifications
- 📄 PDF & CSV Export
- 🌙 Light & Dark Theme Support
- ☁️ Firebase Real-Time Sync
- 🤖 AI Assistant Integration

---

## 🚀 Project Information

| Property | Value |
|-----------|--------|
| App Name | Kadai – Inventory Management |
| Version | 1.0.1+6 |
| Platform | Android, iOS, Windows, Web |
| Framework | Flutter (Dart SDK ≥ 3.0.0) |
| Backend | Firebase (Firestore, Auth, Storage, Messaging) |
| Architecture | Feature-First + Provider + GoRouter |
| Theme | Material 3 (Light & Dark) |
| Currency | Indian Rupee (₹) |
| GST Support | Yes |

---

# 🛠️ Tech Stack

## Frontend

| Package | Version | Purpose |
|----------|-----------|----------|
| flutter | Latest | UI Framework |
| provider | ^6.1.2 | State Management |
| go_router | ^14.6.3 | Navigation & Routing |
| intl | ^0.18.1 | Date & Currency Formatting |
| fl_chart | ^0.69.2 | Charts & Analytics |
| animated_splash_screen | ^1.3.0 | Splash Animation |

---

## Firebase & Backend

| Package | Version | Purpose |
|----------|-----------|----------|
| firebase_core | ^3.6.0 | Firebase Initialization |
| cloud_firestore | ^5.4.4 | Real-Time Database |
| firebase_auth | ^5.3.1 | Authentication |
| firebase_storage | ^12.3.2 | File Storage |
| firebase_messaging | ^15.1.3 | Push Notifications |
| shared_preferences | ^2.2.2 | Session Persistence |

---

## Utilities

| Package | Purpose |
|----------|----------|
| crypto | SHA-256 Password Hashing |
| uuid | Unique ID Generation |
| pdf | PDF Generation |
| printing | Print & Share PDF |
| csv | CSV Export |
| path_provider | File System Access |
| file_picker | File Selection |
| open_file | Open Exported Files |
| permission_handler | Runtime Permissions |
| google_maps_flutter | Maps Integration |
| geolocator | GPS Location |
| geocoding | Address Conversion |
| flutter_local_notifications | Local Notifications |
| logger | Logging |
| http | REST API Communication |

---

# 📂 Project Structure

```bash
inventory_flutter_app/
│
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart
│   ├── notification_service.dart
│   │
│   ├── core/
│   │   ├── navigation/
│   │   ├── providers/
│   │   ├── theme/
│   │   └── utils/
│   │
│   └── features/
│       ├── auth/
│       ├── session/
│       ├── dashboard/
│       ├── party/
│       ├── inventory/
│       ├── bill/
│       ├── ledger/
│       ├── reports/
│       ├── feedback/
│       ├── ai/
│       ├── settings/
│       └── onboarding/
│
├── assets/
│   ├── fonts/
│   └── logo/
│
└── pubspec.yaml
```

---

# 🎨 App Color Palette

| Token | Color | Usage |
|---------|---------|---------|
| Primary | `#1E3A8A` | Primary Actions |
| Secondary | `#0D9488` | Secondary Actions |
| Accent | `#3B82F6` | Highlights |
| Success | `#10B981` | Positive States |
| Warning | `#F59E0B` | Alerts |
| Error | `#EF4444` | Errors |
| Ledger | `#8B5CF6` | Ledger Entries |
| Customer | `#3B82F6` | Customer Records |
| Supplier | `#0D9488` | Supplier Records |
| Background | `#F9FAFB` | Screen Background |
| Surface | `#FFFFFF` | Cards & Forms |

---

# 🧭 Navigation Flow

```text
Splash Screen
    │
    ├── First Launch
    │      └── Onboarding
    │
    └── Returning User
            │
            ├── Login
            │      ├── Register
            │      └── Forgot Password
            │
            └── Dashboard
                    ├── Home
                    ├── Inventory
                    ├── Bills
                    ├── Accounts
                    ├── Reports
                    ├── Profile
                    └── Settings
```

---

# 🔐 Authentication Module

### Features

- Mobile Number Login
- User Registration
- Forgot Password
- SHA-256 Password Encryption
- Session Persistence
- Auto Login

### Validation Rules

```text
Mobile Number:
[6-9]\d{9}

Password:
Minimum 6 Characters
Letters + Numbers
```

### Security

- Passwords stored as SHA-256 hashes
- No plain-text passwords
- Firestore-based custom authentication

---

# 📊 Dashboard Module

## Dashboard Tabs

| Tab | Description |
|--------|-------------|
| Home | Business Summary |
| Inventory | Stock Management |
| Bills | Invoice Overview |
| Accounts | Ledger Overview |
| Reports | Analytics Dashboard |
| Profile | User Information |
| Settings | App Preferences |

### Home Dashboard Cards

- Total Sales
- Inventory Value
- Customer Count
- Pending Dues
- Low Stock Alerts
- Expiry Notifications

---

# 👥 Party Management

Manage Customers and Suppliers.

## Customer Features

- Add Customer
- Edit Customer
- GPS Location Support
- Address Storage
- Active/Inactive Status

## Supplier Features

- Supplier Details
- GST Number
- Email Support
- Location Tracking

### Firestore Structure

```text
users/{mobile}/customers/{id}
users/{mobile}/suppliers/{id}
```

---

# 📦 Inventory Management

Complete stock management with category and batch tracking.

## Features

- Item Management
- Category Management
- Batch Tracking
- Expiry Monitoring
- Low Stock Alerts
- Inventory Valuation

## Inventory Metrics

### Low Stock

```text
quantity <= lowStockThreshold
```

### Near Expiry

```text
expiryDate <= 30 Days
```

### Profit Margin

```text
((price - cost) / price) × 100
```

### Total Stock Value

```text
quantity × cost
```

### Firestore Structure

```text
users/{mobile}/inventory/{id}
users/{mobile}/batches/{id}
users/{mobile}/categories/{id}
```

---

# 🧾 Billing Module

Sales and Purchase Invoice Management.

## Features

- Sales Bills
- Purchase Bills
- GST Calculation
- PDF Invoice Export
- Payment Tracking
- Outstanding Balance Calculation

## GST Rates

```text
0%
5%
12%
18%
28%
```

## Payment Status

- Paid
- Partial
- Pending

### Firestore Structure

```text
users/{mobile}/bills/{id}
```

---

# 💰 Ledger / Accounts Book

Tracks all money movement within the business.

## Transaction Types

| User Action | Internal Type |
|-------------|--------------|
| Sold to Customer | Sale |
| Bought from Supplier | Purchase |
| Customer Paid | Payment |
| Supplier Paid | Receipt |
| Income | Income |
| Expense | Expense |

---

## Ledger Tabs

### Home

- Net Balance
- To Collect
- To Pay
- Recent Transactions

### Customers

- Customer-wise Balances
- Outstanding Dues

### Suppliers

- Supplier-wise Balances

### Cash Book

- Money In
- Money Out
- Net Cash Flow

### Firestore Structure

```text
users/{mobile}/ledger/{id}
```

---

# 📈 Reports Module

Generate business reports and exports.

## Available Reports

| Report | Export |
|----------|---------|
| Sales Report | PDF, CSV |
| Purchase Report | PDF, CSV |
| Inventory Report | PDF, CSV |
| Customer Report | PDF |
| Supplier Report | PDF |
| Profit & Loss | PDF |
| Ledger Report | PDF, CSV |

---

# ⭐ Feedback Module

Collect feedback from customers and suppliers.

## Features

- Ratings (1–5 Stars)
- Comments
- Status Tracking
- Anonymous Feedback
- Tags & Labels

### Status Flow

```text
Pending
   ↓
Reviewed
   ↓
Resolved
   ↓
Archived
```

### Firestore Structure

```text
users/{mobile}/feedback/{id}
```

---

# 🔔 Notification System

### Firebase Cloud Messaging (FCM)

Used for:

- Push Notifications
- System Alerts
- Business Updates

### Local Notifications

Used for:

- Expiry Alerts
- Low Stock Warnings
- Payment Reminders

---

# 🗄️ Firestore Database Design

```text
users/
└── {mobile}
    ├── customers/
    ├── suppliers/
    ├── inventory/
    ├── batches/
    ├── bills/
    ├── ledger/
    ├── feedback/
    └── categories/
```

---

# ⚡ State Management

```text
MultiProvider
│
├── AuthNotifier
├── ThemeProvider
├── AIProvider
│
└── ProxyProvider
    ├── InventoryService
    ├── BillService
    ├── CustomerService
    └── SupplierService
```

---

# 🔒 Security Features

| Feature | Implementation |
|----------|----------------|
| Password Security | SHA-256 Hashing |
| Session Persistence | SharedPreferences |
| Data Isolation | User-Scoped Collections |
| Authentication | Firebase Auth |
| Validation | Form & Input Validation |
| Access Control | Route Guards |

---

# 📋 Business Rules

### Inventory

- Sales reduce stock automatically.
- Low stock triggers alerts.
- Batch quantity is tracked separately.

### Billing

- GST can be enabled or disabled.
- Invoice numbers can be auto-generated.

### Ledger

- Running balance maintained automatically.
- Customer/Supplier dues tracked separately.

### Expiry Management

- Near expiry = 30 days or less.
- Expired items flagged automatically.

---

# 🌐 Platform Support

| Platform | Supported |
|-----------|------------|
| Android | ✅ |
| iOS | ✅ |
| Windows | ✅ |
| Web | ✅ |

---

# 🚀 Future Enhancements

- Barcode Scanning
- Thermal Printer Support
- Multi-User Access
- Role-Based Permissions
- Offline Sync Engine
- WhatsApp Invoice Sharing
- AI Business Insights
- Multi-Language Support

---

# 👨‍💻 Development Notes

- Feature-first architecture
- Firebase real-time synchronization
- Material 3 UI design
- Pagination support for large datasets
- SQLite offline caching
- Dark/Light theme support
- Multi-platform deployment

---

# 🏢 Built By

### NeuralArc

**Kadai – Smart Inventory Management for India's Neighborhood Shops**

Empowering small businesses with modern digital inventory, billing, accounting, and analytics solutions.

---
