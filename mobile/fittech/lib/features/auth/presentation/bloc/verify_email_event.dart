part of 'verify_email_bloc.dart';

abstract class VerifyEmailEvent extends Equatable {
  const VerifyEmailEvent();

  @override
  List<Object?> get props => [];
}

class VerifyEmailSubmitted extends VerifyEmailEvent {
  final String email;
  final String code;
  const VerifyEmailSubmitted({required this.email, required this.code});

  @override
  List<Object?> get props => [email, code];
}

class VerifyEmailResendRequested extends VerifyEmailEvent {
  final String email;
  const VerifyEmailResendRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class VerifyEmailTimerStarted extends VerifyEmailEvent {}

class VerifyEmailTimerTicked extends VerifyEmailEvent {
  final int seconds;
  const VerifyEmailTimerTicked({required this.seconds});

  @override
  List<Object?> get props => [seconds];
}
