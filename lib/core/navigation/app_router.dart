import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:inventory_app/core/navigation/auth_notifier.dart';
import 'package:inventory_app/core/providers/app_providers.dart';
import 'package:inventory_app/features/splash/splash_screen.dart';
import 'package:inventory_app/features/onboarding/onboarding_screen.dart';
import 'package:inventory_app/features/auth/screens/login_screen.dart';
import 'package:inventory_app/features/dashboard/dashboard_screen.dart';
import 'package:inventory_app/features/inventory/screens/inventory_dashboard.dart';
import 'package:inventory_app/features/inventory/services/inventory_repo_service.dart';
import 'package:inventory_app/features/bill/screens/bill_home_screen.dart';
import 'package:inventory_app/features/ledger/screens/ledger_home_screen.dart';
import 'package:inventory_app/features/party/screens/customer_list_screen.dart';
import 'package:inventory_app/features/party/screens/supplier_list_screen.dart';
import 'package:inventory_app/features/reports/screens/reports_dashboard_screen.dart';
import 'package:inventory_app/features/dashboard/profile_tab.dart';
import 'package:inventory_app/features/dashboard/settings_screen.dart';
import 'package:inventory_app/features/feedback/screens/feedback_list_screen.dart';
import 'package:inventory_app/features/feedback/services/feedback_service.dart';
import 'package:inventory_app/features/ai/screens/ai_chat_screen.dart' show AiChatScreen;
import 'package:inventory_app/features/inventory/screens/all_batches_screen.dart';
import 'package:inventory_app/features/accounts/screens/accounts_dashboard_screen.dart';
import 'package:inventory_app/features/accounts/screens/transactions_dashboard_screen.dart';
import 'package:inventory_app/features/accounts/screens/borrows_dashboard_screen.dart';
import 'package:inventory_app/features/accounts/screens/cashbook_dashboard_screen.dart';

// Route name constants — use these instead of bare strings throughout the app.
class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const dashboard = '/';
  static const inventory = '/inventory';
  static const accounts = '/accounts';
  static const transactions = '/accounts/transactions';
  static const borrows = '/accounts/borrows';
  static const cashBook = '/accounts/cashbook';
  static const bills = '/bills';
  static const billsSales = '/bills/sales';
  static const billsPurchase = '/bills/purchase';
  static const ledger = '/ledger';
  static const ledgerCustomer = '/ledger/customer';
  static const ledgerSupplier = '/ledger/supplier';
  static const customers = '/customers';
  static const suppliers = '/suppliers';
  static const reports = '/reports';
  static const profile = '/profile';
  static const settings = '/settings';
  static const feedback = '/feedback';
  static const aiChat = '/ai-chat';
  static const String batches = '/batches';
}

GoRouter createRouter(AuthNotifier authNotifier) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Hold on splash until BOTH init is done AND the 2-second delay has fired.
      // This prevents any redirect loop: we never leave splash prematurely.
      final readyToLeave = authNotifier.initialized && authNotifier.splashDone;
      if (!readyToLeave) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      // Route away from splash based on auth state.
      if (loc == Routes.splash) {
        if (authNotifier.isAuthenticated) return Routes.dashboard;
        if (authNotifier.isFirstTime) return Routes.onboarding;
        return Routes.login;
      }

      final publicRoutes = {Routes.onboarding, Routes.login};
      final onPublicRoute = publicRoutes.contains(loc);

      if (!authNotifier.isAuthenticated) {
        return onPublicRoute ? null : Routes.login;
      }

      // Authenticated — redirect away from public routes
      if (onPublicRoute) return Routes.dashboard;
      return null;
    },
    routes: [
      // ── Public routes ──────────────────────────────────────────────────────
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, _) => LoginScreen(
          onLoginSuccess: (String mobile) {
            authNotifier.setUser(mobile);
            if (context.mounted) context.go(Routes.dashboard);
          },
        ),
      ),

      // ── Authenticated shell — provides user-scoped services ────────────────
      ShellRoute(
        builder: (context, state, child) {
          final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
          return AppProviders(userMobile: mobile, child: child);
        },
        routes: [
          GoRoute(
            path: Routes.dashboard,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return DashboardScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.inventory,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              final inv = Provider.of<InventoryService>(context, listen: false);
              return InventoryDashboard(inventoryService: inv, userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.accounts,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return AccountsDashboardScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.transactions,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return TransactionsDashboardScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.borrows,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return BorrowsDashboardScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.cashBook,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return CashBookDashboardScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.bills,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return BillHomeScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.billsSales,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return BillHomeScreen(userMobile: mobile, initialFilter: 'sales');
            },
          ),
          GoRoute(
            path: Routes.billsPurchase,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return BillHomeScreen(userMobile: mobile, initialFilter: 'purchase');
            },
          ),
          GoRoute(
            path: Routes.ledger,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return LedgerHomeScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.ledgerCustomer,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return LedgerHomeScreen(userMobile: mobile, initialTab: 1);
            },
          ),
          GoRoute(
            path: Routes.ledgerSupplier,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return LedgerHomeScreen(userMobile: mobile, initialTab: 2);
            },
          ),
          GoRoute(
            path: Routes.cashBook,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return LedgerHomeScreen(userMobile: mobile, initialTab: 3);
            },
          ),
          GoRoute(
            path: Routes.customers,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return CustomerListScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.suppliers,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return SupplierListScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.reports,
            builder: (_, __) => ReportsDashboardScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return ProfileScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return SettingsScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.feedback,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return FeedbackListScreen(feedbackService: FeedbackService(mobile));
            },
          ),
          GoRoute(
            path: Routes.aiChat,
            builder: (context, _) {
              final mobile = Provider.of<AuthNotifier>(context, listen: false).userMobile!;
              return AiChatScreen(userMobile: mobile);
            },
          ),
          GoRoute(
            path: Routes.batches,
            builder: (context, _) {
              final inv = Provider.of<InventoryService>(context, listen: false);
              return AllBatchesScreen(inventoryService: inv);
            },
          ),
        ],
      ),
    ],
  );
}
