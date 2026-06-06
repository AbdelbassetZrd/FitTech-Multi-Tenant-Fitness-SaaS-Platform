part of 'register_bloc.dart';

abstract class RegisterEvent extends Equatable {
  const RegisterEvent();
  @override
  List<Object?> get props => [];
}

class RegisterSubmitted extends RegisterEvent {
  final String email;
  final String password;
  final String password2;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;

  const RegisterSubmitted({
    required this.email,
    required this.password,
    required this.password2,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.role = 'member',
  });

  @override
  List<Object?> get props =>
      [email, password, password2, firstName, lastName, phone, role];
}

class RegisterReset extends RegisterEvent {
  const RegisterReset();
}
