import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../google_brand_icon.dart';

class WorkspaceConnectionPanel extends StatelessWidget {
  const WorkspaceConnectionPanel({
    super.key,
    required this.connection,
    required this.email,
    required this.disabled,
    required this.polling,
    required this.onConnect,
    required this.onChangeAccount,
    required this.onDisconnect,
    required this.onCancelPolling,
  });

  final Map<String, dynamic> connection;
  final String email;
  final bool disabled;
  final bool polling;
  final VoidCallback onConnect;
  final VoidCallback onChangeAccount;
  final VoidCallback onDisconnect;
  final VoidCallback onCancelPolling;

  @override
  Widget build(BuildContext context) {
    final connected = connection['connected'] == true;
    final needsConsent = connection['state'] == 'REAUTH_REQUIRED';
    final retryConnection =
        connection['state'] == 'TEMPORARY_ERROR' ||
        connection['state'] == 'CONFIG_ERROR';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GoogleBrandIcon(size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? 'Google đã kết nối'
                          : needsConsent
                          ? 'Cần cấp quyền Google'
                          : retryConnection
                          ? 'Kết nối chưa ổn định'
                          : 'Kết nối Google',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (!connected && !polling)
                FilledButton.icon(
                  onPressed: disabled || connection['configured'] != true
                      ? null
                      : onConnect,
                  icon: const Icon(Icons.link),
                  label: Text(
                    needsConsent
                        ? 'Cấp quyền lại'
                        : retryConnection
                        ? 'Thử lại'
                        : 'Kết nối',
                  ),
                ),
              if (connected && !polling)
                PopupMenuButton<String>(
                  enabled: !disabled,
                  tooltip: 'Tài khoản Google',
                  onSelected: (value) {
                    if (value == 'account') onChangeAccount();
                    if (value == 'access') onConnect();
                    if (value == 'disconnect') onDisconnect();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'account',
                      child: Text('Đổi tài khoản'),
                    ),
                    PopupMenuItem(
                      value: 'access',
                      child: Text('Cấp quyền lại'),
                    ),
                    PopupMenuItem(
                      value: 'disconnect',
                      child: Text('Ngắt kết nối'),
                    ),
                  ],
                ),
            ],
          ),
          if (connection['configured'] == false)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffe8f4f3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ứng dụng chưa được cấu hình kết nối Google. Người cài đặt HocLucStation cần hoàn tất cấu hình; giáo viên không cần tạo Client ID.',
                    ),
                  ),
                ],
              ),
            ),
          if (polling)
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Chọn tài khoản và cấp quyền trong trình duyệt, rồi trở về HocLucStation.',
                  ),
                ),
                TextButton(
                  onPressed: onCancelPolling,
                  child: const Text('Hủy'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
