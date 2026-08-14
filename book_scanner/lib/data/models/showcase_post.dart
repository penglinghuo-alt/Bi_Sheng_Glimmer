class ShowcaseAuthor {
  final String id;
  final String username;
  final String? avatar;
  final String? bio;

  const ShowcaseAuthor({
    required this.id,
    required this.username,
    this.avatar,
    this.bio,
  });

  factory ShowcaseAuthor.fromJson(Map<String, dynamic> json) {
    return ShowcaseAuthor(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      avatar: json['avatar'],
      bio: json['bio'],
    );
  }
}

class ShowcasePost {
  final String id;
  final String title;
  final String sourceType;
  final int pageCount;
  final String? textContent;
  final String? description;
  final DateTime createdAt;
  final ShowcaseAuthor author;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool favorited;

  const ShowcasePost({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.pageCount,
    required this.createdAt,
    required this.author,
    this.textContent,
    this.description,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
    this.favorited = false,
  });

  String get excerpt {
    final desc = description?.trim() ?? '';
    if (desc.isEmpty) return '该用户未填写描述';
    if (desc.length <= 80) return desc;
    return '${desc.substring(0, 80)}…';
  }

  String get displayTitle {
    final t = title.trim();
    return t.isEmpty ? '未命名记录' : t;
  }

  ShowcasePost copyWith({
    int? likeCount,
    int? commentCount,
    bool? liked,
    bool? favorited,
  }) {
    return ShowcasePost(
      id: id,
      title: title,
      sourceType: sourceType,
      pageCount: pageCount,
      textContent: textContent,
      description: description,
      createdAt: createdAt,
      author: author,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      liked: liked ?? this.liked,
      favorited: favorited ?? this.favorited,
    );
  }

  factory ShowcasePost.fromJson(Map<String, dynamic> json) {
    return ShowcasePost(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      sourceType: json['source_type'] ?? '',
      pageCount: json['page_count'] ?? 1,
      textContent: json['text_content'],
      description: json['description'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      author: ShowcaseAuthor.fromJson(json['author'] ?? {}),
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      liked: json['liked'] ?? false,
      favorited: json['favorited'] ?? false,
    );
  }
}

class ShowcasePostList {
  final int total;
  final List<ShowcasePost> posts;

  const ShowcasePostList({required this.total, required this.posts});

  factory ShowcasePostList.fromJson(Map<String, dynamic> json) {
    return ShowcasePostList(
      total: json['total'] ?? 0,
      posts: (json['posts'] as List?)?.map((e) => ShowcasePost.fromJson(e)).toList() ?? [],
    );
  }
}
