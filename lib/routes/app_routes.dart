import '../features/auth/screens/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const dashboard = '/dashboard';

  static final routes = {
    login: (context) => LoginScreen(),
    dashboard: (context) =>  DashboardScreen(),
  };
}
