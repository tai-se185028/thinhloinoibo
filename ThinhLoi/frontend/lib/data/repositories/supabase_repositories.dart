import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AppFailure implements Exception {
  const AppFailure(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

abstract class SupabaseRepository {
  SupabaseRepository(this.client);
  final SupabaseClient client;
  Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw AppFailure(_databaseMessage(e), e);
    } on StorageException catch (e) {
      throw AppFailure('Không thể xử lý tệp: ${e.message}', e);
    } on AuthException catch (e) {
      throw AppFailure('Phiên đăng nhập không hợp lệ: ${e.message}', e);
    } catch (e) {
      throw AppFailure('Không thể kết nối máy chủ. Vui lòng thử lại.', e);
    }
  }

  String _databaseMessage(PostgrestException e) {
    if (e.code == '23505') return 'Mã dữ liệu đã tồn tại.';
    if (e.code == '23503') {
      return 'Không thể thay đổi dữ liệu đang được sử dụng.';
    }
    if (e.code == '42501') return 'Bạn không có quyền thực hiện thao tác này.';
    if (e.message.contains('INSUFFICIENT_STOCK')) {
      return 'Tồn kho không đủ để xác nhận phiếu xuất.';
    }
    if (e.message.contains('ALREADY_CONFIRMED')) {
      return 'Phiếu này đã được xác nhận trước đó.';
    }
    return 'Lỗi dữ liệu: ${e.message}';
  }
}

class AuthRepository extends SupabaseRepository {
  AuthRepository(super.client);
  Session? get session => client.auth.currentSession;
  Stream<AuthState> get changes => client.auth.onAuthStateChange;
  Future<void> signIn(String email, String password) => guard(() async {
    await client.auth.signInWithPassword(email: email, password: password);
  });
  Future<void> signOut() => guard(client.auth.signOut);
  Future<Map<String, dynamic>?> profile() => guard(
    () async => await client
        .from('profiles')
        .select()
        .eq('id', client.auth.currentUser!.id)
        .maybeSingle(),
  );
}

class ProductRepository extends SupabaseRepository {
  ProductRepository(super.client);
  Future<List<Map<String, dynamic>>> list({
    String search = '',
    String? categoryId,
    int page = 0,
    int pageSize = 50,
  }) => guard(() async {
    var query = client.from('product_stock_view').select();
    if (search.isNotEmpty) {
      query = query.or('name.ilike.%$search%,sku.ilike.%$search%');
    }
    if (categoryId != null) query = query.eq('category_id', categoryId);
    return List<Map<String, dynamic>>.from(
      await query
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .order('name'),
    );
  });
  Future<Map<String, dynamic>> create(Map<String, dynamic> value) => guard(
    () async => await client.from('products').insert(value).select().single(),
  );
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> value) =>
      guard(
        () async => await client
            .from('products')
            .update(value)
            .eq('id', id)
            .select()
            .single(),
      );
  Future<void> deactivate(String id) => guard(() async {
    await client.from('products').update({'is_active': false}).eq('id', id);
  });
}

class CategoryRepository extends SupabaseRepository {
  CategoryRepository(super.client);
  Future<List<Map<String, dynamic>>> list() => guard(
    () async => List<Map<String, dynamic>>.from(
      await client.from('categories').select().order('name'),
    ),
  );
}

class CustomerRepository extends SupabaseRepository {
  CustomerRepository(super.client);
  Future<List<Map<String, dynamic>>> list() => guard(
    () async => List<Map<String, dynamic>>.from(
      await client.from('customers').select().order('name'),
    ),
  );
  Future<Map<String, dynamic>> save(Map<String, dynamic> row) => guard(
    () async => await client.from('customers').upsert(row).select().single(),
  );
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> row) =>
      guard(
        () async => await client
            .from('customers')
            .update(row)
            .eq('id', id)
            .select()
            .single(),
      );
  Future<void> remove(String id) => guard(() async {
    await client.from('customers').delete().eq('id', id);
  });
}

class SupplierRepository extends SupabaseRepository {
  SupplierRepository(super.client);
  Future<List<Map<String, dynamic>>> list() => guard(
    () async => List<Map<String, dynamic>>.from(
      await client.from('suppliers').select().order('name'),
    ),
  );
  Future<Map<String, dynamic>> save(Map<String, dynamic> row) => guard(
    () async => await client.from('suppliers').upsert(row).select().single(),
  );
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> row) =>
      guard(
        () async => await client
            .from('suppliers')
            .update(row)
            .eq('id', id)
            .select()
            .single(),
      );
  Future<void> remove(String id) => guard(() async {
    await client.from('suppliers').delete().eq('id', id);
  });
}

