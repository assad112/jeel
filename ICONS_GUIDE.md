# دليل وضع أيقونة التطبيق

هذا الدليل يوضح أين تضع أيقونة التطبيق لكل منصة.

## 📱 Android

### الموقع:
```
android/app/src/main/res/
├── mipmap-mdpi/
│   └── ic_launcher.png      (48x48 بكسل)
├── mipmap-hdpi/
│   └── ic_launcher.png      (72x72 بكسل)
├── mipmap-xhdpi/
│   └── ic_launcher.png      (96x96 بكسل)
├── mipmap-xxhdpi/
│   └── ic_launcher.png      (144x144 بكسل)
└── mipmap-xxxhdpi/
    └── ic_launcher.png      (192x192 بكسل)
```

### الخطوات:
1. جهز أيقونة واحدة بحجم **1024x1024** بكسل
2. استخدم أداة مثل [App Icon Generator](https://www.appicon.co/) لإنشاء جميع الأحجام
3. استبدل الملفات الموجودة في المجلدات أعلاه

### أو استخدم Flutter Package:
```bash
flutter pub add flutter_launcher_icons
```

ثم أضف في `pubspec.yaml`:
```yaml
flutter_launcher_icons:
  android: true
  image_path: "assets/icons/app_icon.png"
```

---

## 🍎 iOS

### الموقع:
```
ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

### الخطوات:
1. افتح المشروع في Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. في Xcode:
   - اختر `Runner` من القائمة الجانبية
   - اختر `Assets.xcassets`
   - اختر `AppIcon`
   - اسحب الأيقونات إلى الأماكن المناسبة

### الأحجام المطلوبة:
- 20x20 (@2x, @3x) = 40x40, 60x60
- 29x29 (@1x, @2x, @3x) = 29x29, 58x58, 87x87
- 40x40 (@2x, @3x) = 80x80, 120x120
- 60x60 (@2x, @3x) = 120x120, 180x180
- 1024x1024 (لـ App Store)

---

## 🌐 Web

### الموقع:
```
web/icons/
├── Icon-192.png
├── Icon-512.png
├── Icon-maskable-192.png
└── Icon-maskable-512.png
```

### الأحجام:
- `Icon-192.png`: 192x192 بكسل
- `Icon-512.png`: 512x512 بكسل
- `Icon-maskable-192.png`: 192x192 بكسل (مع خلفية شفافة)
- `Icon-maskable-512.png`: 512x512 بكسل (مع خلفية شفافة)

---

## 🪟 Windows

### الموقع:
```
windows/runner/resources/
└── app_icon.ico
```

### الخطوات:
1. حول PNG إلى ICO باستخدام أداة مثل [ConvertICO](https://convertio.co/png-ico/)
2. استبدل `app_icon.ico` الموجود

---

## 🖥️ macOS

### الموقع:
```
macos/Runner/Assets.xcassets/AppIcon.appiconset/
```

### الخطوات:
مشابهة لـ iOS - افتح في Xcode وحدد الأيقونات

---

## 🐧 Linux

### الموقع:
```
linux/runner/
└── (يتم تحديده في CMakeLists.txt)
```

---

## 🚀 الطريقة السهلة (موصى بها)

استخدم حزمة `flutter_launcher_icons` لتوليد جميع الأيقونات تلقائياً:

### 1. تثبيت الحزمة:
```bash
flutter pub add --dev flutter_launcher_icons
```

### 2. إضافة الإعدادات في `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  web:
    generate: true
    image_path: "assets/icons/app_icon.png"
    background_color: "#ffffff"
    theme_color: "#0175C2"
  image_path: "assets/icons/app_icon.png"
  min_sdk_android: 21
  remove_alpha_ios: true
```

### 3. وضع الأيقونة الأساسية:
ضع أيقونة واحدة بحجم **1024x1024** في:
```
assets/icons/app_icon.png
```

### 4. توليد الأيقونات:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

---

## 📝 ملاحظات مهمة:

1. **الأيقونة الأساسية**: يجب أن تكون بحجم **1024x1024** بكسل
2. **الصيغة**: PNG مع خلفية شفافة (للأفضل)
3. **التصميم**: تجنب النصوص الصغيرة - الأيقونة ستظهر صغيرة
4. **الألوان**: استخدم ألوان واضحة ومميزة

---

## ✅ بعد وضع الأيقونات:

1. أعد بناء التطبيق:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. للتحقق من التغييرات:
   - **Android**: احذف التطبيق وأعد تثبيته
   - **iOS**: احذف التطبيق من المحاكي/الجهاز وأعد تثبيته

---

## 🔗 روابط مفيدة:

- [App Icon Generator](https://www.appicon.co/)
- [Flutter Launcher Icons Package](https://pub.dev/packages/flutter_launcher_icons)
- [Android Icon Guidelines](https://developer.android.com/guide/practices/ui_guidelines/icon_design)
- [iOS Icon Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)


