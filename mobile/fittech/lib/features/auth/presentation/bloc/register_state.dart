part of 'register_bloc.dart';

abstract class RegisterState extends Equatable {
  const RegisterState();
  @override
  List<Object?> get props => [];
}

class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

class RegisterLoading extends RegisterState {
  const RegisterLoading();
}

class RegisterSuccess extends RegisterState {
  final AuthTokensEntity tokens;
  const RegisterSuccess({required this.tokens});
  @override
  List<Object?> get props => [tokens];
}

class RegisterFailure extends RegisterState {
  final String message;
  const RegisterFailure({required this.message});
  @override
  List<Object?> get props => [message];
}
