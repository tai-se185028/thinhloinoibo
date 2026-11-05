import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'repositories/supabase_repositories.dart';

class AppStore extends ChangeNotifier {
  AppStore.seeded() : _client = null, isRemote = false {
    _seed();
  }
  AppStore.supabase() : _client = Supabase.instance.client, isRemote = true;
  final SupabaseClient? _client;
  final bool isRemote;
  bool loading = false;
  String? errorMessage;
  final products = <Product>[];
  final partners = <Partner>[];
  final documents = <StockDocument>[];
  final movements = <Movement>[];
  final invoices = <Invoice>[];
  final salesOrders = <SalesOrder>[];
  final company = CompanyProfile();
  String? _businessSettingsId;
  int _sequence = 100;
  int _loadGeneration = 0;

  void clearEmployeeData() {
    _loadGeneration++;
    products.clear();
    partners.clear();
    documents.clear();
    movements.clear();
    invoices.clear();
    salesOrders.clear();
    company.name = '';
    company.address = '';
    company.phone = '';
    company.email = '';
    company.bank = '';
    loading = false;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> loadRemoteData() async {
    if (!isRemote || _client == null || _client.auth.currentSession == null) {
      return;
    }
    loading = true;
    final generation = ++_loadGeneration;
    final userId = _client.auth.currentUser?.id;
    errorMessage = null;
    notifyListeners();
    try {
      final productRows = await ProductRepository(_client).list();
      final customerRows = await CustomerRepository(_client).list();
      final supplierRows = await SupplierRepository(_client).list();
      final movementRows = await InventoryRepository(_client).movements();
      final inboundRows = await InboundRepository(_client).list();
      final outboundRows = await OutboundRepository(_client).list();
      final invoiceRows = await InvoiceRepository(_client).list();
      final salesOrderRows = await SalesOrderRepository(_client).list();
      final settingsRow = await BusinessSettingsRepository(_client).get();
      if (generation != _loadGeneration ||
          userId != _client.auth.currentUser?.id) {
        return;
      }
      products
        ..clear()
        ..addAll(productRows.map(_productFromRow));
      partners
        ..clear()
        ..addAll(
          customerRows.map((r) => _partnerFromRow(r, PartnerType.customer)),
        )
        ..addAll(
          supplierRows.map((r) => _partnerFromRow(r, PartnerType.supplier)),
        );
      movements
        ..clear()
        ..addAll(
          movementRows.map(
            (r) => Movement(
              id: r['id'].toString(),
              productId: r['product_id'].toString(),
              code: r['reference_type'].toString(),
              date: DateTime.parse(r['created_at'].toString()),
              inbound: (r['quantity_change'] as num) > 0,
              quantity: ((r['quantity_change'] as num).abs()).round(),
              balance: (r['balance_after'] as num).round(),
            ),
          ),
        );
      documents
        ..clear()
        ..addAll(inboundRows.map((r) => _documentFromRow(r, true)))
        ..addAll(outboundRows.map((r) => _documentFromRow(r, false)))
        ..sort((a, b) => b.date.compareTo(a.date));
      invoices
        ..clear()
        ..addAll(invoiceRows.map(_invoiceFromRow));
      salesOrders
        ..clear()
        ..addAll(salesOrderRows.map(_salesOrderFromRow));
      if (settingsRow != null) {
        _businessSettingsId = settingsRow['id']?.toString();
        company.name = settingsRow['business_name']?.toString() ?? '';
        company.address = settingsRow['address']?.toString() ?? '';
        company.phone = settingsRow['phone']?.toString() ?? '';
        company.email = settingsRow['email']?.toString() ?? '';
        company.bank =
            [settingsRow['bank_name'], settingsRow['bank_account_number']]
                .where((value) => value != null && value.toString().isNotEmpty)
                .join(' • ');
        company.shortName = settingsRow['company_short_name']?.toString() ?? '';
        company.taxCode = settingsRow['tax_code']?.toString() ?? '';
        company.website = settingsRow['website']?.toString() ?? '';
        company.representativeName =
            settingsRow['representative_name']?.toString() ?? '';
        company.currency = settingsRow['default_currency']?.toString() ?? 'VND';
        company.invoiceFooter = settingsRow['invoice_footer']?.toString() ?? '';
      }
    } on AppFailure catch (e) {
      if (generation == _loadGeneration) errorMessage = e.message;
    } catch (_) {
      if (generation == _loadGeneration) {
        errorMessage = 'Không thể tải dữ liệu. Vui lòng thử lại.';
      }
    } finally {
      if (generation == _loadGeneration) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Product _productFromRow(Map<String, dynamic> r) => Product(
    id: r['id'].toString(),
    sku: r['sku']?.toString() ?? '',
    name: r['name']?.toString() ?? '',
    category: r['category_name']?.toString() ?? 'Chưa phân loại',
    dimension: [
      r['dimension_length'],
      r['dimension_width'],
      r['dimension_height'],
    ].where((e) => e != null).join(' × '),
    material: r['material']?.toString() ?? '',
    unit: r['unit']?.toString() ?? 'đơn vị',
    purchasePrice: (r['purchase_price'] as num?)?.toDouble() ?? 0,
    sellingPrice: (r['selling_price'] as num?)?.toDouble() ?? 0,
    stockQuantity: (r['stock_quantity'] as num?)?.round() ?? 0,
    minStock: (r['minimum_stock'] as num?)?.round() ?? 0,
    imageUrl: r['image_path']?.toString() ?? '',
    note: r['packaging_specification']?.toString() ?? '',
    layerCount: (r['layer_count'] as num?)?.toInt(),
    dimensionUnit: r['dimension_unit']?.toString() ?? 'cm',
    description: r['description']?.toString() ?? '',
  );
  Partner _partnerFromRow(Map<String, dynamic> r, PartnerType type) => Partner(
    id: r['id'].toString(),
    type: type,
    name: r['name']?.toString() ?? '',
    phone: r['phone']?.toString() ?? '',
    address: r['address']?.toString() ?? '',
    email: r['email']?.toString() ?? '',
    taxCode: r['tax_code']?.toString() ?? '',
    note: r['notes']?.toString() ?? '',
    contactPerson: r['contact_person']?.toString() ?? '',
    deliveryAddress: r['delivery_address']?.toString() ?? '',
    isActive: r['is_active'] as bool? ?? true,
  );
  StockDocument _documentFromRow(Map<String, dynamic> r, bool inbound) {
    final raw =
        (r[inbound ? 'inbound_items' : 'outbound_items'] as List? ?? const []);
    return StockDocument(
      id: r['id'].toString(),
      code: r['voucher_code'].toString(),
      inbound: inbound,
      date: DateTime.parse((r['voucher_date'] ?? r['created_at']).toString()),
      partnerId: r[inbound ? 'supplier_id' : 'customer_id'].toString(),
      items: raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return LineItem(
          productId: m['product_id'].toString(),
          quantity: (m['quantity'] as num).round(),
          requestedQuantity: (m['requested_quantity'] as num?)?.round(),
          price: (m['unit_price'] as num).toDouble(),
        );
      }).toList(),
      status: r['status'] == 'confirmed'
          ? DocStatus.confirmed
          : DocStatus.draft,
      discount: (r['discount_amount'] as num?)?.toDouble() ?? 0,
      note: r['note']?.toString() ?? '',
      salesOrderId: r['sales_order_id']?.toString(),
      recipientName: r['recipient_name']?.toString() ?? '',
      recipientDepartment: r['recipient_department']?.toString() ?? '',
      deliveryAddress: r['delivery_address']?.toString() ?? '',
      reason: r['dispatch_reason']?.toString() ?? '',
      destination: r['destination']?.toString() ?? '',
    );
  }

  Invoice _invoiceFromRow(Map<String, dynamic> r) {
    final raw = (r['invoice_items'] as List? ?? const []);
    return Invoice(
      id: r['id'].toString(),
      number: r['invoice_code'].toString(),
      date: DateTime.parse(r['invoice_date'].toString()),
      customerId: r['customer_id'].toString(),
      items: raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return LineItem(
          productId: m['product_id']?.toString() ?? '',
          quantity: (m['quantity'] as num).round(),
          price: (m['unit_price'] as num).toDouble(),
        );
      }).toList(),
      sourceDocumentId: r['outbound_voucher_id']?.toString(),
      discount: (r['discount_amount'] as num?)?.toDouble() ?? 0,
      paymentStatus: switch (r['payment_status']) {
        'paid' => PaymentStatus.paid,
        'partial' => PaymentStatus.partial,
        _ => PaymentStatus.unpaid,
      },
      draft: r['status'] == 'draft',
      note: r['note']?.toString() ?? '',
    );
  }

  SalesOrder _salesOrderFromRow(Map<String, dynamic> r) {
    final raw = r['sales_order_items'] as List? ?? const [];
    return SalesOrder(
      id: r['id'].toString(),
      code: r['order_code'].toString(),
      customerId: r['customer_id'].toString(),
      date: DateTime.parse(r['order_date'].toString()),
      expectedDeliveryDate: r['expected_delivery_date'] == null
          ? null
          : DateTime.parse(r['expected_delivery_date'].toString()),
      deliveryAddress: r['delivery_address']?.toString() ?? '',
      note: r['note']?.toString() ?? '',
      discount: (r['discount_amount'] as num?)?.toDouble() ?? 0,
      status: switch (r['status']) {
        'confirmed' => SalesOrderStatus.confirmed,
        'partially_fulfilled' => SalesOrderStatus.partiallyFulfilled,
        'fulfilled' => SalesOrderStatus.fulfilled,
        'cancelled' => SalesOrderStatus.cancelled,
        _ => SalesOrderStatus.draft,
      },
      items: raw.map((value) {
        final item = Map<String, dynamic>.from(value as Map);
        return LineItem(
          productId: item['product_id'].toString(),
          requestedQuantity: (item['ordered_quantity'] as num).round(),
          quantity: (item['fulfilled_quantity'] as num).round(),
          price: (item['unit_price'] as num).toDouble(),
          sourceItemId: item['id'].toString(),
        );
      }).toList(),
    );
  }

  Product? productOrNull(String id) =>
      products.where((e) => e.id == id).firstOrNull;
  Partner? partnerOrNull(String id) =>
      partners.where((e) => e.id == id).firstOrNull;
  Product product(String id) =>
      productOrNull(id) ??
      Product(
        id: id,
        sku: '—',
        name: 'Sản phẩm không còn tồn tại',
        category: '',
        dimension: '',
        material: '',
        unit: '',
        purchasePrice: 0,
        sellingPrice: 0,
        stockQuantity: 0,
        minStock: 0,
      );
  Partner partner(String id) =>
      partnerOrNull(id) ??
      Partner(
        id: id,
        type: PartnerType.customer,
        name: 'Đối tác không còn tồn tại',
        phone: '',
        address: '',
      );
  List<Partner> partnersOf(PartnerType type) =>
      partners.where((e) => e.type == type).toList();
  double get stockValue =>
      products.fold(0, (v, e) => v + e.purchasePrice * e.stockQuantity);
  int get stockUnits => products.fold(0, (v, e) => v + e.stockQuantity);
  double get inboundValue => documents
      .where((e) => e.inbound && e.status == DocStatus.confirmed)
      .fold(0, (v, e) => v + e.total);
  double get outboundValue => documents
      .where((e) => !e.inbound && e.status == DocStatus.confirmed)
      .fold(0, (v, e) => v + e.total);

  void addProduct(Product value) {
    products.insert(0, value);
    notifyListeners();
    if (isRemote) unawaited(_createRemoteProduct(value));
  }

  Future<void> saveProduct(
    Product value, {
    required bool isNew,
    int receivedQuantity = 0,
  }) async {
    if (!isRemote) {
      if (isNew) {
        addProduct(value);
      } else {
        value.stockQuantity += receivedQuantity;
        final index = products.indexWhere((e) => e.id == value.id);
        if (index >= 0) products[index] = value;
        notifyListeners();
      }
      return;
    }
    final payload = _productPayload(value, await _categoryId(value.category));
    await _client!.rpc(
      'receive_product',
      params: {
        'p_product': payload,
        'p_quantity': isNew ? value.stockQuantity : receivedQuantity,
        'p_product_id': isNew ? null : value.id,
      },
    );
    await loadRemoteData();
  }

  Future<void> removeProduct(String id) async {
    if (!isRemote) {
      deleteProduct(id);
      return;
    }
    await ProductRepository(_client!).deactivate(id);
    await loadRemoteData();
  }

  void updateProduct(Product value) {
    notifyListeners();
    if (isRemote) unawaited(_updateRemoteProduct(value));
  }

  void deleteProduct(String id) {
    products.removeWhere((e) => e.id == id);
    notifyListeners();
    if (isRemote) {
      unawaited(
        ProductRepository(_client!)
            .deactivate(id)
            .then((_) => loadRemoteData())
            .catchError(_captureError),
      );
    }
  }

  void addPartner(Partner value) {
    partners.insert(0, value);
    notifyListeners();
    if (isRemote) unawaited(_saveRemotePartner(value));
  }

  Future<void> savePartner(Partner value, {required bool isNew}) async {
    if (!isRemote) {
      if (isNew) {
        addPartner(value);
      } else {
        final index = partners.indexWhere((e) => e.id == value.id);
        if (index >= 0) partners[index] = value;
        notifyListeners();
      }
      return;
    }
    final row = {
      if (isNew) 'code': 'DT-${DateTime.now().millisecondsSinceEpoch}',
      'name': value.name.trim(),
      'phone': value.phone.trim(),
      'email': value.email.trim(),
      'address': value.address.trim(),
      'tax_code': value.taxCode.trim(),
      'notes': value.note.trim(),
      'contact_person': value.contactPerson.trim(),
      'delivery_address': value.deliveryAddress.trim(),
    };
    if (value.type == PartnerType.supplier) {
      final repository = SupplierRepository(_client!);
      if (isNew) {
        await repository.save(row);
      } else {
        await repository.update(value.id, row);
      }
    } else {
      final repository = CustomerRepository(_client!);
      if (isNew) {
        await repository.save(row);
      } else {
        await repository.update(value.id, row);
      }
    }
    await loadRemoteData();
  }

  Future<void> removePartner(String id) async {
    if (!isRemote) {
      deletePartner(id);
      return;
    }
    final value = partnerOrNull(id);
    if (value == null) return;
    if (value.type == PartnerType.supplier) {
      await SupplierRepository(_client!).remove(id);
    } else {
      await CustomerRepository(_client!).remove(id);
    }
    await loadRemoteData();
  }

  void deletePartner(String id) {
    final wasSupplier = partners.any(
      (e) => e.id == id && e.type == PartnerType.supplier,
    );
    partners.removeWhere((e) => e.id == id);
    notifyListeners();
    if (isRemote) {
      final repo = wasSupplier
          ? SupplierRepository(_client!)
          : CustomerRepository(_client!);
      unawaited(
        (repo is SupplierRepository
                ? repo.remove(id)
                : (repo as CustomerRepository).remove(id))
            .then((_) => loadRemoteData())
            .catchError(_captureError),
      );
    }
  }

  void _captureError(Object error) {
    errorMessage = error is AppFailure
        ? error.message
        : 'Không thể đồng bộ dữ liệu.';
    notifyListeners();
  }

  Future<String?> _categoryId(String name) async {
    final rows = await CategoryRepository(_client!).list();
    final match = rows.where((e) => e['name'] == name);
    return match.isEmpty ? null : match.first['id'].toString();
  }

  Map<String, dynamic> _productPayload(Product p, String? categoryId) {
    final dimensions = p.dimension
        .replaceAll(',', '.')
        .split(RegExp(r'[x×/]'))
        .map((value) => double.tryParse(value.trim()))
        .toList();
    return {
      'sku': p.sku,
      'name': p.name,
      'category_id': categoryId,
      'material': p.material,
      'unit': p.unit,
      'packaging_specification': p.note,
      'layer_count': p.layerCount,
      'dimension_unit': p.dimensionUnit,
      'description': p.description,
      'dimension_length': dimensions.isNotEmpty ? dimensions[0] : null,
      'dimension_width': dimensions.length > 1 ? dimensions[1] : null,
      'dimension_height': dimensions.length > 2 ? dimensions[2] : null,
      'purchase_price': p.purchasePrice,
      'selling_price': p.sellingPrice,
      'minimum_stock': p.minStock,
    };
  }

  Future<void> _createRemoteProduct(Product p) async {
    try {
      await ProductRepository(_client!)
          .create(_productPayload(p, await _categoryId(p.category)));
      await loadRemoteData();
    } catch (e) {
      _captureError(e);
    }
  }

  Future<void> _updateRemoteProduct(Product p) async {
    try {
      await ProductRepository(_client!)
          .update(p.id, _productPayload(p, await _categoryId(p.category)));
      await loadRemoteData();
    } catch (e) {
      _captureError(e);
    }
  }

  Future<void> _saveRemotePartner(Partner p) async {
    try {
      final row = {
        'code': 'DT-${DateTime.now().millisecondsSinceEpoch}',
        'name': p.name,
        'phone': p.phone,
        'email': p.email,
        'address': p.address,
        'tax_code': p.taxCode,
        'notes': p.note,
      };
      if (p.type == PartnerType.supplier) {
        await SupplierRepository(_client!).save(row);
      } else {
        await CustomerRepository(_client!).save(row);
      }
      await loadRemoteData();
    } catch (e) {
      _captureError(e);
    }
  }

  Future<String> defaultWarehouseId() async {
    final row = await _client!
        .from('warehouses')
        .select('id')
        .eq('is_active', true)
        .order('created_at')
        .order('id')
        .limit(1)
        .maybeSingle();
    if (row == null) {
      throw const AppFailure(
        'Chưa có kho đang hoạt động. Hãy cấu hình kho trước khi lập phiếu.',
      );
    }
    return row['id'].toString();
  }

  Future<void> saveAndMaybeConfirmRemote({
    DateTime? date,
    required bool inbound,
    required String partnerId,
    required List<LineItem> items,
    required double discount,
    required String note,
    required bool confirm,
  }) async {
    final warehouseId = await defaultWarehouseId();
    final payload = items
        .map(
          (e) => {
            'product_id': e.productId,
            'quantity': e.quantity,
            'requested_quantity': e.requestedQuantity,
            'actual_quantity': e.quantity,
            'unit_price': e.price,
          },
        )
        .toList();
    final result = inbound
        ? await InboundRepository(_client!).createDraftV2({
            'warehouse_id': warehouseId,
            'supplier_id': partnerId,
            'note': note,
            'items': payload,
          })
        : await OutboundRepository(_client!).createDraftV2({
            'voucher_date': (date ?? DateTime.now())
                .toIso8601String()
                .split('T')
                .first,
            'warehouse_id': warehouseId,
            'customer_id': partnerId,
            'note': note,
            'discount_amount': discount,
            'items': payload,
          });
    final id = result['id'].toString();
    if (confirm) {
      if (inbound) {
        await InboundRepository(_client).confirm(id);
      } else {
        await OutboundRepository(_client).confirm(id);
      }
    }
    await loadRemoteData();
  }

  Future<void> confirmRemoteDocument(StockDocument document) async {
    if (document.inbound) {
      await InboundRepository(_client!).confirm(document.id);
    } else {
      await OutboundRepository(_client!).confirm(document.id);
    }
    await loadRemoteData();
  }

  Future<String> addInvoiceRemote({
    required String customerId,
    required List<LineItem> items,
    String? sourceDocumentId,
    double discount = 0,
  }) async {
    final created = await InvoiceRepository(_client!).create(
      customerId: customerId,
      outboundVoucherId: sourceDocumentId,
      discount: discount,
      items: items
          .map(
            (e) => {
              'product_id': e.productId,
              'description': product(e.productId).name,
              'quantity': e.quantity,
              'unit_price': e.price,
            },
          )
          .toList(),
    );
    await loadRemoteData();
    return created['id'].toString();
  }

  /// Phát hành đúng một hóa đơn cho một phiếu xuất đã xác nhận.
  /// Gọi lại chỉ trả về hóa đơn đã có, không tạo chứng từ trùng.
  Future<Invoice> issueInvoiceForOutbound(StockDocument document) async {
    if (document.inbound || document.status != DocStatus.confirmed) {
      throw const AppFailure(
        'Chỉ phát hành hóa đơn từ phiếu xuất đã xác nhận.',
      );
    }
    Invoice? existing;
    for (final invoice in invoices) {
      if (invoice.sourceDocumentId == document.id) {
        existing = invoice;
        break;
      }
    }
    if (existing != null) {
      if (existing.draft) await finalizeInvoice(existing);
      return invoices.firstWhere((invoice) => invoice.id == existing!.id);
    }

    if (!isRemote) {
      final invoice = addInvoice(
        customerId: document.partnerId,
        items: document.items,
        sourceDocumentId: document.id,
      );
      invoice.draft = false;
      notifyListeners();
      return invoice;
    }

    final id = await addInvoiceRemote(
      customerId: document.partnerId,
      items: document.items,
      sourceDocumentId: document.id,
    );
    final draft = invoices.firstWhere((invoice) => invoice.id == id);
    await finalizeInvoice(draft);
    return invoices.firstWhere((invoice) => invoice.id == id);
  }

  Future<String> createSalesOrder({
    required String customerId,
    required List<LineItem> items,
    required String deliveryAddress,
    String note = '',
    double discount = 0,
  }) async {
    final created = await SalesOrderRepository(_client!).create(
      customerId: customerId,
      deliveryAddress: deliveryAddress,
      note: note,
      discount: discount,
      items: items
          .map(
            (item) => {
              'product_id': item.productId,
              'quantity': item.requestedQuantity,
              'unit_price': item.price,
            },
          )
          .toList(),
    );
    await loadRemoteData();
    return created['id'].toString();
  }

  Future<void> confirmSalesOrder(String id) async {
    await SalesOrderRepository(_client!).confirm(id);
    await loadRemoteData();
  }

  Future<void> removeSalesOrder(String id) async {
    final order = salesOrders.where((value) => value.id == id).firstOrNull;
    if (order == null) return;
    if (order.status != SalesOrderStatus.draft) {
      throw const AppFailure('Chỉ có thể xóa đơn bán hàng nháp.');
    }
    if (!isRemote) {
      salesOrders.remove(order);
      notifyListeners();
      return;
    }
    await SalesOrderRepository(_client!).removeDraft(id);
    await loadRemoteData();
  }

  Future<void> finalizeInvoice(Invoice invoice) async {
    if (!isRemote) {
      invoice.draft = false;
      notifyListeners();
      return;
    }
    await InvoiceRepository(_client!).finalize(invoice.id);
    await loadRemoteData();
  }

  Future<void> recordInvoicePayment({
    required Invoice invoice,
    required double amount,
    required String method,
    String? reference,
    String? note,
  }) async {
    if (amount <= 0) throw const AppFailure('Số tiền phải lớn hơn 0.');
    if (!isRemote) {
      invoice.paymentStatus = amount >= invoice.total
          ? PaymentStatus.paid
          : PaymentStatus.partial;
      notifyListeners();
      return;
    }
    await PaymentRepository(_client!).record(
      invoiceId: invoice.id,
      amount: amount,
      method: method,
      reference: reference,
      note: note,
    );
    await loadRemoteData();
  }

  Future<void> markInvoicePaid(Invoice invoice) async {
    if (invoice.draft) {
      throw const AppFailure(
        'Hóa đơn phải được phát hành trước khi thanh toán.',
      );
    }
    if (!isRemote) {
      invoice.paymentStatus = PaymentStatus.paid;
      notifyListeners();
      return;
    }
    await PaymentRepository(_client!).markPaid(invoice.id);
    await loadRemoteData();
  }

  Future<void> removeInvoice(Invoice invoice) async {
    if (!invoice.draft) throw const AppFailure('Chỉ có thể xóa hóa đơn nháp.');
    if (!isRemote) {
      deleteInvoice(invoice);
      return;
    }
    await InvoiceRepository(_client!).removeDraft(invoice.id);
    await loadRemoteData();
  }

  StockDocument saveDocument({
    DateTime? date,
    required bool inbound,
    required String partnerId,
    required List<LineItem> items,
    double discount = 0,
    bool confirm = false,
    String note = '',
  }) {
    final prefix = inbound ? 'PNK' : 'PXK';
    final doc = StockDocument(
      id: 'd${++_sequence}',
      code:
          '$prefix-${DateTime.now().year}-${_sequence.toString().padLeft(4, '0')}',
      inbound: inbound,
      date: date ?? DateTime.now(),
      partnerId: partnerId,
      items: items,
      discount: discount,
      note: note,
    );
    documents.insert(0, doc);
    if (confirm) confirmDocument(doc);
    notifyListeners();
    return doc;
  }

  String? confirmDocument(StockDocument doc) {
    if (doc.status == DocStatus.confirmed) return 'Phiếu này đã được xác nhận.';
    if (!doc.inbound) {
      for (final item in doc.items) {
        if (product(item.productId).stockQuantity < item.quantity) {
          return 'Tồn kho không đủ cho ${product(item.productId).name}.';
        }
      }
    }
    for (final item in doc.items) {
      final p = product(item.productId);
      p.stockQuantity += doc.inbound ? item.quantity : -item.quantity;
      movements.insert(
        0,
        Movement(
          id: 'm${++_sequence}',
          productId: p.id,
          code: doc.code,
          date: DateTime.now(),
          inbound: doc.inbound,
          quantity: item.quantity,
          balance: p.stockQuantity,
        ),
      );
    }
    doc.status = DocStatus.confirmed;
    notifyListeners();
    return null;
  }

  Invoice addInvoice({
    required String customerId,
    required List<LineItem> items,
    String? sourceDocumentId,
    double discount = 0,
  }) {
    final invoice = Invoice(
      id: 'i${++_sequence}',
      number:
          'HDNB-${DateTime.now().year}-${_sequence.toString().padLeft(4, '0')}',
      date: DateTime.now(),
      customerId: customerId,
      items: items,
      sourceDocumentId: sourceDocumentId,
      discount: discount,
    );
    invoices.insert(0, invoice);
    notifyListeners();
    return invoice;
  }

  void deleteInvoice(Invoice value) {
    if (value.draft) invoices.remove(value);
    notifyListeners();
  }

  void updateCompany() => notifyListeners();

  Future<void> saveCompany() async {
    if (!isRemote) {
      notifyListeners();
      return;
    }
    final bankParts = company.bank.split('•').map((e) => e.trim()).toList();
    final saved = await BusinessSettingsRepository(_client!).save(
      id: _businessSettingsId,
      value: {
        'business_name': company.name.trim(),
        'address': company.address.trim(),
        'phone': company.phone.trim(),
        'email': company.email.trim(),
        'bank_name': bankParts.firstOrNull ?? '',
        'bank_account_number': bankParts.length > 1 ? bankParts[1] : '',
        'company_short_name': company.shortName.trim(),
        'tax_code': company.taxCode.trim(),
        'website': company.website.trim(),
        'representative_name': company.representativeName.trim(),
        'default_currency': company.currency.trim().isEmpty
            ? 'VND'
            : company.currency.trim(),
        'invoice_footer': company.invoiceFooter.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    _businessSettingsId = saved['id']?.toString();
    notifyListeners();
  }

  void _seed() {
    const names = [
      [
        'Thùng carton 3 lớp 30x20x15',
        'Thùng carton',
        '30 × 20 × 15 cm',
        'Carton 3 lớp',
      ],
      [
        'Thùng carton 5 lớp 40x30x30',
        'Thùng carton',
        '40 × 30 × 30 cm',
        'Carton 5 lớp',
      ],
      ['Túi giấy kraft size M', 'Túi giấy', '25 × 32 × 11 cm', 'Giấy kraft'],
      ['Túi PE trong suốt', 'Túi nhựa', '30 × 40 cm', 'Nhựa PE'],
      ['Màng PE quấn pallet', 'Màng bọc', '50 cm × 2.4 kg', 'Nhựa PE'],
      [
        'Hộp carton nắp gài size S',
        'Hộp giấy',
        '20 × 15 × 8 cm',
        'Carton sóng E',
      ],
      [
        'Hộp carton nắp gài size L',
        'Hộp giấy',
        '35 × 25 × 12 cm',
        'Carton sóng E',
      ],
      ['Băng keo trong 100 yard', 'Phụ kiện', '48 mm × 100 yd', 'BOPP'],
      ['Băng keo đục 100 yard', 'Phụ kiện', '48 mm × 100 yd', 'BOPP'],
      ['Xốp hơi chống sốc khổ 1.2m', 'Chống sốc', '1.2 × 100 m', 'Nhựa PE'],
      ['Giấy tổ ong bọc hàng', 'Chống sốc', '40 cm × 50 m', 'Giấy kraft'],
      ['Túi zipper bạc size 18', 'Túi nhựa', '18 × 26 cm', 'PET/AL/PE'],
      ['Túi niêm phong giao hàng M', 'Túi nhựa', '28 × 35 cm', 'Nhựa PE'],
      ['Dây đai PP màu vàng', 'Phụ kiện', '15 mm × 10 kg', 'Nhựa PP'],
      ['Pallet nhựa xanh 1 mặt', 'Pallet', '110 × 110 cm', 'Nhựa HDPE'],
    ];
    for (var i = 0; i < names.length; i++) {
      products.add(
        Product(
          id: 'p$i',
          sku: 'BB-${(i + 1).toString().padLeft(4, '0')}',
          name: names[i][0],
          category: names[i][1],
          dimension: names[i][2],
          material: names[i][3],
          unit: i == 4
              ? 'cuộn'
              : i == 14
              ? 'cái'
              : 'đơn vị',
          purchasePrice: 4500 + i * 3700,
          sellingPrice: 6500 + i * 5100,
          stockQuantity: [
            420,
            85,
            18,
            0,
            32,
            120,
            76,
            240,
            9,
            54,
            33,
            61,
            145,
            14,
            22,
          ][i],
          minStock: [
            50,
            30,
            25,
            20,
            15,
            30,
            20,
            50,
            20,
            15,
            15,
            20,
            30,
            20,
            5,
          ][i],
        ),
      );
    }
    const customers = [
      'Công ty TNHH Minh Long',
      'Cửa hàng An Nhiên',
      'Công ty Thực phẩm Hương Việt',
      'Shop Hoa Mộc',
      'Nội thất Hòa Phát',
      'Công ty May Thành Công',
      'Điện máy Sao Việt',
      'Kho vận Tín Phát',
    ];
    const suppliers = [
      'Bao bì Đông Nam',
      'Giấy Kraft Việt',
      'Nhựa Phú Mỹ',
      'Carton Sài Gòn',
      'Vật tư Đại Phát',
    ];
    for (var i = 0; i < customers.length; i++) {
      partners.add(
        Partner(
          id: 'c$i',
          type: PartnerType.customer,
          name: customers[i],
          phone: '090${i + 2} 456 78$i ',
          address: '${12 + i * 7} Nguyễn Trãi, TP. Hồ Chí Minh',
          email: 'lienhe${i + 1}@doitac.vn',
        ),
      );
    }
    for (var i = 0; i < suppliers.length; i++) {
      partners.add(
        Partner(
          id: 's$i',
          type: PartnerType.supplier,
          name: suppliers[i],
          phone: '028 3765 88$i ',
          address: 'KCN Tân Bình, TP. Hồ Chí Minh',
          taxCode: '03123456$i',
        ),
      );
    }
    final now = DateTime.now();
    final d1 = StockDocument(
      id: 'seed1',
      code: 'PNK-2026-0098',
      inbound: true,
      date: now.subtract(const Duration(days: 3)),
      partnerId: 's0',
      items: [LineItem(productId: 'p0', quantity: 200, price: 4500)],
      status: DocStatus.confirmed,
    );
    final d2 = StockDocument(
      id: 'seed2',
      code: 'PXK-2026-0076',
      inbound: false,
      date: now.subtract(const Duration(days: 1)),
      partnerId: 'c0',
      items: [
        LineItem(productId: 'p0', quantity: 50, price: 6500),
        LineItem(productId: 'p1', quantity: 15, price: 11900),
      ],
      status: DocStatus.confirmed,
    );
    documents.addAll([d2, d1]);
    movements.addAll([
      Movement(
        id: 'm1',
        productId: 'p0',
        code: d2.code,
        date: d2.date,
        inbound: false,
        quantity: 50,
        balance: 420,
      ),
      Movement(
        id: 'm2',
        productId: 'p1',
        code: d2.code,
        date: d2.date,
        inbound: false,
        quantity: 15,
        balance: 85,
      ),
      Movement(
        id: 'm3',
        productId: 'p0',
        code: d1.code,
        date: d1.date,
        inbound: true,
        quantity: 200,
        balance: 470,
      ),
    ]);
    invoices.addAll([
      Invoice(
        id: 'i1',
        number: 'HDNB-2026-0088',
        date: now.subtract(const Duration(days: 1)),
        customerId: 'c0',
        items: [LineItem(productId: 'p0', quantity: 50, price: 6500)],
        sourceDocumentId: d2.id,
        paymentStatus: PaymentStatus.paid,
        draft: false,
      ),
      Invoice(
        id: 'i2',
        number: 'HDNB-2026-0089',
        date: now,
        customerId: 'c2',
        items: [LineItem(productId: 'p4', quantity: 4, price: 26900)],
      ),
    ]);
  }
}
