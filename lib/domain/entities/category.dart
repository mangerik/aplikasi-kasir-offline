/// Entity domain Kategori — representasi murni tanpa dependency Drift.
///
/// Layer `features/` hanya boleh bergantung pada entity ini (dan kontrak
/// repository di `domain/repositories`), tidak pernah langsung ke Drift.
/// Lihat architecture.md §3.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;

  Category copyWith({int? id, String? name, DateTime? createdAt}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Category &&
            other.id == id &&
            other.name == name &&
            other.createdAt == createdAt);
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);

  @override
  String toString() => 'Category(id: $id, name: $name)';
}
