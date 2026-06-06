import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';

import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/refresh_token_usecase.dart';
import 'features/auth/domain/usecases/register_usecase.dart';
import 'features/auth/domain/usecases/resend_verification_usecase.dart';
import 'features/auth/domain/usecases/verify_email_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/login_bloc.dart';
import 'features/auth/presentation/bloc/register_bloc.dart';
import 'features/auth/presentation/bloc/verify_email_bloc.dart';

import 'features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'features/subscription/data/repositories/subscription_repository_impl.dart';

import 'features/messaging/data/datasources/messaging_remote_datasource.dart';
import 'features/messaging/data/repositories/messaging_repository_impl.dart';
import 'features/messaging/domain/repositories/messaging_repository.dart';
import 'features/messaging/presentation/bloc/messaging_bloc.dart';

import 'core/services/nfc_service.dart';
import 'features/nfc/data/datasources/nfc_remote_datasource.dart';
import 'features/nfc/data/repositories/nfc_repository_impl.dart';
import 'features/nfc/domain/repositories/nfc_repository.dart';
import 'features/nfc/presentation/bloc/nfc_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── Core ───────────────────────────────────────────────────────────────────
  final tokenStorage = TokenStorage();
  await tokenStorage.init();

  sl.registerSingleton<TokenStorage>(tokenStorage);

  sl.registerLazySingleton<http.Client>(() => http.Client());

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(
      client: sl<http.Client>(),
      tokenStorage: sl<TokenStorage>(),
    ),
  );

  // ── Data Sources ───────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
  );

  // ── Repositories ───────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSource>(),
      tokenStorage: sl<TokenStorage>(),
    ),
  );

  // ── Use Cases ──────────────────────────────────────────────────────────────
  sl.registerLazySingleton<LoginUseCase>(
      () => LoginUseCase(sl<AuthRepository>()));

  sl.registerLazySingleton<RegisterUseCase>(
      () => RegisterUseCase(sl<AuthRepository>()));

  sl.registerLazySingleton<LogoutUseCase>(
      () => LogoutUseCase(sl<AuthRepository>()));

  sl.registerLazySingleton<VerifyEmailUseCase>(
      () => VerifyEmailUseCase(sl<AuthRepository>()));

  sl.registerLazySingleton<ResendVerificationUseCase>(
      () => ResendVerificationUseCase(sl<AuthRepository>()));

  sl.registerLazySingleton<RefreshTokenUseCase>(
      () => RefreshTokenUseCase(sl<AuthRepository>()));

  // ── BLoCs ──────────────────────────────────────────────────────────────────
  // AuthBloc is a singleton — it guards the session for the app lifetime
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(tokenStorage: sl<TokenStorage>()),
  );

  // Per-screen BLoCs created fresh each time via registerFactory
  sl.registerFactory<LoginBloc>(
    () => LoginBloc(loginUseCase: sl<LoginUseCase>()),
  );

  sl.registerFactory<RegisterBloc>(
    () => RegisterBloc(registerUseCase: sl<RegisterUseCase>()),
  );

  sl.registerFactory<VerifyEmailBloc>(
    () => VerifyEmailBloc(
      verifyEmailUseCase: sl<VerifyEmailUseCase>(),
      resendVerificationUseCase: sl<ResendVerificationUseCase>(),
    ),
  );

  // ── Messaging ──────────────────────────────────────────────────────────────
  sl.registerLazySingleton<MessagingRemoteDataSource>(
    () => MessagingRemoteDataSourceImpl(
      apiClient: sl<ApiClient>(),
      tokenStorage: sl<TokenStorage>(),
    ),
  );

  sl.registerLazySingleton<MessagingRepository>(
    () => MessagingRepositoryImpl(
      remoteDataSource: sl<MessagingRemoteDataSource>(),
    ),
  );

  sl.registerFactory<MessagingBloc>(
    () => MessagingBloc(repository: sl<MessagingRepository>()),
  );

  // ── NFC / Access Control ───────────────────────────────────────────────────
  sl.registerLazySingleton<NfcService>(() => NfcService());

  sl.registerLazySingleton<NfcRemoteDataSource>(
    () => NfcRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
  );

  sl.registerLazySingleton<NfcRepository>(
    () => NfcRepositoryImpl(remoteDataSource: sl<NfcRemoteDataSource>()),
  );

  sl.registerLazySingleton<SubscriptionRemoteDataSource>(
    () => SubscriptionRemoteDataSource(
      apiClient: sl<ApiClient>(),
    ),
  );

  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepository(
        remoteDataSource: sl<SubscriptionRemoteDataSource>()),
  );

  sl.registerFactory<NfcBloc>(
    () => NfcBloc(
      repository: sl<NfcRepository>(),
      nfcService: sl<NfcService>(),
    ),
  );
}
