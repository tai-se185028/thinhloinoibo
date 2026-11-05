import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';

class SalesOrdersScreen extends StatelessWidget {
  const SalesOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn bán hàng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/sales-orders/new'),
        icon: const Icon(Icons.add),
        label: const Text('Tạo đơn'),
      ),
      body: store.salesOrders.isEmpty
          ? const Center(child: Text('Chưa có đơn bán hàng.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: store.salesOrders.length,
              itemBuilder: (context, index) {
                final order = store.salesOrders[index];
                final remaining =
                    order.orderedQuantity - order.fulfilledQuantity;
                return Card(
                  child: ListTile(
                    title: Text(order.code),
                    subtitle: Text(
                      '${store.partner(order.customerId).name}\nĐã xuất ${order.fulfilledQuantity}/${order.orderedQuantity} • Còn $remaining',
                    ),
                    isThreeLine: true,
                    trailing: order.status == SalesOrderStatus.draft
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Xóa đơn nháp',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(context, store, order),
                              ),
                              FilledButton.tonal(
                                onPressed: () async {
                                  try {
                                    await store.confirmSalesOrder(order.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Đã xác nhận đơn hàng.',
                                              ),
                                            ),
                                          );
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(error.toString()),
                                            ),
                                          );
                                    }
                                  }
                                },
                                child: const Text('Xác nhận'),
                              ),
                            ],
                          )
                        : Text(_status(order.status)),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppStore store,
    SalesOrder order,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa đơn bán hàng nháp?'),
        content: Text('Dữ liệu ${order.code} sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa đơn'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      await store.removeSalesOrder(order.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa đơn bán hàng nháp.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  String _status(SalesOrderStatus status) => switch (status) {
    SalesOrderStatus.confirmed => 'Đã xác nhận',
    SalesOrderStatus.partiallyFulfilled => 'Xuất một phần',
    SalesOrderStatus.fulfilled => 'Hoàn tất',
    SalesOrderStatus.cancelled => 'Đã hủy',
    SalesOrderStatus.draft => 'Bản nháp',
  };
}

class SalesOrderFormScreen extends StatefulWidget {
  const SalesOrderFormScreen({super.key});
  @override
  State<SalesOrderFormScreen> createState() => _SalesOrderFormScreenState();
}

class _SalesOrderFormScreenState extends State<SalesOrderFormScreen> {
  String? customerId;
  final deliveryAddress = TextEditingController();
  final note = TextEditingController();
  final items = <LineItem>[];
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final customers = store.partnersOf(PartnerType.customer);
    customerId ??= customers.firstOrNull?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo đơn bán hàng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: customerId,
            decoration: const InputDecoration(labelText: 'Khách hàng *'),
            items: customers
                .map(
                  (customer) => DropdownMenuItem(
                    value: customer.id,
                    child: Text(customer.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                customerId = value;
                deliveryAddress.text =
                    store.partner(value!).deliveryAddress.isNotEmpty
                    ? store.partner(value).deliveryAddress
                    : store.partner(value).address;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: deliveryAddress,
            decoration: const InputDecoration(labelText: 'Địa chỉ giao hàng'),
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            final product = store.product(item.productId);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => items.removeAt(entry.key)),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Text(
                      '${product.sku} • ${product.dimension} ${product.dimensionUnit}',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: item.requestedQuantity.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số lượng đặt',
                            ),
                            onChanged: (value) => item.requestedQuantity =
                                int.tryParse(value) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: item.price.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Đơn giá',
                            ),
                            onChanged: (value) =>
                                item.price = double.tryParse(value) ?? 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => _pickProduct(store),
            icon: const Icon(Icons.add),
            label: const Text('Thêm sản phẩm'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : () => _save(store),
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Lưu đơn hàng'),
          ),
        ],
      ),
    );
  }

  void _pickProduct(AppStore store) => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => ListView(
      children: store.products
          .map(
            (product) => ListTile(
              title: Text(product.name),
              subtitle: Text(
                '${product.sku} • Tồn ${product.stockQuantity} ${product.unit}',
              ),
              onTap: () {
                setState(
                  () => items.add(
                    LineItem(
                      productId: product.id,
                      quantity: 1,
                      requestedQuantity: 1,
                      price: product.sellingPrice,
                    ),
                  ),
                );
                Navigator.pop(sheet);
              },
            ),
          )
          .toList(),
    ),
  );

  Future<void> _save(AppStore store) async {
    if (customerId == null ||
        items.isEmpty ||
        items.any((item) => item.requestedQuantity <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn khách hàng và nhập số lượng hợp lệ.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await store.createSalesOrder(
        customerId: customerId!,
        items: items,
        deliveryAddress: deliveryAddress.text.trim(),
        note: note.text.trim(),
      );
      if (mounted) context.go('/sales-orders');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
