import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/usecases/verify_email_usecase.dart';
import '../../domain/usecases/resend_verification_usecase.dart';

part 'verify_email_event.dart';
part 'verify_email_state.dart';

class VerifyEmailBloc extends Bloc<VerifyEmailEvent, VerifyEmailState> {
  final VerifyEmailUseCase _verifyEmailUseCase;
  final ResendVerificationUseCase _resendVerificationUseCase;

  Timer? _countdownTimer;
  int _secondsRemaining = 59;

  VerifyEmailBloc({
    required VerifyEmailUseCase verifyEmailUseCase,
    required ResendVerificationUseCase resendVerificationUseCase,
  })  : _verifyEmailUseCase = verifyEmailUseCase,
        _resendVerificationUseCase = resendVerificationUseCase,
        super(VerifyEmailInitial()) {
    on<VerifyEmailSubmitted>(_onVerify);
    on<VerifyEmailResendRequested>(_onResend);
    on<VerifyEmailTimerTicked>(_onTick);
    on<VerifyEmailTimerStarted>(_onTimerStart);
  }

  void _onTimerStart(
      VerifyEmailTimerStarted event, Emitter<VerifyEmailState> emit) {
    _secondsRemaining = 59;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        add(VerifyEmailTimerTicked(seconds: _secondsRemaining));
      } else {
        _countdownTimer?.cancel();
      }
    });
    emit(VerifyEmailTimerRunning(seconds: _secondsRemaining));
  }

  void _onTick(VerifyEmailTimerTicked event, Emitter<VerifyEmailState> emit) {
    emit(VerifyEmailTimerRunning(seconds: event.seconds));
  }

  Future<void> _onVerify(
    VerifyEmailSubmitted event,
    Emitter<VerifyEmailState> emit,
  ) async {
    emit(VerifyEmailLoading());
    final result = await _verifyEmailUseCase(
      VerifyEmailParams(email: event.email, code: event.code),
    );
    result.fold(
      (failure) => emit(VerifyEmailFailureState(message: _map(failure))),
      (_) => emit(VerifyEmailSuccess()),
    );
  }

  Future<void> _onResend(
    VerifyEmailResendRequested event,
    Emitter<VerifyEmailState> emit,
  ) async {
    emit(VerifyEmailResending());
    final result = await _resendVerificationUseCase(
        ResendVerificationParams(email: event.email));
    result.fold(
      (failure) => emit(VerifyEmailFailureState(message: _map(failure))),
      (_) {
        add(VerifyEmailTimerStarted());
        emit(VerifyEmailResendSuccess());
      },
    );
  }

  String _map(Failure f) {
    if (f is NetworkFailure) return 'No internet connection.';
    return f.message;
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }
}
