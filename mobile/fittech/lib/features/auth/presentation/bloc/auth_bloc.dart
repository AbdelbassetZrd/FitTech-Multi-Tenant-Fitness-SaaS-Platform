import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/token_storage.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final TokenStorage _tokenStorage;

  AuthBloc({required TokenStorage tokenStorage})
      : _tokenStorage = tokenStorage,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoggedOut>(_onLoggedOut);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final loggedIn = await _tokenStorage.isLoggedIn();
    if (loggedIn) {
      final userMap = await _tokenStorage.getUser();
      emit(AuthAuthenticated(userMap: userMap));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoggedOut(
    AuthLoggedOut event,
    Emitter<AuthState> emit,
  ) async {
    await _tokenStorage.clearAll();
    emit(AuthUnauthenticated());
  }
}
