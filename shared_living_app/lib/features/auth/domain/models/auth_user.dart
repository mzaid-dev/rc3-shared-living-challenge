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
    final member = json['member'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    return AuthUser(
      id: (member?['id'] ?? user?['id'] ?? json['id'] ?? '').toString(),
      name: (member?['name'] ?? user?['display_name'] ?? json['name'] ?? '').toString(),
      email: (user?['email'] ?? json['email'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  @override
  List<Object?> get props => [id, name, email];
}
