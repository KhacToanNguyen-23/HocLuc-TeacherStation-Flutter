import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import '../../services/pdf_annotation_exporter.dart';

class SaveClassroomDialog extends StatelessWidget {
  const SaveClassroomDialog({
    super.key,
    required this.studio,
    required this.onSaveSlide,
  });

  final StudioState studio;
  final Future<bool> Function() onSaveSlide;

  static Future<void> show(
    BuildContext context, {
    required StudioState studio,
    required Future<bool> Function() onSaveSlide,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          SaveClassroomDialog(studio: studio, onSaveSlide: onSaveSlide),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      elevation: 10,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.sky50,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: const Icon(
                      Icons.save_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Lưu bài giảng trong phòng học',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Option 1: Lưu Slide bài giảng
              _buildOptionCard(
                context: context,
                icon: Icons.slideshow_rounded,
                iconColor: AppColors.success,
                iconBg: AppColors.successSurface,
                title: 'Slide bài giảng',
                buttonText: 'Lưu Slide',
                buttonColor: AppColors.success,
                onTap: () async {
                  Navigator.pop(context);
                  final success = await onSaveSlide();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Đã lưu slide bài giảng lên hệ thống thành công.'
                              : 'Lưu slide thất bại. Vui lòng kiểm tra lại dịch vụ.',
                        ),
                        backgroundColor: success
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Lưu file PDF
              _buildOptionCard(
                context: context,
                icon: Icons.picture_as_pdf_rounded,
                iconColor: AppColors.error,
                iconBg: AppColors.errorSurface,
                title: 'File tài liệu PDF',
                buttonText: 'Lưu PDF',
                buttonColor: AppColors.error,
                onTap: () async {
                  Navigator.pop(context);
                  await PdfAnnotationExporter.saveLecturePdf(context, studio);
                },
              ),
              const SizedBox(height: 12),

              // Option 3: Lưu cả hai (Slide & File PDF)
              _buildOptionCard(
                context: context,
                icon: Icons.cloud_done_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.sky50,
                title: 'Cả Slide & File PDF',
                buttonText: 'Lưu cả hai',
                buttonColor: AppColors.primary,
                onTap: () async {
                  Navigator.pop(context);
                  final success = await onSaveSlide();
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã lưu slide vào hệ thống. Đang mở hộp thoại xuất tệp PDF...',
                          ),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    await PdfAnnotationExporter.saveLecturePdf(context, studio);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 128, minHeight: 44),
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
