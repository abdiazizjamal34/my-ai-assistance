import 'package:flutter/material.dart';

import 'core/auth/auth_controller.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/settings/app_shell.dart';
import 'core/notifications/notification_service.dart';

// void main() {
//   final apiClient = ApiClient(
//     baseUrl: AppConfig.resolvedApiBaseUrl,
//     userId: AppConfig.userId,
//   );
//   final auth = AuthController(apiClient: apiClient);
//   runApp(ChiefOfStaffApp(apiClient: apiClient, auth: auth));
// }
final navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

 await NotificationService.instance.init(
    onTap: (payload) {
      // payload is the reminder ID
      // For now: just ensure the app is open. In a fuller version,
      // you'd navigate to a specific reminder detail page.
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    },
  );
  final apiClient = ApiClient(
    baseUrl: AppConfig.resolvedApiBaseUrl,
    userId: AppConfig.userId,
  );
  final auth = AuthController(apiClient: apiClient);
  runApp(ChiefOfStaffApp(apiClient: apiClient, auth: auth));
}


class ChiefOfStaffApp extends StatelessWidget {
  const ChiefOfStaffApp({
    required this.apiClient,
    required this.auth,
    super.key,
  });

  final ApiClient apiClient;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
     navigatorKey: navigatorKey,

      title: 'Personal AI Chief of Staff',
      theme: AppTheme.theme,
      home: AnimatedBuilder(
        animation: auth,
        builder: (context, _) {
          switch (auth.status) {
            case AuthStatus.unknown:
              return _BootstrapGate(auth: auth);
            // case AuthStatus.authenticated:
            //   return AppShell(
            //     apiClient: apiClient,
            //     onSignOut: auth.logout,
            //   );


            case AuthStatus.authenticated:
  return AppShell(
    apiClient: apiClient,
    onSignOut: auth.logout,
    authUserId: auth.userId ?? '',
  );
            case AuthStatus.unauthenticated:
              return LoginPage(apiClient: apiClient, auth: auth);
          }
        },
      ),
    );
  }
}

/// Runs [AuthController.bootstrap] once, then lets the parent rebuild
/// into the correct screen based on the resulting status.
class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate({required this.auth});

  final AuthController auth;

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.auth.bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}