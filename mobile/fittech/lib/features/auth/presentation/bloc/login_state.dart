part of 'login_bloc.dart';

abstract class LoginState extends Equatable {
  const LoginState();
  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginSuccess extends LoginState {
  final AuthTokensEntity tokens;
  const LoginSuccess({required this.tokens});
  @override
  List<Object?> get props => [tokens];
}

class LoginFailure extends LoginState {
  final String message;
  const LoginFailure({required this.message});
  @override
  List<Object?> get props => [message];
}
