import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/google_account.dart';

import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/formatters.dart';
import '../core/widgets.dart';
import '../data/app_store.dart';
import '../models/models.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final low = s.products
        .where((e) => e.status != StockStatus.inStock)
        .toList();
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Xin chào, Minh 👋',
              subtitle: longDate(DateTime.now()),
              action: const CircleAvatar(
                backgroundColor: Color(0xFFDBEAFE),
                child: Text(
                  'MT',
                  style: TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.45,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildListDelegate([
                _Kpi(
                  'Tổng sản phẩm',
                  '${s.products.length}',
                  Icons.inventory_2_rounded,
                  const Color(0xFF2563EB),
                ),
                _Kpi(
                  'Tồn kho',
                  '${s.stockUnits}',
                  Icons.warehouse_rounded,
                  const Color(0xFF0D9488),
                ),
                _Kpi(
                  'Nhập tháng này',
                  money(s.inboundValue),
                  Icons.south_west_rounded,
                  const Color(0xFF16A34A),
                ),
                _Kpi(
                  'Xuất tháng này',
                  money(s.outboundValue),
                  Icons.north_east_rounded,
                  const Color(0xFF7C3AED),
                ),
                _Kpi(
                  'Doanh thu',
                  money(s.invoices.fold(0, (v, e) => v + e.total)),
                  Icons.payments_rounded,
                  const Color(0xFF0284C7),
                ),
                _Kpi(
                  'Hàng sắp hết',
                  '${low.length}',
                  Icons.warning_amber_rounded,
                  const Color(0xFFF59E0B),
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SectionTitle('Thao tác nhanh')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Quick(
                    Icons.move_to_inbox_rounded,
                    'Nhập sản phẩm',
                    () => context.go('/products/new'),
                  ),
                  _Quick(
                    Icons.outbox_rounded,
                    'Xuất kho',
                    () => context.go('/outbound'),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionTitle('Xu hướng 6 tháng')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(height: 130, child: _MiniChart()),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionTitle(
              'Cảnh báo tồn kho',
              trailing: Text(
                '${low.length} mặt hàng',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: low.take(4).length,
            itemBuilder: (context, i) {
              final p = low[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    title: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${p.sku} • Tối thiểu ${p.minStock} ${p.unit}',
                    ),
                    trailing: StatusPill.stock(p.status),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SectionTitle('Hoạt động gần đây')),
          SliverList.builder(
            itemCount: s.movements.take(5).length,
            itemBuilder: (context, i) {
              final m = s.movements[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: CircleAvatar(
                  backgroundColor: (m.inbound
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFEDE9FE)),
                  child: Icon(
                    m.inbound ? Icons.south_west : Icons.north_east,
                    color: m.inbound
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF7C3AED),
                  ),
                ),
                title: Text(
                  s.product(m.productId).name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${m.code} • ${shortDate(m.date)}'),
                trailing: Text(
                  '${m.inbound ? '+' : '-'}${m.quantity}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: m.inbound
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF2563EB)),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MiniChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(
        6,
        (i) => Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 13,
                  height: 35.0 + i * 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFF93C5FD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 3),
                Container(
                  width: 13,
                  height: 60.0 + (5 - i) * 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'T${i + 5}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String q = '', category = 'Tất cả', status = 'Tất cả';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final categories = [
      'Tất cả',
      ...{for (final p in s.products) p.category},
    ];
    final list = s.products
        .where(
          (p) =>
              (p.name.toLowerCase().contains(q.toLowerCase()) ||
                  p.sku.toLowerCase().contains(q.toLowerCase())) &&
              (category == 'Tất cả' || p.category == category) &&
              (status == 'Tất cả' ||
                  (status == 'Sắp hết' && p.status == StockStatus.low) ||
                  (status == 'Hết hàng' && p.status == StockStatus.out) ||
                  (status == 'Còn hàng' && p.status == StockStatus.inStock)),
        )
        .toList();
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            PageHeader(
              title: 'Nhập sản phẩm',
              subtitle: '${s.products.length} mặt hàng',
              action: IconButton.filled(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm tên sản phẩm hoặc SKU...',
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                children: [
                  ...categories.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(e),
                        selected: category == e,
                        onSelected: (_) => setState(() => category = e),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    initialValue: status,
                    onSelected: (v) => setState(() => status = v),
                    itemBuilder: (_) =>
                        ['Tất cả', 'Còn hàng', 'Sắp hết', 'Hết hàng']
                            .map((e) => PopupMenuItem(value: e, child: Text(e)))
                            .toList(),
                    child: Chip(
                      avatar: const Icon(Icons.tune, size: 18),
                      label: Text(status),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Không tìm thấy sản phẩm',
                      message: 'Hãy thử từ khóa hoặc bộ lọc khác.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: list.length,
                      itemBuilder: (context, i) =>
                          _ProductCard(list[i], onEdit: () => _edit(list[i])),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit([Product? p]) async {
    context.go(
      p == null
          ? '/products/new'
          : '/products/${Uri.encodeComponent(p.id)}/edit',
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(this.p, {required this.onEdit});
  final Product p;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go('/products/${Uri.encodeComponent(p.id)}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${p.sku} • ${p.dimension}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Text(
                        '${p.stockQuantity} ${p.unit}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        money(p.sellingPrice),
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StatusPill.stock(p.status),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.add),
                        label: const Text('Nhập thêm'),
                      ),
                      TextButton.icon(
                        onPressed: p.stockQuantity > 0
                            ? () => context.go(
                                '/outbound/new?productId=${Uri.encodeComponent(p.id)}',
                              )
                            : null,
                        icon: const Icon(Icons.outbox_outlined),
                        label: const Text('Xuất kho'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: p.stockQuantity > 0,
                  onTap: () => context.go(
                    '/outbound/new?productId=${Uri.encodeComponent(p.id)}',
                  ),
                  child: const ListTile(
                    leading: Icon(Icons.outbox_outlined),
                    title: Text('Xuất kho'),
                  ),
                ),
                PopupMenuItem(
                  onTap: onEdit,
                  child: const ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Nhập thêm / Chỉnh sửa'),
                  ),
                ),
                PopupMenuItem(
                  onTap: () => _delete(context),
                  child: const ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                    ),
                    title: Text(
                      'Xóa',
                      style: TextStyle(color: Color(0xFFDC2626)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  void _delete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Xóa sản phẩm?'),
        content: Text('Bạn chắc chắn muốn xóa “${p.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () async {
              try {
                await context.read<AppStore>().removeProduct(p.id);
                if (!context.mounted) return;
                Navigator.pop(dialog);
                toast(context, 'Đã xóa sản phẩm.');
              } catch (error) {
                if (context.mounted) {
                  toast(context, error.toString(), error: true);
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen(this.p, {super.key});
  final Product p;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 54,
              color: Color(0xFF2563EB),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          p.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Center(child: StatusPill.stock(p.status)),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              _Info('SKU', p.sku),
              _Info('Danh mục', p.category),
              _Info('Kích thước', p.dimension),
              _Info('Chất liệu', p.material),
              _Info('Đơn vị', p.unit),
              _Info('Tồn kho', '${p.stockQuantity} ${p.unit}'),
              _Info('Tồn tối thiểu', '${p.minStock} ${p.unit}'),
              _Info('Giá nhập', money(p.purchasePrice)),
              _Info('Giá bán', money(p.sellingPrice)),
              if (p.note.isNotEmpty) _Info('Ghi chú', p.note),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.a, this.b);
  final String a, b;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(a, style: const TextStyle(color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            b,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  bool saving = false;
  final key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> c;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    c = {
      'name': TextEditingController(text: p?.name),
      'sku': TextEditingController(
        text:
            p?.sku ??
            'BB-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      ),
      'category': TextEditingController(text: p?.category ?? 'Thùng carton'),
      'dimension': TextEditingController(text: p?.dimension),
      'material': TextEditingController(text: p?.material),
      'layers': TextEditingController(text: p?.layerCount?.toString()),
      'dimensionUnit': TextEditingController(text: p?.dimensionUnit ?? 'cm'),
      'unit': TextEditingController(text: p?.unit ?? 'đơn vị'),
      'buy': TextEditingController(text: p?.purchasePrice.toStringAsFixed(0)),
      'sell': TextEditingController(text: p?.sellingPrice.toStringAsFixed(0)),
      'stock': TextEditingController(text: p == null ? '1' : '0'),
      'min': TextEditingController(text: p?.minStock.toString() ?? '10'),
      'note': TextEditingController(text: p?.note),
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.product == null ? 'Nhập sản phẩm' : 'Nhập thêm / Sửa sản phẩm',
      ),
    ),
    body: Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field('Tên sản phẩm *', 'name'),
          _field('Mã SKU *', 'sku'),
          _field('Danh mục *', 'category'),
          _field('Kích thước', 'dimension'),
          Row(
            children: [
              Expanded(child: _field('Số lớp', 'layers', number: true)),
              const SizedBox(width: 10),
              Expanded(child: _field('Đơn vị kích thước', 'dimensionUnit')),
            ],
          ),
          _field('Chất liệu', 'material'),
          _field('Đơn vị tính *', 'unit'),
          Row(
            children: [
              Expanded(child: _field('Giá nhập', 'buy', number: true)),
              const SizedBox(width: 10),
              Expanded(child: _field('Giá bán', 'sell', number: true)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _field(
                  widget.product == null
                      ? 'Số lượng nhập *'
                      : 'Số lượng nhập thêm',
                  'stock',
                  number: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _field('Tồn tối thiểu', 'min', number: true)),
            ],
          ),
          _field('Ghi chú', 'note', lines: 3),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              saving ? 'Đang lưu...' : 'Lưu sản phẩm và số lượng nhập',
            ),
          ),
        ],
      ),
    ),
  );
  Widget _field(
    String label,
    String name, {
    bool number = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c[name],
      maxLines: lines,
      keyboardType: number ? TextInputType.number : null,
      decoration: InputDecoration(labelText: label),
      validator: (v) => label.contains('*') && (v == null || v.trim().isEmpty)
          ? 'Vui lòng nhập ${label.replaceAll(' *', '').toLowerCase()}.'
          : null,
    ),
  );
  Future<void> _save() async {
    if (!key.currentState!.validate()) return;
    final old = widget.product;
    final received = int.tryParse(c['stock']!.text);
    if (received == null || received < 0 || (old == null && received == 0)) {
      toast(
        context,
        'Số lượng nhập phải là số nguyên dương (sửa thông tin có thể nhập 0).',
        error: true,
      );
      return;
    }
    if (saving) return;
    setState(() => saving = true);
    final p = Product(
      id: old?.id ?? 'p${DateTime.now().microsecondsSinceEpoch}',
      sku: '',
      name: '',
      category: '',
      dimension: '',
      material: '',
      unit: '',
      purchasePrice: 0,
      sellingPrice: 0,
      stockQuantity: 0,
      minStock: 0,
    );
    p.name = c['name']!.text;
    p.sku = c['sku']!.text;
    p.category = c['category']!.text;
    p.dimension = c['dimension']!.text;
    p.material = c['material']!.text;
    p.layerCount = int.tryParse(c['layers']!.text);
    p.dimensionUnit = c['dimensionUnit']!.text.trim().isEmpty
        ? 'cm'
        : c['dimensionUnit']!.text.trim();
    p.unit = c['unit']!.text;
    p.purchasePrice = double.tryParse(c['buy']!.text) ?? 0;
    p.sellingPrice = double.tryParse(c['sell']!.text) ?? 0;
    p.stockQuantity = old?.stockQuantity ?? received;
    p.minStock = int.tryParse(c['min']!.text) ?? 0;
    p.note = c['note']!.text;
    final store = context.read<AppStore>();
    try {
      await store.saveProduct(
        p,
        isNew: old == null,
        receivedQuantity: old == null ? 0 : received,
      );
      if (!mounted) return;
      context.go('/products');
      toast(
        context,
        old == null ? 'Đã thêm sản phẩm.' : 'Đã cập nhật sản phẩm.',
      );
    } catch (error) {
      if (mounted) toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool history = false;
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return SafeArea(
      child: Column(
        children: [
          const PageHeader(
            title: 'Kho hàng',
            subtitle: 'Theo dõi tồn kho và biến động',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Tồn kho'),
                  icon: Icon(Icons.inventory),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Lịch sử'),
                  icon: Icon(Icons.history),
                ),
              ],
              selected: {history},
              onSelectionChanged: (v) => setState(() => history = v.first),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm sản phẩm...',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: history ? _history(s) : _stock(s)),
        ],
      ),
    );
  }

  Widget _stock(AppStore s) {
    final list = s.products
        .where(
          (e) =>
              e.name.toLowerCase().contains(q.toLowerCase()) ||
              e.sku.toLowerCase().contains(q.toLowerCase()),
        )
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final p = list[i];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEFF6FF),
              child: Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB)),
            ),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${p.sku} • Tối thiểu ${p.minStock} ${p.unit}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${p.stockQuantity} ${p.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                StatusPill.stock(p.status),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _history(AppStore s) {
    final list = s.movements
        .where(
          (e) =>
              s
                  .product(e.productId)
                  .name
                  .toLowerCase()
                  .contains(q.toLowerCase()) ||
              e.code.toLowerCase().contains(q.toLowerCase()),
        )
        .toList();
    return list.isEmpty
        ? const EmptyState(
            icon: Icons.history,
            title: 'Chưa có biến động',
            message: 'Lịch sử nhập xuất sẽ xuất hiện tại đây.',
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final m = list[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (m.inbound
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2)),
                    child: Icon(
                      m.inbound ? Icons.south_west : Icons.north_east,
                      color: m.inbound
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  title: Text(s.product(m.productId).name),
                  subtitle: Text(
                    '${m.code} • ${shortDate(m.date)}\nSố dư sau giao dịch: ${m.balance}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '${m.inbound ? '+' : '-'}${m.quantity}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: m.inbound
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              );
            },
          );
  }
}

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key, required this.inbound});
  final bool inbound;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final list = s.documents.where((e) => e.inbound == inbound).toList();
    return Scaffold(
      appBar: AppBar(title: Text(inbound ? 'Nhập kho' : 'Xuất kho')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(inbound ? '/inbound/new' : '/outbound/new'),
        icon: const Icon(Icons.add),
        label: Text(inbound ? 'Tạo phiếu nhập' : 'Tạo phiếu xuất'),
      ),
      body: list.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Chưa có phiếu',
              message: 'Tạo phiếu đầu tiên để bắt đầu.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final d = list[i];
                return Card(
                  child: InkWell(
                    onTap: () => context.go(
                      '/${inbound ? 'inbound' : 'outbound'}/${Uri.encodeComponent(d.id)}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              StatusPill(
                                d.status == DocStatus.confirmed
                                    ? 'Đã xác nhận'
                                    : 'Bản nháp',
                                d.status == DocStatus.confirmed
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF64748B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                inbound
                                    ? Icons.factory_outlined
                                    : Icons.store_outlined,
                                size: 18,
                                color: const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(s.partner(d.partnerId).name),
                              ),
                              Text(shortDate(d.date)),
                            ],
                          ),
                          const Divider(height: 22),
                          Row(
                            children: [
                              Text('${d.items.length} mặt hàng'),
                              const Spacer(),
                              Text(
                                money(d.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class DocumentFormScreen extends StatefulWidget {
  const DocumentFormScreen({super.key, required this.inbound, this.productId});
  final bool inbound;
  final String? productId;
  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  DateTime voucherDate = DateUtils.dateOnly(DateTime.now());
  bool initialized = false;
  String? partnerId;
  final items = <LineItem>[];
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    if (!initialized) {
      initialized = true;
      final product = s.productOrNull(widget.productId ?? '');
      if (product != null && product.stockQuantity > 0) {
        items.add(
          LineItem(
            productId: product.id,
            quantity: 1,
            price: product.sellingPrice,
          ),
        );
      }
    }
    final partners = s.partnersOf(
      widget.inbound ? PartnerType.supplier : PartnerType.customer,
    );
    partnerId ??= partners.firstOrNull?.id;
    final total = items.fold<double>(0, (v, e) => v + e.total);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.inbound ? 'Tạo phiếu nhập kho' : 'Tạo phiếu xuất kho',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (partners.isEmpty)
            EmptyState(
              icon: widget.inbound
                  ? Icons.factory_outlined
                  : Icons.people_outline,
              title: widget.inbound
                  ? 'Chưa có nhà cung cấp'
                  : 'Chưa có khách hàng',
              message: 'Hãy thêm đối tác trước khi lập phiếu.',
              action: FilledButton(
                onPressed: () => context.go('/partners'),
                child: const Text('Mở danh sách đối tác'),
              ),
            ),
          Text(
            'Thông tin phiếu',
            style: Theme.of(context).textTheme.titleMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: partnerId,
            decoration: InputDecoration(
              labelText: widget.inbound ? 'Nhà cung cấp *' : 'Khách hàng *',
            ),
            items: partners
                .map(
                  (e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => partnerId = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(voucherDate),
            initialValue: shortDate(voucherDate),
            readOnly: true,
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: voucherDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100, 12, 31),
                helpText: 'Chọn ngày xuất kho',
                cancelText: 'Hủy',
                confirmText: 'Chọn',
              );
              if (selected != null && mounted) {
                setState(() => voucherDate = selected);
              }
            },
            decoration: const InputDecoration(
              labelText: 'Ngày xuất kho',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
          ),
          const SectionTitle('Sản phẩm'),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Chưa có sản phẩm',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          ...items.asMap().entries.map((entry) {
            final item = entry.value, p = s.product(item.productId);
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
                            p.name,
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
                      'Mã hàng: ${p.sku} • Kích thước: ${p.dimension} ${p.dimensionUnit}${widget.inbound ? '' : ' • Tồn ${p.stockQuantity} ${p.unit}'}',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: item.quantity.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số lượng',
                            ),
                            onChanged: (v) => setState(() {
                              final quantity = int.tryParse(v) ?? 0;
                              item.quantity = quantity;
                              item.requestedQuantity = quantity;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: item.price.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: widget.inbound
                                  ? 'Giá nhập'
                                  : 'Giá bán',
                            ),
                            onChanged: (v) => setState(
                              () => item.price = double.tryParse(v) ?? 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        money(item.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => _pickProduct(s),
            icon: const Icon(Icons.add),
            label: const Text('Thêm sản phẩm'),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Tạm tính'),
                      const Spacer(),
                      Text(money(items.fold<double>(0, (v, e) => v + e.total))),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Tổng cộng',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        money(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _save(false),
                  child: const Text('Lưu nháp'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _save(true),
                  child: const Text('Xác nhận'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _pickProduct(AppStore s) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Chọn sản phẩm',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ...s.products
                .where((p) => widget.inbound || p.stockQuantity > 0)
                .map(
                  (p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      'Mã ${p.sku} • ${p.dimension} ${p.dimensionUnit} • '
                      '${widget.inbound ? 'Giá nhập' : 'Giá bán'} ${money(widget.inbound ? p.purchasePrice : p.sellingPrice)}',
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () {
                      setState(
                        () => items.add(
                          LineItem(
                            productId: p.id,
                            quantity: 1,
                            price: widget.inbound
                                ? p.purchasePrice
                                : p.sellingPrice,
                          ),
                        ),
                      );
                      Navigator.pop(sheet);
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(bool confirm) async {
    final s = context.read<AppStore>();
    if (partnerId == null) {
      toast(context, 'Vui lòng thêm và chọn đối tác.', error: true);
      return;
    }
    if (items.isEmpty) {
      toast(context, 'Vui lòng thêm ít nhất một sản phẩm.', error: true);
      return;
    }
    if (items.any((e) => e.quantity <= 0)) {
      toast(context, 'Số lượng phải lớn hơn 0.', error: true);
      return;
    }
    if (items.any((e) => s.productOrNull(e.productId) == null)) {
      toast(context, 'Phiếu có sản phẩm không còn tồn tại.', error: true);
      return;
    }
    if (s.isRemote) {
      try {
        await s.saveAndMaybeConfirmRemote(
          date: voucherDate,
          inbound: widget.inbound,
          partnerId: partnerId!,
          items: items,
          discount: 0,
          note: '',
          confirm: confirm,
        );
        if (!mounted) return;
        toast(
          context,
          confirm ? 'Đã xác nhận và cập nhật tồn kho.' : 'Đã lưu bản nháp.',
        );
        Navigator.pop(context);
      } catch (e) {
        if (mounted) toast(context, e.toString(), error: true);
      }
      return;
    }
    final doc = s.saveDocument(
      date: voucherDate,
      inbound: widget.inbound,
      partnerId: partnerId!,
      items: items
          .map(
            (e) => LineItem(
              productId: e.productId,
              quantity: e.quantity,
              price: e.price,
            ),
          )
          .toList(),
      discount: 0,
      confirm: false,
      note: '',
    );
    if (confirm) {
      final error = s.confirmDocument(doc);
      if (error != null) {
        s.documents.remove(doc);
        toast(context, error, error: true);
        return;
      }
    }
    toast(
      context,
      confirm ? 'Đã xác nhận và cập nhật tồn kho.' : 'Đã lưu bản nháp.',
    );
    Navigator.pop(context);
  }
}

class DocumentDetailScreen extends StatelessWidget {
  const DocumentDetailScreen(this.doc, {super.key});
  final StockDocument doc;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.code),
        actions: [
          if (!doc.inbound && doc.status == DocStatus.confirmed)
            IconButton(
              tooltip: 'Xuất PDF và lưu hóa đơn',
              onPressed: () => _issueAndPrint(context, s),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
      ),
      bottomNavigationBar: doc.status == DocStatus.draft
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () async {
                    if (s.isRemote) {
                      try {
                        await s.confirmRemoteDocument(doc);
                        if (context.mounted) {
                          toast(context, 'Đã xác nhận và cập nhật tồn kho.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          toast(context, e.toString(), error: true);
                        }
                      }
                      return;
                    }
                    final error = s.confirmDocument(doc);
                    toast(
                      context,
                      error ?? 'Đã xác nhận và cập nhật tồn kho.',
                      error: error != null,
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Xác nhận phiếu'),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              StatusPill(
                doc.status == DocStatus.confirmed ? 'Đã xác nhận' : 'Bản nháp',
                doc.status == DocStatus.confirmed
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF64748B),
              ),
              const Spacer(),
              Text(shortDate(doc.date)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                doc.inbound ? Icons.factory_outlined : Icons.store_outlined,
              ),
              title: Text(doc.inbound ? 'Nhà cung cấp' : 'Khách hàng'),
              subtitle: Text(s.partner(doc.partnerId).name),
            ),
          ),
          const SectionTitle('Chi tiết hàng hóa'),
          ...doc.items.map((e) {
            final p = s.product(e.productId);
            return Card(
              child: ListTile(
                title: Text(p.name),
                subtitle: Text('${e.quantity} ${p.unit} × ${money(e.price)}'),
                trailing: Text(
                  money(e.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Tổng cộng',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    money(doc.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (doc.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Ghi chú: ${doc.note}'),
            ),
          if (!doc.inbound && doc.status == DocStatus.confirmed) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _issueAndPrint(context, s),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Xuất PDF và lưu hóa đơn'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _issueAndPrint(BuildContext context, AppStore store) async {
    try {
      await store.issueInvoiceForOutbound(doc);
      if (!context.mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) => buildOutboundVoucherPdf(store, doc, format),
      );
      if (context.mounted) {
        toast(context, 'Đã lưu hóa đơn và tạo phiếu xuất kho PDF.');
      }
    } catch (error) {
      if (context.mounted) toast(context, error.toString(), error: true);
    }
  }
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool issuing = false;

  Future<void> _issueFromOutbound() async {
    final store = context.read<AppStore>();
    final vouchers = store.documents
        .where((d) => !d.inbound && d.status == DocStatus.confirmed)
        .toList();
    final selected = await showModalBottomSheet<StockDocument>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .65,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chọn phiếu xuất kho đã xác nhận'),
              ),
              Expanded(
                child: vouchers.isEmpty
                    ? const Center(
                        child: Text('Chưa có phiếu xuất kho đã xác nhận.'),
                      )
                    : ListView.builder(
                        itemCount: vouchers.length,
                        itemBuilder: (_, index) {
                          final voucher = vouchers[index];
                          final issued = store.invoices.any(
                            (i) => i.sourceDocumentId == voucher.id && !i.draft,
                          );
                          return ListTile(
                            title: Text(
                              '${voucher.code} • ${store.partner(voucher.partnerId).name}',
                            ),
                            subtitle: Text(
                              '${shortDate(voucher.date)} • ${money(voucher.total)}${issued ? ' • Đã có hóa đơn' : ''}',
                            ),
                            trailing: const Icon(Icons.picture_as_pdf_outlined),
                            onTap: () => Navigator.pop(sheet, voucher),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted || issuing) return;
    setState(() => issuing = true);
    try {
      final invoice = await store.issueInvoiceForOutbound(selected);
      if (!mounted) return;
      toast(context, 'Đã lưu hóa đơn ${invoice.number}.');
      await Printing.layoutPdf(
        onLayout: (format) => buildOutboundVoucherPdf(store, selected, format),
      );
    } catch (error) {
      if (mounted) toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => issuing = false);
    }
  }

  String q = '', status = 'Tất cả';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final list = s.invoices
        .where(
          (e) =>
              !e.draft &&
              (e.number.toLowerCase().contains(q.toLowerCase()) ||
                  s
                      .partner(e.customerId)
                      .name
                      .toLowerCase()
                      .contains(q.toLowerCase())) &&
              (status == 'Tất cả' ||
                  (status == 'Đã thanh toán' &&
                      e.paymentStatus == PaymentStatus.paid) ||
                  (status == 'Chưa thanh toán' &&
                      e.paymentStatus == PaymentStatus.unpaid)),
        )
        .toList();
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            PageHeader(
              title: 'Hóa đơn nội bộ',
              subtitle: '${s.invoices.where((i) => !i.draft).length} chứng từ',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: issuing ? null : _issueFromOutbound,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    issuing
                        ? 'Đang xuất hóa đơn...'
                        : 'Xuất hóa đơn từ phiếu xuất kho',
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Số hóa đơn hoặc khách hàng...',
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: ['Tất cả', 'Chưa thanh toán', 'Đã thanh toán']
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(e),
                          selected: status == e,
                          onSelected: (_) => setState(() => status = e),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Không có hóa đơn',
                      message: 'Tạo hóa đơn mới hoặc thay đổi bộ lọc.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _InvoiceCard(list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard(this.invoice);
  final Invoice invoice;
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final label = invoice.draft
        ? 'Bản nháp'
        : invoice.paymentStatus == PaymentStatus.paid
        ? 'Đã thanh toán'
        : invoice.paymentStatus == PaymentStatus.partial
        ? 'Thanh toán một phần'
        : 'Chưa thanh toán';
    final color = invoice.draft
        ? const Color(0xFF64748B)
        : invoice.paymentStatus == PaymentStatus.paid
        ? const Color(0xFF16A34A)
        : const Color(0xFFF59E0B);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/invoices/${Uri.encodeComponent(invoice.id)}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.number,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  StatusPill(label, color),
                  IconButton(
                    tooltip: 'Xuất PDF',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () async {
                      try {
                        await Printing.layoutPdf(
                          onLayout: (format) =>
                              buildInvoicePdf(s, invoice, format),
                        );
                      } catch (error) {
                        if (context.mounted) {
                          toast(context, error.toString(), error: true);
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.business_outlined,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.partner(invoice.customerId).name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    shortDate(invoice.date),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  Text('${invoice.items.length} mặt hàng'),
                  const Spacer(),
                  Text(
                    money(invoice.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key, this.source});
  final StockDocument? source;
  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  String? customer;
  final items = <LineItem>[];
  double discount = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (items.isEmpty && widget.source != null) {
      customer = widget.source!.partnerId;
      items.addAll(
        widget.source!.items.map(
          (e) => LineItem(
            productId: e.productId,
            quantity: e.quantity,
            price: e.price,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final customers = s.partnersOf(PartnerType.customer);
    customer ??= customers.firstOrNull?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo hóa đơn nội bộ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (customers.isEmpty)
            EmptyState(
              icon: Icons.people_outline,
              title: 'Chưa có khách hàng',
              message: 'Hãy thêm khách hàng trước khi tạo hóa đơn.',
              action: FilledButton(
                onPressed: () => context.go('/partners'),
                child: const Text('Mở danh sách đối tác'),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFFC2410C)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đây là chứng từ bán hàng nội bộ, không phải hóa đơn điện tử hoặc hóa đơn thuế.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: customer,
            decoration: const InputDecoration(labelText: 'Khách hàng *'),
            items: customers
                .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                .toList(),
            onChanged: (v) => setState(() => customer = v),
          ),
          const SectionTitle('Hàng hóa'),
          ...items.asMap().entries.map((entry) {
            final e = entry.value, p = s.product(e.productId);
            return Card(
              child: ListTile(
                title: Text(p.name),
                subtitle: Text('${e.quantity} × ${money(e.price)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      money(e.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => items.removeAt(entry.key)),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => _pick(s),
            icon: const Icon(Icons.add),
            label: const Text('Thêm dòng hàng'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '0',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Chiết khấu'),
            onChanged: (v) =>
                setState(() => discount = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Tổng thanh toán',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    money(
                      items.fold<double>(0, (v, e) => v + e.total) - discount,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu và xem hóa đơn'),
          ),
        ],
      ),
    );
  }

  void _pick(AppStore s) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheet) => ListView(
      shrinkWrap: true,
      children: s.products
          .map(
            (p) => ListTile(
              title: Text(p.name),
              subtitle: Text(money(p.sellingPrice)),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: () {
                setState(
                  () => items.add(
                    LineItem(
                      productId: p.id,
                      quantity: 1,
                      price: p.sellingPrice,
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
  Future<void> _save() async {
    if (customer == null) {
      toast(context, 'Vui lòng thêm và chọn khách hàng.', error: true);
      return;
    }
    if (items.isEmpty) {
      toast(context, 'Vui lòng thêm ít nhất một mặt hàng.', error: true);
      return;
    }
    final store = context.read<AppStore>();
    if (items.any((e) => store.productOrNull(e.productId) == null)) {
      toast(context, 'Hóa đơn có sản phẩm không còn tồn tại.', error: true);
      return;
    }
    if (store.isRemote) {
      try {
        final invoiceId = await store.addInvoiceRemote(
          customerId: customer!,
          items: items,
          sourceDocumentId: widget.source?.id,
          discount: discount,
        );
        if (!mounted) return;
        context.go('/invoices/${Uri.encodeComponent(invoiceId)}');
      } catch (e) {
        if (mounted) toast(context, e.toString(), error: true);
      }
      return;
    }
    final invoice = store.addInvoice(
      customerId: customer!,
      items: items,
      sourceDocumentId: widget.source?.id,
      discount: discount,
    );
    context.go('/invoices/${Uri.encodeComponent(invoice.id)}');
  }
}

/* class InvoiceDetailScreen extends StatelessWidget{const InvoiceDetailScreen(this.invoice,{super.key});final Invoice invoice;@override Widget build(BuildContext context){final s=context.watch<AppStore>(),customer=s.partner(invoice.customerId);return Scaffold(appBar:AppBar(title:Text(invoice.number),actions:[IconButton(tooltip:'In / Xuất PDF',onPressed:()=>Printing.layoutPdf(onLayout:(format)=>buildInvoicePdf(s,invoice,format)),icon:const Icon(Icons.picture_as_pdf_outlined))]),body:ListView(padding:const EdgeInsets.all(16),children:[Container(color:Colors.white,padding:const EdgeInsets.all(20),child:Column(children:[Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:52,height:52,decoration:BoxDecoration(color:const Color(0xFF2563EB),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.inventory_2,color:Colors.white)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s.company.name,style:const TextStyle(fontWeight:FontWeight.bold)),Text(s.company.address,style:const TextStyle(fontSize:11,color:Color(0xFF64748B)))]))]),const SizedBox(height:24),const Text('HÓA ĐƠN BÁN HÀNG',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Color(0xFF1D4ED8))),const Text('(NỘI BỘ)',style:TextStyle(fontWeight:FontWeight.bold)),Text('Số: ${invoice.number} • ${shortDate(invoice.date)}'),const Divider(height:32),Align(alignment:Alignment.centerLeft,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('KHÁCH HÀNG',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF64748B))),Text(customer.name,style:const TextStyle(fontWeight:FontWeight.bold)),Text(customer.address),Text(customer.phone)])),const SizedBox(height:20),...invoice.items.asMap().entries.map((e){final p=s.product(e.value.productId);return Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${e.key+1}. '),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.name,style:const TextStyle(fontWeight:FontWeight.w600)),Text('${e.value.quantity} ${p.unit} × ${money(e.value.price)}',style:const TextStyle(color:Color(0xFF64748B)))])),Text(money(e.value.total),style:const TextStyle(fontWeight:FontWeight.bold))]));}),const Divider(height:24),Row(children:[const Text('TỔNG CỘNG',style:TextStyle(fontWeight:FontWeight.bold)),const Spacer(),Text(money(invoice.total),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Color(0xFF2563EB)))]),const SizedBox(height:30),const Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_Signature('Người lập phiếu'),_Signature('Khách hàng')])]))]),Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>Printing.layoutPdf(onLayout:(format)=>buildInvoicePdf(s,invoice,format)),icon:const Icon(Icons.print_outlined),label:const Text('In / PDF'))),if(invoice.draft)...[const SizedBox(width:10),IconButton.filledTonal(onPressed:(){showDialog(context:context,builder:(d)=>AlertDialog(title:const Text('Xóa hóa đơn nháp?'),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Hủy')),FilledButton(onPressed:(){s.deleteInvoice(invoice);Navigator.pop(d);Navigator.pop(context);},child:const Text('Xóa'))]));},icon:const Icon(Icons.delete_outline))]]))]));}}
*/
class _Signature extends StatelessWidget {
  const _Signature(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 50),
      const Text(
        '(Ký, ghi rõ họ tên)',
        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
      ),
    ],
  );
}

Future<Uint8List> buildOutboundVoucherPdf(
  AppStore store,
  StockDocument voucher,
  PdfPageFormat format,
) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final company = store.company;
  final customer = store.partner(voucher.partnerId);
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
      header: (_) => pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      company.name,
                      style: pw.TextStyle(font: bold, fontSize: 10),
                    ),
                    pw.Text(
                      company.address,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    if (company.phone.isNotEmpty)
                      pw.Text(
                        'Điện thoại: ${company.phone}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PHIẾU XUẤT KHO',
                      style: pw.TextStyle(font: bold, fontSize: 18),
                    ),
                    pw.Text(
                      'Số: ${voucher.code}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Ngày ${voucher.date.day} tháng ${voucher.date.month} năm ${voucher.date.year}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
        ],
      ),
      build: (_) => [
        pw.Table(
          border: pw.TableBorder.all(width: .5),
          columnWidths: const {
            0: pw.FixedColumnWidth(100),
            1: pw.FlexColumnWidth(),
          },
          children: [
            _pdfInfoRow('TÊN NGƯỜI NHẬN HÀNG', customer.name, bold),
            _pdfInfoRow(
              'ĐỊA CHỈ (BỘ PHẬN)',
              voucher.recipientDepartment.isEmpty
                  ? voucher.deliveryAddress
                  : voucher.recipientDepartment,
              bold,
            ),
            _pdfInfoRow(
              'LÝ DO XUẤT KHO',
              voucher.reason.isEmpty ? voucher.note : voucher.reason,
              bold,
            ),
            _pdfInfoRow('XUẤT TẠI KHO', voucher.destination, bold),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(width: .5),
          headerStyle: pw.TextStyle(font: bold, fontSize: 7),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellAlignment: pw.Alignment.center,
          columnWidths: const {
            0: pw.FixedColumnWidth(22),
            1: pw.FlexColumnWidth(2.6),
            2: pw.FlexColumnWidth(.8),
            3: pw.FlexColumnWidth(.6),
            4: pw.FlexColumnWidth(.8),
            5: pw.FlexColumnWidth(.8),
            6: pw.FlexColumnWidth(1),
            7: pw.FlexColumnWidth(1.2),
          },
          headers: const [
            'STT',
            'TÊN, NHÃN HIỆU, QUY CÁCH, PHẨM CHẤT VẬT TƯ, SẢN PHẨM, HÀNG HÓA',
            'MÃ SỐ',
            'ĐVT',
            'SL YÊU CẦU',
            'SL THỰC XUẤT',
            'ĐƠN GIÁ',
            'THÀNH TIỀN',
          ],
          data: voucher.items.asMap().entries.map((entry) {
            final item = entry.value;
            final product = store.product(item.productId);
            final specification = [
              product.name,
              product.note,
              '${product.dimension} ${product.dimensionUnit}',
            ].where((value) => value.trim().isNotEmpty).join('\n');
            return [
              '${entry.key + 1}',
              specification,
              product.sku,
              product.unit,
              '${item.requestedQuantity}',
              '${item.quantity}',
              money(item.price),
              money(item.total),
            ];
          }).toList(),
        ),
        pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            'Tổng cộng: ${money(voucher.total)}',
            style: pw.TextStyle(font: bold),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Ngày ${voucher.date.day} tháng ${voucher.date.month} năm ${voucher.date.year}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: ['Người nhận hàng', 'NGƯỜI LẬP PHIẾU']
              .map(
                (title) => pw.Column(
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(font: bold, fontSize: 9),
                    ),
                    pw.Text(
                      '(Ký, ghi rõ họ tên)',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.SizedBox(height: 52),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
  return document.save();
}

pw.TableRow _pdfInfoRow(String label, String value, pw.Font bold) =>
    pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 7)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
        ),
      ],
    );

Future<Uint8List> buildInvoicePdf(
  AppStore s,
  Invoice invoice,
  PdfPageFormat format,
) async {
  if (invoice.sourceDocumentId != null) {
    final voucher = s.documents
        .where((d) => d.id == invoice.sourceDocumentId && !d.inbound)
        .firstOrNull;
    if (voucher == null) {
      throw StateError(
        'Không tìm thấy phiếu xuất kho của hóa đơn. Hãy tải lại dữ liệu.',
      );
    }
    return buildOutboundVoucherPdf(s, voucher, format);
  }
  final doc = pw.Document();
  final customer = s.partner(invoice.customerId);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PACKFLOW',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(width: 220, child: pw.Text(s.company.name)),
                pw.Text(s.company.phone),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'HOA DON BAN HANG',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '(NOI BO)',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(invoice.number),
                pw.Text(shortDate(invoice.date)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'KHACH HANG',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(customer.name),
              pw.Text(customer.address),
              pw.Text(customer.phone),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: [
            'STT',
            'San pham',
            'DVT',
            'So luong',
            'Don gia',
            'Thanh tien',
          ],
          data: invoice.items.asMap().entries.map((e) {
            final p = s.product(e.value.productId);
            return [
              '${e.key + 1}',
              p.name,
              p.unit,
              '${e.value.quantity}',
              money(e.value.price),
              money(e.value.total),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'TONG CONG: ${money(invoice.total)}',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
        ),
        pw.SizedBox(height: 50),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Text(
              'Nguoi lap phieu\n\n\n(Ky, ghi ro ho ten)',
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'Khach hang\n\n\n(Ky, ghi ro ho ten)',
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ],
      footer: (context) => pw.Center(
        child: pw.Text(
          'Chung tu noi bo - khong phai hoa don dien tu',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
        ),
      ),
    ),
  );
  return doc.save();
}

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});
  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

/* class _PartnersScreenState extends State<PartnersScreen>{PartnerType type=PartnerType.customer;String q='';@override Widget build(BuildContext context){final s=context.watch<AppStore>();final list=s.partnersOf(type).where((e)=>e.name.toLowerCase().contains(q.toLowerCase())||e.phone.contains(q)).toList();return Scaffold(appBar:AppBar(title:const Text('Đối tác')),floatingActionButton:FloatingActionButton.extended(onPressed:()=>_form(),icon:const Icon(Icons.person_add_alt),label:const Text('Thêm đối tác')),body:Column(children:[Padding(padding:const EdgeInsets.all(16),child:SegmentedButton<PartnerType>(segments:const [ButtonSegment(value:PartnerType.customer,label:Text('Khách hàng'),icon:Icon(Icons.people_outline)),ButtonSegment(value:PartnerType.supplier,label:Text('Nhà cung cấp'),icon:Icon(Icons.factory_outlined))],selected:{type},onSelectionChanged:(v)=>setState(()=>type=v.first))),Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(onChanged:(v)=>setState(()=>q=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Tìm tên hoặc số điện thoại...'))),const SizedBox(height:8),Expanded(child:ListView.builder(padding:const EdgeInsets.fromLTRB(16,0,16,100),itemCount:list.length,itemBuilder:(_,i){final p=list[i];final tx=s.documents.where((e)=>e.partnerId==p.id).length;return Card(child:ListTile(onTap:()=>showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)),const SizedBox(height:12),Text('Điện thoại: ${p.phone}'),Text('Email: ${p.email.isEmpty?'Chưa cập nhật':p.email}'),Text('Địa chỉ: ${p.address}'),Text('Mã số thuế: ${p.taxCode.isEmpty?'—':p.taxCode}'),const Divider(height:28),Text('$tx giao dịch liên quan',style:const TextStyle(fontWeight:FontWeight.bold))]))),leading:CircleAvatar(backgroundColor:const Color(0xFFDBEAFE),child:Text(p.name.substring(0,1),style:const TextStyle(color:Color(0xFF1D4ED8),fontWeight:FontWeight.bold))),title:Text(p.name,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text('${p.phone}\n${p.address}',maxLines:2),isThreeLine:true,trailing:PopupMenuButton(itemBuilder:(_)=>[PopupMenuItem(onTap:()=>_form(p),child:const Text('Chỉnh sửa')),PopupMenuItem(onTap:()=>Future.delayed(Duration.zero,()=>s.deletePartner(p.id)),child:const Text('Xóa',style:TextStyle(color:Color(0xFFDC2626))))])));}))]));}
void _form([Partner? p]){final name=TextEditingController(text:p?.name),phone=TextEditingController(text:p?.phone),address=TextEditingController(text:p?.address),email=TextEditingController(text:p?.email),tax=TextEditingController(text:p?.taxCode);showDialog(context:context,builder:(d)=>AlertDialog(title:Text(p==null?'Thêm đối tác':'Sửa đối tác'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Tên *')),const SizedBox(height:8),TextField(controller:phone,decoration:const InputDecoration(labelText:'Điện thoại *')),const SizedBox(height:8),TextField(controller:address,decoration:const InputDecoration(labelText:'Địa chỉ')),const SizedBox(height:8),TextField(controller:email,decoration:const InputDecoration(labelText:'Email')),const SizedBox(height:8),TextField(controller:tax,decoration:const InputDecoration(labelText:'Mã số thuế'))])),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Hủy')),FilledButton(onPressed:(){if(name.text.trim().isEmpty||phone.text.trim().isEmpty)return;if(p==null){context.read<AppStore>().addPartner(Partner(id:'pt${DateTime.now().microsecondsSinceEpoch}',type:type,name:name.text,phone:phone.text,address:address.text,email:email.text,taxCode:tax.text));}else{p.name=name.text;p.phone=phone.text;p.address=address.text;p.email=email.text;p.taxCode=tax.text;context.read<AppStore>().updateCompany();}Navigator.pop(d);},child:const Text('Lưu'))]));}}

*/
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo thống kê')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Từ ngày'),
                  child: Text(
                    shortDate(
                      DateTime.now().subtract(const Duration(days: 30)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Đến ngày'),
                  child: Text(shortDate(DateTime.now())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _ReportKpi(
                'Tổng nhập',
                money(s.inboundValue),
                Icons.south_west,
                const Color(0xFF16A34A),
              ),
              _ReportKpi(
                'Tổng xuất',
                money(s.outboundValue),
                Icons.north_east,
                const Color(0xFF7C3AED),
              ),
              _ReportKpi(
                'Giá trị kho',
                money(s.stockValue),
                Icons.warehouse_outlined,
                const Color(0xFF2563EB),
              ),
              _ReportKpi(
                'Số giao dịch',
                '${s.documents.where((e) => e.status == DocStatus.confirmed).length}',
                Icons.swap_horiz,
                const Color(0xFF0D9488),
              ),
            ],
          ),
          const SectionTitle('Nhập / xuất theo tháng'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(height: 180, child: _MiniChart()),
            ),
          ),
          const SectionTitle('Giao dịch gần đây'),
          ...s.documents
              .take(6)
              .map(
                (d) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: d.inbound
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFEDE9FE),
                      child: Icon(
                        d.inbound ? Icons.south_west : Icons.north_east,
                        color: d.inbound
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF7C3AED),
                      ),
                    ),
                    title: Text(d.code),
                    subtitle: Text(
                      '${s.partner(d.partnerId).name} • ${shortDate(d.date)}',
                    ),
                    trailing: Text(
                      money(d.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ReportKpi extends StatelessWidget {
  const _ReportKpi(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool dark = false, compact = false;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>(), c = s.company;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: Color(0xFF2563EB),
                  child: Icon(Icons.inventory_2, size: 42, color: Colors.white),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 15,
                    child: Icon(Icons.edit, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            c.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          if (s.isRemote) const GoogleAccountCard(),
          const SectionTitle('Hồ sơ doanh nghiệp'),
          Card(
            child: Column(
              children: [
                _SettingField('Tên công ty', c.name, (v) => c.name = v),
                _SettingField(
                  'Tên viết tắt',
                  c.shortName,
                  (v) => c.shortName = v,
                ),
                _SettingField('Mã số thuế', c.taxCode, (v) => c.taxCode = v),
                _SettingField('Địa chỉ', c.address, (v) => c.address = v),
                _SettingField('Điện thoại', c.phone, (v) => c.phone = v),
                _SettingField('Email', c.email, (v) => c.email = v),
                _SettingField('Website', c.website, (v) => c.website = v),
                _SettingField(
                  'Người đại diện',
                  c.representativeName,
                  (v) => c.representativeName = v,
                ),
                _SettingField('Tài khoản ngân hàng', c.bank, (v) => c.bank = v),
                _SettingField(
                  'Chân trang chứng từ',
                  c.invoiceFooter,
                  (v) => c.invoiceFooter = v,
                ),
              ],
            ),
          ),
          const SectionTitle('Cấu hình hóa đơn nội bộ'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('Mẫu hóa đơn'),
                  subtitle: Text('A4 • PackFlow tiêu chuẩn'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: true,
                  onChanged: (_) {},
                  title: const Text('Hiển thị thông tin ngân hàng'),
                  subtitle: const Text('Thêm vào cuối hóa đơn PDF'),
                ),
              ],
            ),
          ),
          const SectionTitle('Giao diện'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: dark,
                  onChanged: (v) => setState(() => dark = v),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Chế độ tối'),
                  subtitle: const Text('Bản xem trước giao diện'),
                ),
                SwitchListTile(
                  value: compact,
                  onChanged: (v) => setState(() => compact = v),
                  secondary: const Icon(Icons.density_small),
                  title: const Text('Hiển thị thu gọn'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              try {
                await s.saveCompany();
                if (context.mounted) toast(context, 'Đã lưu cài đặt.');
              } catch (error) {
                if (context.mounted) {
                  toast(context, error.toString(), error: true);
                }
              }
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu cài đặt'),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'PackFlow v1.0.0 • Frontend Prototype',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingField extends StatelessWidget {
  const _SettingField(this.label, this.value, this.change);
  final String label, value;
  final ValueChanged<String> change;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(
      label,
      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
    ),
    subtitle: Text(
      value,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
    ),
    trailing: const Icon(Icons.edit_outlined, size: 18),
    onTap: () => showDialog(
      context: context,
      builder: (d) {
        final c = TextEditingController(text: value);
        return AlertDialog(
          title: Text('Cập nhật $label'),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLines: label == 'Địa chỉ' ? 2 : 1,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                change(c.text);
                context.read<AppStore>().updateCompany();
                Navigator.pop(d);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    ),
  );
}

class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen(this.invoice, {super.key});
  final Invoice invoice;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final customer = store.partner(invoice.customerId);
    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.number),
        actions: [
          IconButton(
            onPressed: () => Printing.layoutPdf(
              onLayout: (f) => buildInvoicePdf(store, invoice, f),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'HÓA ĐƠN BÁN HÀNG',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const Text(
                    '(NỘI BỘ)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${invoice.number} • ${shortDate(invoice.date)}'),
                  const Divider(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${customer.name}\n${customer.address}\n${customer.phone}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...invoice.items.map((item) {
                    final p = store.product(item.productId);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name),
                      subtitle: Text(
                        '${item.quantity} ${p.unit} × ${money(item.price)}',
                      ),
                      trailing: Text(
                        money(item.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    children: [
                      const Text(
                        'TỔNG CỘNG',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        money(invoice.total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Signature('Người lập phiếu'),
                      _Signature('Khách hàng'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Printing.layoutPdf(
              onLayout: (f) => buildInvoicePdf(store, invoice, f),
            ),
            icon: const Icon(Icons.print_outlined),
            label: const Text('In / Xuất PDF'),
          ),
          if (invoice.draft) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _finalize(context, store),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Phát hành hóa đơn'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _delete(context, store),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa hóa đơn nháp'),
            ),
          ] else if (invoice.paymentStatus != PaymentStatus.paid) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _markPaid(context, store),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Đánh dấu đã thanh toán'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _finalize(BuildContext context, AppStore store) async {
    try {
      await store.finalizeInvoice(invoice);
      if (context.mounted) {
        toast(context, 'Đã phát hành hóa đơn.');
        context.go('/invoices');
      }
    } catch (error) {
      if (context.mounted) toast(context, error.toString(), error: true);
    }
  }

  Future<void> _delete(BuildContext context, AppStore store) async {
    try {
      await store.removeInvoice(invoice);
      if (context.mounted) {
        toast(context, 'Đã xóa hóa đơn nháp.');
        context.go('/invoices');
      }
    } catch (error) {
      if (context.mounted) toast(context, error.toString(), error: true);
    }
  }

  Future<void> _markPaid(BuildContext context, AppStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Xác nhận đã thanh toán?'),
        content: Text(
          'Hóa đơn ${invoice.number} sẽ được cập nhật là đã thanh toán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await store.markInvoicePaid(invoice);
      if (context.mounted) {
        toast(context, 'Đã cập nhật trạng thái đã thanh toán.');
        context.go('/invoices');
      }
    } catch (error) {
      if (context.mounted) toast(context, error.toString(), error: true);
    }
  }
}

class _PartnersScreenState extends State<PartnersScreen> {
  PartnerType type = PartnerType.customer;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final list = store
        .partnersOf(type)
        .where(
          (p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.phone.contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Đối tác')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(store),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Thêm đối tác'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<PartnerType>(
              segments: const [
                ButtonSegment(
                  value: PartnerType.customer,
                  label: Text('Khách hàng'),
                ),
                ButtonSegment(
                  value: PartnerType.supplier,
                  label: Text('Nhà cung cấp'),
                ),
              ],
              selected: {type},
              onSelectionChanged: (v) => setState(() => type = v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm đối tác...',
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final p = list[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(p.name.substring(0, 1))),
                    title: Text(p.name),
                    subtitle: Text('${p.phone}\n${p.address}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      onPressed: () async {
                        try {
                          await store.removePartner(p.id);
                        } catch (error) {
                          if (context.mounted) {
                            toast(context, error.toString(), error: true);
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _add(AppStore store) {
    final name = TextEditingController(), phone = TextEditingController();
    showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Thêm đối tác'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Điện thoại *'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.isNotEmpty && phone.text.isNotEmpty) {
                try {
                  await store.savePartner(
                    Partner(
                      id: 'pt${DateTime.now().microsecondsSinceEpoch}',
                      type: type,
                      name: name.text,
                      phone: phone.text,
                      address: 'Chưa cập nhật',
                    ),
                    isNew: true,
                  );
                  if (dialog.mounted) Navigator.pop(dialog);
                } catch (error) {
                  if (dialog.mounted) {
                    toast(dialog, error.toString(), error: true);
                  }
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
