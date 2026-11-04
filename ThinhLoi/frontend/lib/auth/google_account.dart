import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';

class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/google_g.png',
    width: 18,
    height: 18,
    excludeFromSemantics: true,
  );
}

class GoogleAccountCard extends StatelessWidget {
  const GoogleAccountCard({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tài khoản đăng nhập',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              auth.googleLinked
                  ? 'Đã liên kết Google với hồ sơ nhân viên này.'
                  : 'Liên kết Google để đăng nhập bằng hồ sơ nhân viên hiện tại.',
            ),
            if (!auth.googleLinked)
              OutlinedButton.icon(
                onPressed: auth.busy ? null : auth.linkGoogle,
                icon: auth.oauthPending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const GoogleMark(),
                label: const Text('Liên kết tài khoản Google'),
              ),
            if (auth.message != null) Text(auth.message!),
            if (auth.oauthPending)
              TextButton(
                onPressed: auth.cancelOAuth,
                child: const Text('Hủy liên kết'),
              ),
          ],
        ),
      ),
    );
  }
}
