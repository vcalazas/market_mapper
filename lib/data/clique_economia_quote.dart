class CliqueEconomiaQuote {
  const CliqueEconomiaQuote({
    required this.date,
    required this.companyId,
    required this.store,
    required this.address,
    required this.categoryId,
    required this.productId,
    required this.description,
    required this.regularPrice,
    required this.wholesalePrice,
    required this.wholesaleQuantity,
    required this.promotionPrice,
    required this.loyaltyPrice,
  });

  final DateTime? date;
  final String companyId;
  final String store;
  final String address;
  final String categoryId;
  final String productId;
  final String description;
  final double regularPrice;
  final double wholesalePrice;
  final double wholesaleQuantity;
  final double promotionPrice;
  final double loyaltyPrice;

  double get displayedPrice {
    final discounted = [promotionPrice, loyaltyPrice]
        .where((price) => price > 0)
        .fold<double>(0, (lowest, price) => lowest == 0 || price < lowest ? price : lowest);
    return discounted > 0 ? discounted : regularPrice;
  }

  factory CliqueEconomiaQuote.fromCsvRow(List<String> row) {
    String value(int index) => index < row.length ? row[index].trim() : '';
    DateTime? date;
    try {
      date = DateTime.parse(value(0));
    } on FormatException {
      date = null;
    }

    double price(int index) {
      final raw = value(index).replaceAll('R\$', '').replaceAll(' ', '');
      if (raw.isEmpty) return 0;
      final normalized = raw.contains(',')
          ? raw.replaceAll('.', '').replaceAll(',', '.')
          : raw;
      return double.tryParse(normalized) ?? 0;
    }

    return CliqueEconomiaQuote(
      date: date,
      companyId: value(1),
      store: value(2),
      address: value(3),
      categoryId: value(4),
      productId: value(5),
      description: value(6),
      regularPrice: price(7),
      wholesalePrice: price(8),
      wholesaleQuantity: price(9),
      promotionPrice: price(10),
      loyaltyPrice: price(11),
    );
  }
}

class CliqueEconomiaProduct {
  CliqueEconomiaProduct({required this.id, required this.description});

  final String id;
  final String description;
  final List<CliqueEconomiaQuote> quotes = [];

  double get lowestPrice => quotes
      .map((quote) => quote.displayedPrice)
      .where((price) => price > 0)
      .fold<double>(0, (lowest, price) => lowest == 0 || price < lowest ? price : lowest);
}
