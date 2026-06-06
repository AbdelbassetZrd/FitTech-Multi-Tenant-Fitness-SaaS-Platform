import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_tokens_entity.dart';
import '../../domain/usecases/login_usecase.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase _loginUseCase;

  LoginBloc({required LoginUseCase loginUseCase})
      : _loginUseCase = loginUseCase,
        super(const LoginInitial()) {
    on<LoginSubmitted>(_onSubmitted);
    on<LoginReset>(_onReset);
  }

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    final result = await _loginUseCase(
      LoginParams(email: event.email, password: event.password),
    );
    result.fold(
      (failure) => emit(LoginFailure(message: _mapFailure(failure))),
      (tokens) => emit(LoginSuccess(tokens: tokens)),
    );
  }

  void _onReset(LoginReset event, Emitter<LoginState> emit) {
    emit(const LoginInitial());
  }

  String _mapFailure(Failure failure) {
    if (failure is InvalidCredentialsFailure) return failure.message;
    if (failure is NetworkFailure) return 'No internet connection. Check your network.';
    if (failure is ValidationFailure) return failure.message;
    return failure.message;
  }
}
