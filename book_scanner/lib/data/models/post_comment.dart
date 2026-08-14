import 'showcase_post.dart';

class PostComment {
  final int id;
  final String postId;
  final String content;
  final DateTime createdAt;
  final ShowcaseAuthor author;
  final bool isMine;

  const PostComment({
    required this.id,
    required this.postId,
    required this.content,
    required this.createdAt,
    required this.author,
    required this.isMine,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      author: ShowcaseAuthor.fromJson(json['author'] ?? {}),
      isMine: json['is_mine'] ?? false,
    );
  }
}

class ShowcaseUser {
  final String id;
  final String username;
  final String? avatar;
  final String? bio;
  final DateTime? createdAt;
  final int postCount;

  const ShowcaseUser({
    required this.id,
    required this.username,
    this.avatar,
    this.bio,
    this.createdAt,
    this.postCount = 0,
  });

  factory ShowcaseUser.fromJson(Map<String, dynamic> json) {
    return ShowcaseUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      avatar: json['avatar'],
      bio: json['bio'],
      createdAt: DateTime.tryParse(json['created_at'] ?? ''),
      postCount: json['post_count'] ?? 0,
    );
  }
}

class UnpublishedRecord {
  final String id;
  final String title;
  final String sourceType;
  final int pageCount;
  final String? textContent;

  const UnpublishedRecord({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.pageCount,
    this.textContent,
  });

  factory UnpublishedRecord.fromJson(Map<String, dynamic> json) {
    return UnpublishedRecord(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      sourceType: json['source_type'] ?? '',
      pageCount: json['page_count'] ?? 1,
      textContent: json['text_content'],
    );
  }
}
