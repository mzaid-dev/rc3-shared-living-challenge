import 'package:equatable/equatable.dart';

class FieldViolation extends Equatable {
  final String field;
  final String issue;

  const FieldViolation({required this.field, required this.issue});

  factory FieldViolation.fromJson(Map<String, dynamic> json) {
    return FieldViolation(
      field: json['field'] as String? ?? '',
      issue: json['issue'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'field': field, 'issue': issue};

  @override
  List<Object?> get props => [field, issue];
}

class AppFailure extends Equatable implements Exception {
  final String code;
  final String message;
  final List<FieldViolation> fields;

  const AppFailure({
    required this.code,
    required this.message,
    this.fields = const [],
  });

  factory AppFailure.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>? ?? json;
    return AppFailure(
      code: error['code'] as String? ?? 'UNKNOWN_ERROR',
      message: error['message'] as String? ?? 'An unexpected error occurred.',
      fields: (error['fields'] as List<dynamic>?)
              ?.map((e) => FieldViolation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'error': {
          'code': code,
          'message': message,
          'fields': fields.map((f) => f.toJson()).toList(),
        }
      };

  @override
  List<Object?> get props => [code, message, fields];

  @override
  String toString() => message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message = 'Network connection unavailable. Please check your connection.',
  }) : super(code: 'NETWORK_ERROR');
}
