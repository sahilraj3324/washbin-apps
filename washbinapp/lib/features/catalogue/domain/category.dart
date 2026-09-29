import 'package:washbinapp/features/catalogue/domain/json_field.dart';

/// A group of services, as `GET /categories` describes it.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.iconUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: JsonField.id(json),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: JsonField.text(json['description']),
      imageUrl: JsonField.text(json['imageUrl']),
      iconUrl: JsonField.text(json['iconUrl']),
      sortOrder: JsonField.integer(json['sortOrder']) ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;
}
