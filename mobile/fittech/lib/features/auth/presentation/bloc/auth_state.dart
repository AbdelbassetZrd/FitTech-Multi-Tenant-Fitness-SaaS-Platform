part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final Map<String, dynamic>? userMap;
  const AuthAuthenticated({this.userMap});
  @override
  List<Object?> get props => [userMap];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}
