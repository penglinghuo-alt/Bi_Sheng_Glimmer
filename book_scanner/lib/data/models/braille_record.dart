class BrailleRecord {
  final String id;
  final String title;
  final String sourceType;
  final int dotMatrixWidth;
  final int dotMatrixHeight;
  final List<List<int>> dotMatrixData;
  final DateTime createdAt;
  final int pageCount;

  const BrailleRecord({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.dotMatrixWidth,
    required this.dotMatrixHeight,
    required this.dotMatrixData,
    required this.createdAt,
    this.pageCount = 1,
  });

  BrailleRecord copyWith({
    String? id,
    String? title,
    String? sourceType,
    int? dotMatrixWidth,
    int? dotMatrixHeight,
    List<List<int>>? dotMatrixData,
    DateTime? createdAt,
    int? pageCount,
  }) {
    return BrailleRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      dotMatrixWidth: dotMatrixWidth ?? this.dotMatrixWidth,
      dotMatrixHeight: dotMatrixHeight ?? this.dotMatrixHeight,
      dotMatrixData: dotMatrixData ?? this.dotMatrixData,
      createdAt: createdAt ?? this.createdAt,
      pageCount: pageCount ?? this.pageCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sourceType': sourceType,
        'dotMatrixWidth': dotMatrixWidth,
        'dotMatrixHeight': dotMatrixHeight,
        'dotMatrixData': dotMatrixData,
        'createdAt': createdAt.toIso8601String(),
        'pageCount': pageCount,
      };

  factory BrailleRecord.fromJson(Map<String, dynamic> json) {
    return BrailleRecord(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      sourceType: json['sourceType'] ?? '',
      dotMatrixWidth: json['dotMatrixWidth'] ?? 0,
      dotMatrixHeight: json['dotMatrixHeight'] ?? 0,
      dotMatrixData: (json['dotMatrixData'] as List?)?.map((r) => List<int>.from(r)).toList() ?? [],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      pageCount: json['pageCount'] ?? 1,
    );
  }
}
