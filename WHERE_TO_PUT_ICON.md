# 📍 أين تضع الأيقونة؟

## الطريقة السهلة (موصى بها) ⭐

### 1. ضع أيقونة واحدة في:
```
assets/icons/app_icon.png
```
**الحجم المطلوب: 1024x1024 بكسل**

### 2. أضف هذا الكود في `pubspec.yaml`:

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
```

### 3. شغل الأوامر:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

**✅ انتهى!** سيقوم البرنامج بإنشاء جميع الأيقونات تلقائياً.

---

## الطريقة اليدوية (إذا لم تريد استخدام الحزمة)

### 📱 Android:
```
android/app/src/main/res/
├── mipmap-mdpi/ic_launcher.png    (48x48)
├── mipmap-hdpi/ic_launcher.png    (72x72)
├── mipmap-xhdpi/ic_launcher.png   (96x96)
├── mipmap-xxhdpi/ic_launcher.png  (144x144)
└── mipmap-xxxhdpi/ic_launcher.png (192x192)
```

### 🍎 iOS:
```
ios/Runner/Assets.xcassets/AppIcon.appiconset/
```
(افتح في Xcode وحدد الأيقونات)

### 🌐 Web:
```
web/icons/
├── Icon-192.png
├── Icon-512.png
├── Icon-maskable-192.png
└── Icon-maskable-512.png
```

---

## 📝 ملاحظة:
- الأيقونة الأساسية يجب أن تكون **1024x1024** بكسل
- الصيغة: **PNG** (يفضل مع خلفية شفافة)
- بعد التغيير: احذف التطبيق وأعد تثبيته لرؤية التغييرات


