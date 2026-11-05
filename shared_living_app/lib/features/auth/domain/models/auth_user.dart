import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  final String id; // "M01", "M02", "M03"
  final String name; // "Ali", "Ayesha", "Bilal"
  final String email;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  @override
  List<Object?> get props => [id, name, email];
}
