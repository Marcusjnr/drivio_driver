import 'dart:convert';

enum MutationStatus { pending, sending, failed, completed }

class Mutation {
  Mutation({
    required this.id,
    required this.idempotencyKey,
    required this.functionName,
    required this.payload,
    this.status = MutationStatus.pending,
    this.retryCount = 0,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String idempotencyKey;
  final String functionName;
  final Map<String, dynamic> payload;
  final MutationStatus status;
  final int retryCount;
  final String? error;
  final DateTime createdAt;

  Mutation copyWith({
    MutationStatus? status,
    int? retryCount,
    String? error,
  }) {
    return Mutation(
      id: id,
      idempotencyKey: idempotencyKey,
      functionName: functionName,
      payload: payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      error: error,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'idempotencyKey': idempotencyKey,
      'functionName': functionName,
      'payload': payload,
      'status': status.name,
      'retryCount': retryCount,
      'error': error,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Mutation.fromJson(Map<String, dynamic> json) {
    return Mutation(
      id: json['id'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      functionName: json['functionName'] as String,
      payload: Map<String, dynamic>.from(
        json['payload'] as Map<dynamic, dynamic>,
      ),
      status: MutationStatus.values.byName(json['status'] as String),
      retryCount: json['retryCount'] as int,
      error: json['error'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String encode() => jsonEncode(toJson());

  factory Mutation.decode(String source) =>
      Mutation.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
