import 'package:intl/intl.dart';

final _money = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);
String money(num value) => _money.format(value);
String shortDate(DateTime value) => DateFormat('dd/MM/yyyy').format(value);
String longDate(DateTime value) =>
    'Ngày ${value.day} tháng ${value.month} năm ${value.year}';
