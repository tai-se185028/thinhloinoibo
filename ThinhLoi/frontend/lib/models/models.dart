enum StockStatus { inStock, low, out }

enum DocStatus { draft, confirmed }

enum PartnerType { customer, supplier }

enum PaymentStatus { unpaid, partial, paid }

class Product {
  Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.dimension,
    required this.material,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.minStock,
    this.imageUrl = '',
    this.note = '',
    this.layerCount,
    this.dimensionUnit = 'cm',
    this.description = '',
  });
  final String id;
  String sku, name, category, dimension, material, unit, imageUrl, note;
  String dimensionUnit, description;
  int? layerCount;
  double purchasePrice, sellingPrice;
  int stockQuantity, minStock;
  StockStatus get status => stockQuantity <= 0
      ? StockStatus.out
      : stockQuantity <= minStock
      ? StockStatus.low
      : StockStatus.inStock;
}

class Partner {
  Partner({
    required this.id,
    required this.type,
    required this.name,
    required this.phone,
    required this.address,
    this.email = '',
    this.taxCode = '',
    this.note = '',
    this.contactPerson = '',
    this.deliveryAddress = '',
    this.isActive = true,
  });
  final String id;
  PartnerType type;
  String name, phone, address, email, taxCode, note;
  String contactPerson, deliveryAddress;
  bool isActive;
}

class LineItem {
  LineItem({
    required this.productId,
    required this.quantity,
    required this.price,
    int? requestedQuantity,
    this.sourceItemId,
  }) : requestedQuantity = requestedQuantity ?? quantity;
  final String productId;
  int quantity;
  int requestedQuantity;
  String? sourceItemId;
  double price;
  double get total => quantity * price;
}

class StockDocument {
  StockDocument({
    required this.id,
    required this.code,
    required this.inbound,
    required this.date,
    required this.partnerId,
    required this.items,
    this.status = DocStatus.draft,
    this.discount = 0,
    this.note = '',
    this.salesOrderId,
    this.recipientName = '',
    this.recipientDepartment = '',
    this.deliveryAddress = '',
    this.reason = '',
    this.destination = '',
  });
  final String id, code;
  String? salesOrderId;
  String recipientName,
      recipientDepartment,
      deliveryAddress,
      reason,
      destination;
  final bool inbound;
  DateTime date;
  String partnerId, note;
  List<LineItem> items;
  DocStatus status;
  double discount;
  double get subtotal => items.fold(0, (v, e) => v + e.total);
  double get total => subtotal - discount;
}

class Movement {
  Movement({
    required this.id,
    required this.productId,
    required this.code,
    required this.date,
    required this.inbound,
    required this.quantity,
    required this.balance,
  });
  final String id, productId, code;
  final DateTime date;
  final bool inbound;
  final int quantity, balance;
}

class Invoice {
  Invoice({
    required this.id,
    required this.number,
    required this.date,
    required this.customerId,
    required this.items,
    this.sourceDocumentId,
    this.discount = 0,
    this.paymentMethod = 'Chuyển khoản',
    this.paymentStatus = PaymentStatus.unpaid,
    this.note = '',
    this.draft = true,
  });
  final String id, number;
  DateTime date;
  String customerId, paymentMethod, note;
  String? sourceDocumentId;
  List<LineItem> items;
  double discount;
  PaymentStatus paymentStatus;
  bool draft;
  double get subtotal => items.fold(0, (v, e) => v + e.total);
  double get total => subtotal - discount;
}

class CompanyProfile {
  String name = 'CÔNG TY TNHH BAO BÌ PACKFLOW';
  String address = '125 Nguyễn Văn Linh, Quận 7, TP. Hồ Chí Minh';
  String phone = '028 3765 8899';
  String email = 'kho@packflow.vn';
  String bank = 'Vietcombank • 1028896688';
  String shortName = '';
  String taxCode = '';
  String website = '';
  String representativeName = '';
  String currency = 'VND';
  String invoiceFooter = '';
}

enum SalesOrderStatus {
  draft,
  confirmed,
  partiallyFulfilled,
  fulfilled,
  cancelled,
}

class SalesOrder {
  SalesOrder({
    required this.id,
    required this.code,
    required this.customerId,
    required this.date,
    required this.items,
    this.expectedDeliveryDate,
    this.deliveryAddress = '',
    this.note = '',
    this.discount = 0,
    this.status = SalesOrderStatus.draft,
  });
  final String id, code, customerId;
  final DateTime date;
  DateTime? expectedDeliveryDate;
  String deliveryAddress, note;
  double discount;
  SalesOrderStatus status;
  List<LineItem> items;
  double get subtotal => items.fold(0, (value, item) => value + item.total);
  double get total => subtotal - discount;
  int get orderedQuantity =>
      items.fold(0, (value, item) => value + item.requestedQuantity);
  int get fulfilledQuantity =>
      items.fold(0, (value, item) => value + item.quantity);
}
