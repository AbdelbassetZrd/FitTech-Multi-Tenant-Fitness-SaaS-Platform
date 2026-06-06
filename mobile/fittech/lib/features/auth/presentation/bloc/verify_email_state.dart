part of 'verify_email_bloc.dart';

abstract class VerifyEmailState extends Equatable {
  const VerifyEmailState();

  @override
  List<Object?> get props => [];
}

class VerifyEmailInitial extends VerifyEmailState {}

class VerifyEmailTimerRunning extends VerifyEmailState {
  final int seconds;
  const VerifyEmailTimerRunning({required this.seconds});

  @override
  List<Object?> get props => [seconds];
}

class VerifyEmailLoading extends VerifyEmailState {}

class VerifyEmailFailureState extends VerifyEmailState {
  final String message;
  const VerifyEmailFailureState({required this.message});

  @override
  List<Object?> get props => [message];
}

class VerifyEmailSuccess extends VerifyEmailState {}

class VerifyEmailResending extends VerifyEmailState {}

class VerifyEmailResendSuccess extends VerifyEmailState {}
