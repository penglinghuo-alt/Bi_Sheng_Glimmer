class NewsItem {
  final String id;
  final String title;
  final String brief;
  final String keywords;
  final String url;
  final String? focusDate;
  final String? image;
  final bool isHot;
  final int? hotRank;

  const NewsItem({
    required this.id,
    required this.title,
    required this.brief,
    required this.keywords,
    required this.url,
    this.focusDate,
    this.image,
    this.isHot = false,
    this.hotRank,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      brief: (json['brief'] as String?) ?? '',
      keywords: (json['keywords'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      focusDate: json['focus_date'] as String?,
      image: json['image'] as String?,
      isHot: (json['is_hot'] as bool?) ?? false,
      hotRank: json['hot_rank'] as int?,
    );
  }
}
