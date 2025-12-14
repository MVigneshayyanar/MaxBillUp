class CartItem {
  final String productId;
  final String name;
  final double price;
  int quantity;

  // Tax information
  final String? taxName;
  final double? taxPercentage;
  final String? taxType; // 'Price includes Tax', 'Price is without Tax', etc.

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.taxName,
    this.taxPercentage,
    this.taxType,
  });

  double get total => price * quantity;

  // Calculate tax amount based on tax type
  double get taxAmount {
    if (taxPercentage == null || taxPercentage == 0) return 0.0;

    if (taxType == 'Price includes Tax') {
      // Tax is already included in price, extract it
      // price = basePrice + tax
      // price = basePrice * (1 + taxRate)
      // taxAmount = price - (price / (1 + taxRate))
      final taxRate = taxPercentage! / 100;
      return (price * quantity) - ((price * quantity) / (1 + taxRate));
    } else if (taxType == 'Price is without Tax') {
      // Tax needs to be added to price
      return (price * quantity) * (taxPercentage! / 100);
    } else {
      // Zero Rated Tax or Exempt Tax
      return 0.0;
    }
  }

  // Get base price (price without tax)
  double get basePrice {
    if (taxPercentage == null || taxPercentage == 0) return price;

    if (taxType == 'Price includes Tax') {
      // Extract base price from tax-inclusive price
      final taxRate = taxPercentage! / 100;
      return price / (1 + taxRate);
    } else {
      // Price is already without tax
      return price;
    }
  }

  // Get total including tax
  double get totalWithTax {
    if (taxType == 'Price includes Tax') {
      // Tax already included in price
      return total;
    } else if (taxType == 'Price is without Tax') {
      // Add tax to total
      return total + taxAmount;
    } else {
      // Zero Rated or Exempt
      return total;
    }
  }
}