import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/network/auth_interceptor.dart';
import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/api_auth_repository.dart';
import 'features/auth/data/token_storage.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'features/expenses/presentation/cubit/expenses_cubit.dart';
import 'features/navigation/presentation/screens/main_navigation_shell.dart';
import 'features/shared_living/data/repositories/api_shared_living_repository.dart';
import 'features/shared_living/domain/repositories/shared_living_repository.dart';
import 'features/shopping/presentation/cubit/shopping_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();
  final mainDio = DioClientConfig.createDio();
  final refreshDio = DioClientConfig.createRefreshDio();

  // Attach mutex AuthInterceptor for Bearer injection & concurrent 401 token rotation
  final authInterceptor = AuthInterceptor(
    tokenStorage: tokenStorage,
    refreshDio: refreshDio,
    mainDio: mainDio,
  );
  mainDio.interceptors.add(authInterceptor);

  final authRepository = ApiAuthRepository(
    dio: mainDio,
    refreshDio: refreshDio,
    tokenStorage: tokenStorage,
  );

  final sharedLivingRepository = ApiSharedLivingRepository(
    dio: mainDio,
  );

  runApp(MyApp(
    authRepository: authRepository,
    sharedLivingRepository: sharedLivingRepository,
  ));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final SharedLivingRepository sharedLivingRepository;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.sharedLivingRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<SharedLivingRepository>.value(value: sharedLivingRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (context) => AuthCubit(authRepository: authRepository)..checkAuthStatus(),
          ),
          BlocProvider<DashboardCubit>(
            create: (context) => DashboardCubit(repository: sharedLivingRepository),
          ),
          BlocProvider<ShoppingCubit>(
            create: (context) => ShoppingCubit(repository: sharedLivingRepository),
          ),
          BlocProvider<ExpensesCubit>(
            create: (context) => ExpensesCubit(repository: sharedLivingRepository),
          ),
        ],
        child: MaterialApp(
          title: 'Hisab · Shared Living App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          context.read<DashboardCubit>().reset();
        }
      },
      builder: (context, state) {
        if (state is Authenticated) {
          return MainNavigationShell(user: state.user);
        }
        if (state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        return const LoginScreen();
      },
    );
  }
}
