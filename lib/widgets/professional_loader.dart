import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../utils/assets_helper.dart';

/// مؤشر تحميل احترافي مع شعار Jeel
class ProfessionalLoader extends StatelessWidget {
  final AnimationController rotationController;
  final String? message;
  final double? progress;

  const ProfessionalLoader({
    super.key,
    required this.rotationController,
    this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 3,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // شعار Jeel ثابت
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                AppAssets.jeelLogo,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.business,
                    size: 40,
                    color: Colors.blue.shade700,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            
            // حركة تحميل احترافية - discreteCircular
            LoadingAnimationWidget.discreteCircle(
              color: const Color(0xFFA21955), // لون #A21955
              secondRingColor: const Color(0xFF0099A3), // لون #0099A3
              thirdRingColor: const Color(0xFFA21955),
              size: 45,
            ),
            const SizedBox(height: 16),
            
            // نص التحميل
            Text(
              message ?? 'جاري التحميل...',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            
            // شريط التقدم
            if (progress != null && progress! > 0 && progress! < 1)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress! * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            else
              // نقاط متحركة إذا لم يكن هناك progress محدد
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 600 + (index * 200)),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: (value * 0.7) + 0.3,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                    onEnd: () {
                      // إعادة التحريك
                    },
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

