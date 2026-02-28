class CartItem {
  final String productId;
  final String name;
  double price; // Changed from final to allow editing
  double quantity; // Changed from int to double to support weights

  final double cost;
  // Tax information
  final String? taxName;
  final double? taxPercentage;
  final String? taxType; // 'Tax Included in Price', 'Add Tax at Billing', 'No Tax Applied', 'Exempt from Tax'

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.cost = 0.0,
    this.quantity = 1.0,
    this.taxName,
    this.taxPercentage,
    this.taxType,
  });

  double get total => price * quantity;

  // Calculate tax amount based on tax type
  double get taxAmount {
    if (taxPercentage == null || taxPercentage == 0) return 0.0;

    if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
      // Tax is already included in price, extract it
      // price = basePrice + tax
      // price = basePrice * (1 + taxRate)
      // taxAmount = price - (price / (1 + taxRate))
      final taxRate = taxPercentage! / 100;
      return (price * quantity) - ((price * quantity) / (1 + taxRate));
    } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
      // Tax needs to be added to price
      return (price * quantity) * (taxPercentage! / 100);
    } else {
      // No Tax Applied or Exempt from Tax
      return 0.0;
    }
  }

  // Get base price (price without tax)
  double get basePrice {
    if (taxPercentage == null || taxPercentage == 0) return price;

    if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
      // Extract base price from tax-inclusive price
      final taxRate = taxPercentage! / 100;
      return price / (1 + taxRate);
    } else {
      // Price is already without tax
      return price;
    }
  }

  // Get per-unit price including tax
  double get priceWithTax {
    if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
      // Tax already included in price
      return price;
    } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
      // Add tax to price
      final taxRate = taxPercentage ?? 0;
      return price * (1 + (taxRate / 100));
    } else {
      // No Tax Applied or Exempt from Tax
      return price;
    }
  }

  // Get total including tax
  double get totalWithTax {
    if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
      // Tax already included in price
      return total;
    } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
      // Add tax to total
      return total + taxAmount;
    } else {
      // No Tax Applied or Exempt from Tax
      return total;
    }
  }
}