class InventoryRepository extends SupabaseRepository {
  InventoryRepository(super.client);
  Future<List<Map<String, dynamic>>> balances() => guard(
    () async => List<Map<String, dynamic>>.from(
      await client
          .from('inventory_balance_view')
          .select()
          .order('product_name'),
    ),
  );
  Future<List<Map<String, dynamic>>> movements({int limit = 100}) => guard(
    () async => List<Map<String, dynamic>>.from(
      await client
          .from('stock_movements')
          .select('*, products(name,sku)')
          .order('created_at', ascending: false)
          .limit(limit),
    ),
  );
}

class InboundRepository extends SupabaseRepository {
  InboundRepository(super.client);
  Future<List<Map<String, dynamic>>> list() => guard(
    () async => List<Map<String, dynamic>>.from(
      await client
          .from('inbound_vouchers')
          .select('*, inbound_items(*)')
          .order('created_at', ascending: false),
    ),
  );
  Future<Map<String, dynamic>> createDraft({
    required String warehouseId,
    required String supplierId,
    required String note,
    required List<Map<String, dynamic>> items,
  }) => guard(() async {
    final result = await client.rpc(
      'create_inbound_draft',
      params: {
        'p_warehouse_id': warehouseId,
        'p_supplier_id': supplierId,
        'p_note': note,
        'p_items': items,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  });
  Future<void> confirm(String id) => guard(() async {
    await client.rpc('confirm_inbound_voucher', params: {'p_voucher_id': id});
  });
  Future<Map<String, dynamic>> createDraftV2(Map<String, dynamic> payload) =>
      guard(() async {
        try {
          return Map<String, dynamic>.from(
            await client.rpc(
              'create_inbound_draft_v2',
              params: {'p_payload': payload},
            ) as Map,
          );
        } on PostgrestException catch (error) {
          if (error.code != 'PGRST202') rethrow;
          return Map<String, dynamic>.from(
            await client.rpc(
              'create_inbound_draft',
              params: {
                'p_warehouse_id': payload['warehouse_id'],
                'p_supplier_id': payload['supplier_id'],
                'p_note': payload['note'],
                'p_items': payload['items'],
              },
            ) as Map,
          );
        }
      });
}

class OutboundRepository extends SupabaseRepository {
  OutboundRepository(super.client);
  Future<List<Map<String, dynamic>>> list() => guard(
    () async => List<Map<String, dynamic>>.from(
      await client
          .from('outbound_vouchers')
          .select('*, outbound_items(*)')
          .order('created_at', ascending: false),
    ),
  );
  Future<Map<String, dynamic>> createDraft({
    required String warehouseId,
    required String customerId,
    required String note,
    required num discount,
    required List<Map<String, dynamic>> items,
  }) => guard(() async {
    final result = await client.rpc(
      'create_outbound_draft',
      params: {
        'p_warehouse_id': warehouseId,
        'p_customer_id': customerId,
        'p_note': note,
        'p_discount_amount': discount,
        'p_items': items,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  });
  Future<void> confirm(String id) => guard(() async {
    await client.rpc('confirm_outbound_voucher', params: {'p_voucher_id': id});
  });
  Future<Map<String, dynamic>> createDraftV2(Map<String, dynamic> payload) =>
      guard(() async {
        try {
          return Map<String, dynamic>.from(
            await client.rpc(
              'create_outbound_draft_v2',
              params: {'p_payload': payload},
            ) as Map,
          );
        } on PostgrestException catch (error) {
          if (error.code != 'PGRST202') rethrow;
          return Map<String, dynamic>.from(
            await client.rpc(
              'create_outbound_draft',
              params: {
                'p_warehouse_id': payload['warehouse_id'],
                'p_customer_id': payload['customer_id'],
                'p_note': payload['note'],
                'p_discount_amount': payload['discount_amount'],
                'p_items': payload['items'],
              },
            ) as Map,
          );
        }
      });
}

class SalesOrderRepository extends SupabaseRepository {
  SalesOrderRepository(super.client);
  Future<List<Map<String, dynamic>>> list() async {
    try {
      return List<Map<String, dynamic>>.from(
        await client
            .from('sales_orders')
            .select('*, sales_order_items(*)')
            .order('order_date', ascending: false),
      );
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') return const [];
      throw AppFailure('Không thể tải đơn bán hàng: ${error.message}', error);
    }
  }

  Future<Map<String, dynamic>> create({
    required String customerId,
    DateTime? expectedDeliveryDate,
    required String deliveryAddress,
    required String note,
    required num discount,
    required List<Map<String, dynamic>> items,
  }) => guard(
    () async => Map<String, dynamic>.from(
      await client.rpc(
        'create_sales_order_draft',
        params: {
          'p_customer_id': customerId,
          'p_expected_delivery_date': expectedDeliveryDate
              ?.toIso8601String()
              .split('T')
              .first,
          'p_delivery_address': deliveryAddress,
          'p_note': note,
          'p_discount_amount': discount,
          'p_items': items,
        },
      ) as Map,
    ),
  );
  Future<void> confirm(String id) => guard(() async {
    await client.rpc('confirm_sales_order', params: {'p_sales_order_id': id});
  });
  Future<void> removeDraft(String id) => guard(() async {
    await client.rpc(
      'delete_sales_order_draft',
      params: {'p_sales_order_id': id},
    );
  });
}

class InvoiceRepository extends SupabaseRepository {
  InvoiceRepository(super.client);
  Future<List<Map<String, dynamic>>> list() => guard(
    () async => List<Map<String, dynamic>>.from(
      await client
          .from('invoices')
          .select('*, customers(name), invoice_items(*)')
          .order('invoice_date', ascending: false),
    ),
  );
  Future<Map<String, dynamic>> create({
    required String customerId,
    String? outboundVoucherId,
    required num discount,
    required List<Map<String, dynamic>> items,
  }) => guard(() async {
    final result = await client.rpc(
      'create_invoice_draft',
      params: {
        'p_customer_id': customerId,
        'p_outbound_voucher_id': outboundVoucherId,
        'p_discount_amount': discount,
        'p_items': items,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  });
  Future<void> finalize(String id) => guard(() async {
    await client.rpc('finalize_invoice', params: {'p_invoice_id': id});
  });
  Future<void> removeDraft(String id) => guard(() async {
    await client.from('invoices').delete().eq('id', id).eq('status', 'draft');
  });
}

class BusinessSettingsRepository extends SupabaseRepository {
  BusinessSettingsRepository(super.client);

  Future<Map<String, dynamic>?> get() => guard(
    () async =>
        await client.from('business_settings').select().limit(1).maybeSingle(),
  );

  Future<Map<String, dynamic>> save({
    String? id,
    required Map<String, dynamic> value,
  }) => guard(() async {
    if (id == null) {
      return await client
          .from('business_settings')
          .insert(value)
          .select()
          .single();
    }
    return await client
        .from('business_settings')
        .update(value)
        .eq('id', id)
        .select()
        .single();
  });
}

class PaymentRepository extends SupabaseRepository {
  PaymentRepository(super.client);
  Future<void> markPaid(String invoiceId) => guard(() async {
    await client.rpc(
      'mark_invoice_paid',
      params: {'p_invoice_id': invoiceId, 'p_payment_method': 'bank_transfer'},
    );
  });

  Future<void> record({
    required String invoiceId,
    required num amount,
    required String method,
    String? reference,
    String? note,
  }) => guard(() async {
    await client.rpc(
      'record_invoice_payment',
      params: {
        'p_invoice_id': invoiceId,
        'p_amount': amount,
        'p_payment_method': method,
        'p_reference_number': reference,
        'p_note': note,
      },
    );
  });
}

class ReportRepository extends SupabaseRepository {
  ReportRepository(super.client);
  Future<Map<String, dynamic>> dashboard() => guard(
    () async =>
        Map<String, dynamic>.from(await client.rpc('dashboard_summary') as Map),
  );
}

class StorageRepository extends SupabaseRepository {
  StorageRepository(super.client);
  static const allowedBuckets = {
    'product-images',
    'invoice-documents',
    'purchase-documents',
    'company-assets',
  };
  Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) => guard(() async {
    if (!allowedBuckets.contains(bucket)) {
      throw const AppFailure('Kho lưu trữ không hợp lệ.');
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw const AppFailure('Tệp không được vượt quá 10 MB.');
    }
    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    return path;
  });
  Future<String> signedUrl(String bucket, String path) =>
      guard(() => client.storage.from(bucket).createSignedUrl(path, 300));
}
