class AppErrorLog {
  final int? id;
  final String source;
  final String message;
  final String? stackTrace;
  final String? details;
  final String createdAt;

  AppErrorLog({
    this.id,
    required this.source,
    required this.message,
    this.stackTrace,
    this.details,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': source,
      'message': message,
      'stack_trace': stackTrace,
      'details': details,
      'created_at': createdAt,
    };
  }

  factory AppErrorLog.fromMap(Map<String, dynamic> map) {
    return AppErrorLog(
      id: map['id'] as int?,
      source: map['source'] as String? ?? 'unknown',
      message: map['message'] as String? ?? '',
      stackTrace: map['stack_trace'] as String?,
      details: map['details'] as String?,
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}
