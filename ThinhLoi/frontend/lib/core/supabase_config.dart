class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.publishableKey,
    this.error,
  });
  factory SupabaseConfig.fromEnvironment() {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL'),
    );
    const key = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment(
        'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
      ),
    );
    if (url.isEmpty || key.isEmpty) {
      return const SupabaseConfig(
        url: '',
        publishableKey: '',
        error: 'Thiếu cấu hình Supabase. Hãy cấu hình SUPABASE_URL và SUPABASE_PUBLISHABLE_KEY trong .env.local, sau đó dừng ứng dụng và chạy lại bằng scripts/run_web.ps1.',
      );
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return const SupabaseConfig(
        url: '',
        publishableKey: '',
        error: 'SUPABASE_URL không hợp lệ.',
      );
    }
    return const SupabaseConfig(url: url, publishableKey: key);
  }
  final String url;
  final String publishableKey;
  final String? error;
  bool get isValid => error == null;
}
