import 'package:flutter/material.dart';
import '../../constants/theme.dart';

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.hub_outlined, color: AppColors.primary, size: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected
                        ? 'Google đã kết nối'
                        : needsConsent
                        ? 'Google cần cấp quyền lại'
                        : retryConnection
                        ? 'Chưa kiểm tra được kết nối'
                        : 'Kết nối Google',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    email.isEmpty ? 'Chọn tài khoản Google để sử dụng HocLucStation.' : email,
                  ),
                ],
              ),
              if (!polling)
                FilledButton.icon(
                  onPressed: disabled || connection['configured'] != true ? null : onConnect,
                  icon: const Icon(Icons.link),
                  label: Text(
                    connected
                        ? 'Kiểm tra kết nối'
                        : needsConsent
                        ? 'Cấp quyền lại'
                        : retryConnection
                        ? 'Thử lại'
                        : 'Kết nối Google',
                  ),
                ),
              if (!polling && connection['configured'] == true)
                TextButton(
                  onPressed: disabled ? null : onChangeAccount,
                  child: const Text('Đổi tài khoản'),
                ),
              if (connected && !polling)
                TextButton(
                  onPressed: disabled ? null : onConnect,
                  child: const Text('Cấp quyền lại'),
                ),
              if (email.isNotEmpty &&
                  connection['state'] != 'DISCONNECTED' &&
                  connection['configured'] == true)
                TextButton(
                  onPressed: disabled ? null : onDisconnect,
                  child: const Text('Ngắt kết nối'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Đăng xuất HocLucStation giữ quyền đã cấp. Ngắt kết nối Google sẽ thu hồi quyền API của tài khoản này.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Chip(
                avatar: Icon(Icons.school_outlined, size: 18),
                label: Text('Classroom · Lớp và thành viên'),
              ),
              Chip(
                avatar: Icon(Icons.videocam_outlined, size: 18),
                label: Text('Meet · Phòng học'),
              ),
              Chip(
                avatar: Icon(Icons.event_outlined, size: 18),
                label: Text('Calendar · Lịch và lời mời'),
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
          if (!connected && !polling)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                '1. Chọn tài khoản Google   →   2. Đồng ý cấp quyền   →   3. Tạo lớp trong HocLucStation',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
