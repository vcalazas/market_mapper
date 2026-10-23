class Product {
  const Product({
    this.id,
    required this.barcode,
    required this.name,
    required this.price,
  });

  final int? id;
  final String barcode;
  final String name;
  final double price;

  Map<String, Object?> toMap() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'price': price,
      };

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as int?,
        barcode: map['barcode'] as String,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
      );
}
