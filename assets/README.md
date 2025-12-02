# مجلد Assets

هذا المجلد يحتوي على جميع الصور والأيقونات المستخدمة في التطبيق.

## البنية

```
assets/
├── images/          # الصور المستخدمة في التطبيق
│   ├── splash_logo.png
│   ├── app_icon.png
│   └── ...
└── icons/           # الأيقونات المستخدمة في التطبيق
    ├── settings.png
    ├── refresh.png
    └── ...
```

## كيفية الاستخدام

### 1. استخدام الصور

```dart
import 'package:expedu/utils/assets_helper.dart';

// استخدام صورة مباشرة
Image.asset(AppAssets.splashLogo)

// أو استخدام الدالة المساعدة
Image.asset(AppAssets.getImagePath('logo.png'))
```

### 2. استخدام الأيقونات

```dart
import 'package:expedu/utils/assets_helper.dart';

// استخدام أيقونة مباشرة
Image.asset(AppAssets.iconSettings)

// أو استخدام الدالة المساعدة
Image.asset(AppAssets.getIconPath('settings.png'))
```

## إضافة صور/أيقونات جديدة

1. ضع الملف في المجلد المناسب (`images/` أو `icons/`)
2. أضف ثابت جديد في `lib/utils/assets_helper.dart`:

```dart
static const String myNewImage = '$_imagesPath/my_new_image.png';
```

3. استخدمه في الكود:

```dart
Image.asset(AppAssets.myNewImage)
```

## ملاحظات مهمة

- جميع الصور يجب أن تكون بصيغة PNG أو JPG
- يُفضل استخدام PNG للصور مع خلفية شفافة
- يُفضل استخدام JPG للصور الفوتوغرافية
- احرص على تحسين حجم الصور قبل إضافتها لتقليل حجم التطبيق

## الأبعاد الموصى بها

- **أيقونة التطبيق**: 1024x1024 بكسل
- **شاشة البداية**: حسب حجم الشاشة (يفضل 1080x1920)
- **الأيقونات الصغيرة**: 24x24 أو 48x48 بكسل
- **الصور العامة**: حسب الحاجة


