import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/fuel/presentation/add_fuel_screen.dart';
import '../../features/sharing/presentation/join_vehicle_screen.dart';
import '../../features/sharing/presentation/share_vehicle_screen.dart';
import '../../features/maintenance/presentation/register_maintenance_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/vehicles/presentation/add_vehicle/add_vehicle_screen.dart';
import '../../features/vehicles/presentation/detail/edit_vehicle_screen.dart';
import '../../features/vehicles/presentation/detail/vehicle_detail_screen.dart';
import '../../features/vehicles/presentation/home_screen.dart';
import '../../shared/widgets/coming_soon_screen.dart';
import '../providers/onboarding_provider.dart';
import '../supabase/supabase_provider.dart';
import 'routes.dart';

/// Estado de sesión que el router escucha para redirigir.
/// Es la ÚNICA pieza que reacciona a cambios de sesión con navegación:
/// las pantallas no hacen `context.go('/home')` tras iniciar sesión.
class AuthRouterState extends ChangeNotifier {
  AuthRouterState(this._auth) {
    _sub = _auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.passwordRecovery:
          _recovering = true;
        case AuthChangeEvent.signedOut:
          _recovering = false;
        default:
          break;
      }
      notifyListeners();
    });
  }

  final GoTrueClient _auth;
  late final StreamSubscription<AuthState> _sub;
  bool _recovering = false;

  bool get signedIn => _auth.currentSession != null;

  /// true desde que se abre el enlace de "recuperar contraseña" hasta que
  /// el usuario guarda la nueva. Mientras tanto solo puede ver esa pantalla.
  bool get recovering => _recovering;

  void finishRecovery() {
    _recovering = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final authRouterStateProvider = Provider<AuthRouterState>((ref) {
  final state = AuthRouterState(ref.watch(supabaseClientProvider).auth);
  ref.onDispose(state.dispose);
  return state;
});

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRouterStateProvider);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthRoute = loc.startsWith('/auth');
      final from = Routes.safeFrom(state.uri.queryParameters['from']);

      // 1. Recuperando contraseña: solo la pantalla de nueva contraseña.
      if (auth.recovering) {
        return loc == Routes.resetPassword ? null : Routes.resetPassword;
      }

      // 2. Sin sesión: onboarding (una vez) y luego login, recordando
      //    a dónde quería ir el usuario.
      if (!auth.signedIn) {
        if (loc == Routes.onboarding) return null;
        final target = isAuthRoute ? from : Routes.safeFrom(state.uri.toString());
        if (!ref.read(onboardingSeenProvider)) {
          return Routes.withFrom(Routes.onboarding, target);
        }
        if (isAuthRoute && loc != Routes.resetPassword) return null;
        return Routes.withFrom(Routes.login, target);
      }

      // 3. Con sesión: fuera de las pantallas de auth/onboarding.
      if (isAuthRoute || loc == Routes.onboarding) {
        return from ?? Routes.home;
      }
      return null;
    },
    routes: [
      // Los enlaces mantenitrak://auth-callback?code=… llegan aquí; el
      // canje del código lo hace supabase_flutter por su cuenta.
      GoRoute(path: '/', redirect: (_, __) => Routes.home),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, s) => OnboardingScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, s) => LoginScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, s) => RegisterScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      // Unirse a un vehículo compartido (punto 7). El QR abre
      // mantenitrak://app/join/CODIGO; sin sesión, el redirect manda al
      // login con ?from= y vuelve aquí después.
      GoRoute(
        path: Routes.joinBase,
        builder: (_, __) => const JoinVehicleScreen(),
        routes: [
          GoRoute(
            path: ':code',
            builder: (_, s) => JoinVehicleScreen(initialCode: s.pathParameters['code']),
          ),
        ],
      ),
      // `add` va antes que `:id` para que no se interprete como un id.
      GoRoute(
        path: Routes.addVehicle,
        builder: (_, __) => const AddVehicleScreen(),
      ),
      GoRoute(
        path: '/vehicles/:id',
        builder: (_, s) => VehicleDetailScreen(
          vehicleId: s.pathParameters['id']!,
          initialTab: s.uri.queryParameters['tab'],
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, s) => EditVehicleScreen(vehicleId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'maintenance',
            builder: (_, s) => RegisterMaintenanceScreen(
              vehicleId: s.pathParameters['id']!,
              preselected: (s.uri.queryParameters['items'] ?? '').split(',').where((i) => i.isNotEmpty).toList(),
            ),
          ),
          GoRoute(
            path: 'fuel/add',
            builder: (_, s) => AddFuelScreen(vehicleId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'share',
            builder: (_, s) => ShareVehicleScreen(vehicleId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'expenses/add',
            builder: (_, __) => const ComingSoonScreen(
              title: 'Añadir gasto',
              roadmapStep: 'la fase de gastos, después del punto 7',
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Página no encontrada: ${state.uri.path}')),
    ),
  );
});
