import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/stores/auth_store.dart';
import '../themes/app_styles.dart';

class DeleteAccountModal extends StatelessWidget {
  const DeleteAccountModal({super.key});

  @override
  Widget build(BuildContext context) {
    final double modalWidth = MediaQuery.of(context).size.width * 0.92;

    return Center(
      child: ClipRRect(
        borderRadius: AppStyles.radiusMedium,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: modalWidth,
            padding: AppStyles.paddingModal,
            decoration: AppStyles.frostedGlass,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppStyles.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Delete Account',
                        textAlign: TextAlign.center,
                        style: AppStyles.headingMedium,
                      ),
                    ),
                    Opacity(
                      opacity: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: null,
                      ),
                    ),
                  ],
                ),
                AppStyles.spacingMedium,
                Text(
                  'Are you sure you want to delete your account permanently?',
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ This action cannot be undone.',
                        style: AppStyles.bodyMedium.copyWith(
                          color: Colors.red.shade200,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'All your data will be permanently deleted, including:',
                        style: AppStyles.bodyMedium.copyWith(
                          fontSize: 14,
                          color: AppStyles.cream,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDataItem('• Your profile information'),
                            _buildDataItem('• All meditations and progress'),
                            _buildDataItem('• Goals and reflections'),
                            _buildDataItem('• Personal settings and preferences'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AppStyles.spacingLarge,
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: AppStyles.white, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'No',
                          style: AppStyles.bodyMedium.copyWith(
                            color: AppStyles.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final authStore = context.read<AuthStore>();
                          
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(
                                color: AppStyles.white,
                              ),
                            ),
                          );

                          try {
                            await authStore.deleteAccount();
                            
                            if (context.mounted) {
                              Navigator.of(context).pop(); // Close loading
                              Navigator.of(context).pop(); // Close modal
                              
                              // Navigate to login page and clear navigation stack
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login',
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(context).pop(); // Close loading
                              
                              // Show error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to delete account. Please try again.',
                                    style: AppStyles.bodyMedium,
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Yes',
                          style: AppStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppStyles.bodyMedium.copyWith(
          fontSize: 14,
          color: AppStyles.cream,
        ),
      ),
    );
  }

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return const DeleteAccountModal();
      },
    );
  }
}
