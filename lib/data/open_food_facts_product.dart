class OpenFoodFactsProduct {
  const OpenFoodFactsProduct({
    required this.code,
    required this.name,
    this.brands,
    this.quantity,
    this.categories,
    this.ingredients,
    this.allergens,
    this.nutriscore,
    this.novaGroup,
    this.ecoscore,
    this.imageUrl,
  });

  final String code;
  final String name;
  final String? brands;
  final String? quantity;
  final String? categories;
  final String? ingredients;
  final String? allergens;
  final String? nutriscore;
  final int? novaGroup;
  final String? ecoscore;
  final String? imageUrl;

  factory OpenFoodFactsProduct.fromJson(Map<String, dynamic> json) {
    String? textValue(String key) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is List) {
        final items = value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (items.isNotEmpty) return items.join(', ');
      }
      return null;
    }

    int? intValue(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value');
    }

    final code = textValue('code') ?? textValue('id') ?? '';
    final localizedName = textValue('product_name_pt') ??
        textValue('product_name') ??
        textValue('product_name_en') ??
        textValue('generic_name_pt') ??
        textValue('generic_name');

    return OpenFoodFactsProduct(
      code: code,
      name: localizedName ?? 'Produto sem nome cadastrado',
      brands: textValue('brands'),
      quantity: textValue('quantity'),
      categories: textValue('categories'),
      ingredients: textValue('ingredients_text_pt') ??
          textValue('ingredients_text'),
      allergens: textValue('allergens'),
      nutriscore: textValue('nutriscore_grade'),
      novaGroup: intValue('nova_group'),
      ecoscore: textValue('ecoscore_grade'),
      imageUrl: textValue('image_front_url') ?? textValue('image_url'),
    );
  }
}
