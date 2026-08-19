class NewsItem {
  final String id;
  final String title;
  final String brief;
  final String keywords;
  final String url;
  final String? focusDate;
  final String? image;

  const NewsItem({
    required this.id,
    required this.title,
    required this.brief,
    required this.keywords,
    required this.url,
    this.focusDate,
    this.image,
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
    );
  }
}
