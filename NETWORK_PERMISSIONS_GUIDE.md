# دليل صلاحيات الشبكة المحلية

تم إضافة جميع الصلاحيات المطلوبة للسماح للتطبيق بالعمل على الشبكة المحلية.

## ما تم إضافته:

### 1. Android (`android/app/src/main/AndroidManifest.xml`):

```xml
<!-- صلاحيات الإنترنت والشبكة -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

<!-- في Application tag -->
android:usesCleartextTraffic="true"
android:networkSecurityConfig="@xml/network_security_config"
```

### 2. ملف إعدادات الشبكة (`android/app/src/main/res/xml/network_security_config.xml`):

يسمح بالاتصالات HTTP (غير المشفرة) للعناوين المحلية:
- `localhost`
- `127.0.0.1`
- `192.168.x.x` (شبكة Wi-Fi المنزلية)
- `10.x.x.x` (شبكات محلية)
- `172.16.x.x` (شبكات محلية)

### 3. iOS (`ios/Runner/Info.plist`):

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>يحتاج التطبيق للوصول إلى الشبكة المحلية للاتصال بخادم Jeel ERP</string>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

## الآن التطبيق يدعم:

✅ الاتصال بالإنترنت (HTTPS/HTTP)
✅ الاتصال بالشبكة المحلية (LAN)
✅ الوصول لعناوين IP محلية مثل:
   - `http://192.168.1.100`
   - `http://10.0.0.50`
   - `http://localhost:8069`
✅ الاتصالات غير المشفرة (HTTP) للشبكة المحلية

## أمثلة على عناوين يمكن استخدامها الآن:

```
http://192.168.1.100:8069/web/login
http://10.0.0.50/erp
http://localhost:3000
https://erp.jeel.om/web/login (يعمل أصلاً)
```

## كيف تستخدمه؟

1. إذا كان لديك خادم Jeel ERP على الشبكة المحلية:
   - افتح الإعدادات في التطبيق
   - غيّر الرابط إلى عنوان IP المحلي، مثل:
     ```
     http://192.168.1.100:8069/web/login
     ```
   - احفظ الإعدادات
   - سيعمل التطبيق مع الخادم المحلي

2. أعد بناء التطبيق:
   ```bash
   flutter clean
   flutter run
   ```

## ملاحظات أمنية:

⚠️ **للإنتاج (Production):**
- يُفضل تقييد `cleartextTrafficPermitted` لعناوين محددة فقط
- استخدم HTTPS حيثما أمكن
- الإعدادات الحالية مناسبة للتطوير والشبكات المحلية

⚠️ **للـ iOS:**
- قد يطلب iOS من المستخدم السماح بالوصول للشبكة المحلية عند أول استخدام
- هذا طبيعي ومطلوب من Apple


