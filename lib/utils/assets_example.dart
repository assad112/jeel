/// ملف مثال يوضح كيفية استخدام الصور والأيقونات
/// 
/// هذا الملف يحتوي على أمثلة عملية لاستخدام AppAssets
/// يمكنك حذف هذا الملف بعد فهم كيفية الاستخدام

import 'package:flutter/material.dart';
import 'assets_helper.dart';

class AssetsExample extends StatelessWidget {
  const AssetsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مثال استخدام الصور والأيقونات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // مثال 1: استخدام صورة مباشرة
          _buildExampleCard(
            title: 'مثال 1: استخدام صورة مباشرة',
            child: Image.asset(
              AppAssets.splashLogo,
              width: 100,
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported);
              },
            ),
          ),

          const SizedBox(height: 16),

          // مثال 2: استخدام أيقونة مباشرة
          _buildExampleCard(
            title: 'مثال 2: استخدام أيقونة مباشرة',
            child: Image.asset(
              AppAssets.iconSettings,
              width: 48,
              height: 48,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.settings, size: 48);
              },
            ),
          ),

          const SizedBox(height: 16),

          // مثال 3: استخدام الدالة المساعدة
          _buildExampleCard(
            title: 'مثال 3: استخدام الدالة المساعدة',
            child: Image.asset(
              AppAssets.getImagePath('my_image.png'),
              width: 100,
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported);
              },
            ),
          ),

          const SizedBox(height: 16),

          // مثال 4: استخدام في قائمة
          _buildExampleCard(
            title: 'مثال 4: استخدام في قائمة',
            child: ListTile(
              leading: Image.asset(
                AppAssets.iconHome,
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.home, size: 24);
                },
              ),
              title: const Text('الصفحة الرئيسية'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ),

          const SizedBox(height: 16),

          // مثال 5: استخدام مع Container
          _buildExampleCard(
            title: 'مثال 5: استخدام مع Container',
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Image.asset(
                  AppAssets.appIcon,
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.apps, size: 60);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}


