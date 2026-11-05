import 'package:equatable/equatable.dart';

class Member extends Equatable {
  final String id; // "M01", "M02", "M03"
  final String name;

  const Member({required this.id, required this.name});

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  List<Object?> get props => [id, name];
}
