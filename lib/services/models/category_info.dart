/// A lightweight DTO representing category information for service layer use.
///
/// Used to pass category context to parsing services without coupling
/// to any full category model from the data layer.
class CategoryInfo {
  final String name;
  final String type;

  const CategoryInfo({
    required this.name,
    required this.type,
  });
}
