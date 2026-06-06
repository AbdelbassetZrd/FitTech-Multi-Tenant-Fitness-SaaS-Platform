import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_tokens_entity.dart';
import '../../domain/usecases/register_usecase.dart';

part 'register_event.dart';
part 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final RegisterUseCase _registerUseCase;

  RegisterBloc({required RegisterUseCase registerUseCase})
      : _registerUseCase = registerUseCase,
        super(const RegisterInitial()) {
    on<RegisterSubmitted>(_onSubmitted);
    on<RegisterReset>(_onReset);
  }

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    emit(const RegisterLoading());
    final result = await _registerUseCase(
      RegisterParams(
        email: event.email,
        password: event.password,
        password2: event.password2,
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
        role: event.role,
      ),
    );
    result.fold(
      (failure) => emit(RegisterFailure(message: _mapFailure(failure))),
      (tokens) => emit(RegisterSuccess(tokens: tokens)),
    );
  }

  void _onReset(RegisterReset event, Emitter<RegisterState> emit) {
    emit(const RegisterInitial());
  }

  String _mapFailure(Failure failure) {
    if (failure is ValidationFailure) return failure.message;
    if (failure is NetworkFailure) return 'No internet connection.';
    return failure.message;
  }
}
