/// Generic id+name master-data option - PODs, Units, Activity Types,
/// Advertisers, Brands, Credit Cards (label pre-formatted by the caller).
class SimpleOption {
  final String id;
  final String name;

  SimpleOption({required this.id, required this.name});

  factory SimpleOption.fromJson(Map<String, dynamic> json) => SimpleOption(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
      );
}
