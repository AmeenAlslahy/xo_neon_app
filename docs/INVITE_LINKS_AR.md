# روابط دعوة الغرف — التشغيل والنشر

**آخر تحديث:** 11 نوفمبر 2026

## 1. الوضع الحالي

> **حالة الإصلاح — 11 نوفمبر 2026:** الكود يُنشئ رابط HTTPS قابلًا للنقر، والصفحة تعمل محليًا، وإعداد Firebase الحالي صحيح (المفاتيح الثلاثة تعمل وAnonymous Auth مفعّل). **لكن الإصلاح ليس مكتملًا إنتاجيًا:**
> - `https://xo-neon-online.web.app/join?...` و`https://xo-neon-online.firebaseapp.com/join?...` ما زالا يعيدان **HTTP 404** لأن Firebase Hosting لم يُنشر بعد.
> - **أُعيد بناء APK/release** بالبيانات الحقيقية، وتأكد الفحص من عدم وجود `AIzaSyDemo`. استخدم الحزم الجديدة في `release/` وليس أي نسخة قديمة.
> - **أُزيل UID الاحتياطي** `guest_...` (P0-03)، وأصبح فشل المصادقة يعرض رسالة عربية واضحة ويمنع الإنشاء/الانضمام.
> - **أُضيفت رسائل أخطاء محلية** للغرفة غير الموجودة أو المنتهية، وللشبكة، وللمحاولات الكثيرة؛ لا يظهر نص Firebase خام.
> - قاعدة RTDB مغلقة أمام غير المصادقين (401)، وهذا هو الوضع الصحيح؛ لا تُعد فتحها.

أصبحت دعوة الغرفة تُشارك كرابط HTTPS قابل للنقر:

```text
https://xo-neon-online.web.app/join?code=XXXXXX&lang=ar
```

- `XXXXXX`: رمز الغرفة (6 أحرف).
- `lang`: اختياري، `ar` أو `en`.
- الصفحة موجودة في `web/join/index.html` وتُنسخ إلى `build/web/join/index.html` عند البناء.
- زر «افتح التطبيق» يستخدم `xoneon://join?code=XXXXXX`، ويستخدم `intent://` على Android لزيادة فرص فتح التطبيق من المتصفح.
- الكود في `lib/features/online/application/deep_link_service.dart`:
  - `createInviteLink` يبني رابط HTTPS.
  - `createAppLink` يبني رابط custom scheme.
  - `parseRoomCode` يقبل HTTPS و`xoneon://` معًا.

## 2. ما يتبقى قبل أن يعمل الرابط للجميع

الرابط لن يعمل حتى تُنشر الصفحة على Firebase Hosting. النشر يحتاج تسجيل دخول بحساب يملك مشروع `xo-neon-online`، ولم يكن ذلك متاحًا في بيئة التنفيذ. التحقق الحالي يعيد **HTTP 404** من النطاقين.

وقبل أن يكتمل الانضمام من طرف إلى طرف، يجب أيضًا:

1. ✅ **أُعيد بناء APK/release** بالبيانات الحالية، ولا يحتوي `libapp.so` على `AIzaSyDemo`.
2. ✅ تم التحقق من نجاح `ensureSignedIn()` شبكيًا (Anonymous Auth يعمل)، والتطبيق يوقف العملية عند فشلها.
3. ✅ أُزيل UID الاحتياطي `guest_...`، وتظهر رسالة عربية عند فشل المصادقة.
4. إبقاء RTDB مغلقة (401) والتأكد من أن القواعد المنشورة تطابق `firebase/database.rules.json`.
5. اختبار إنشاء غرفة والانضمام إليها من جهازين على الإنتاج باستخدام APK الجديد.

### أ. نشر صفحة الويب

```powershell
npm install -g firebase-tools
firebase login
cd D:\xo_neon_app
firebase use xo-neon-online
flutter build web --release
firebase deploy --only hosting
```

> **مهم:** استخدم `--only hosting`. الأمر `firebase deploy` وحده قد ينشر قواعد قاعدة البيانات أيضًا، وهذا خارج نطاق إصلاح رابط الدعوة.

### ب. التحقق

افتح:

```text
https://xo-neon-online.web.app/join?code=TEST99&lang=ar
```

يجب أن تظهر صفحة عربية تعرض `TEST99` وزر «افتح التطبيق» وزر نسخ. ثم جرّب:

```text
https://xo-neon-online.web.app/join?code=BAD
```

يجب أن تظهر رسالة «رابط الدعوة غير صالح» بلا زر فتح.

## 3. فتح التطبيق تلقائيًا (Android App Links)

حاليًا يسجل `AndroidManifest.xml` نطاق HTTPS مع `pathPrefix="/join"` لكن **بدون** `autoVerify`. النتيجة: قد يفتح الرابط في المتصفح أولًا، ثم يستخدم المستخدم زر «افتح التطبيق». هذا مقبول كحل احتياطي، لكنه ليس فتحًا مباشرًا.

للتفعيل المباشر بعد تثبيت توقيع release:

1. احصل على بصمة SHA-256 لشهادة release:
   ```powershell
   keytool -list -v -keystore <مسار-keystore> -alias <alias>
   ```
2. أنشئ `web/.well-known/assetlinks.json`:
   ```json
   [
     {
       "relation": ["delegate_permission/common.handle_all_urls"],
       "target": {
         "namespace": "android_app",
         "package_name": "com.antigravity.xo.xo_neon_app",
         "sha256_cert_fingerprints": [
           "XX:XX:...:XX"
         ]
       }
     }
   ]
   ```
3. أضف `android:autoVerify="true"` إلى intent-filter الخاص بـHTTPS في `AndroidManifest.xml`.
4. أعد بناء التطبيق ونشر الاستضافة:
   ```powershell
   flutter build web --release
   firebase deploy --only hosting
   ```
5. تحقق من:
   ```text
   https://xo-neon-online.web.app/.well-known/assetlinks.json
   ```

لا تضع بصمة مفتاح debug في `assetlinks.json` الخاص بالإنتاج. البصمة يجب أن تطابق الشهادة التي وُقّع بها APK المثبت فعلًا.

## 4. iOS Universal Links (اختياري لكن موصى به)

بدون Universal Links، سيفتح رابط HTTPS في Safari، ثم يستخدم المستخدم زر «افتح التطبيق» عبر `xoneon://`. هذا يعمل إذا كان التطبيق مثبتًا.

للتفعيل المباشر:

1. أضف entitlement:
   ```xml
   <key>com.apple.developer.associated-domains</key>
   <array>
     <string>applinks:xo-neon-online.web.app</string>
   </array>
   ```
2. انشر `https://xo-neon-online.web.app/.well-known/apple-app-site-association` بصيغة JSON وبلا امتداد.
3. أعد توقيع التطبيق بحساب Apple مطابق، واختبر من Notes/Messages/Safari.

## 5. اختبار القبول

| الحالة | المتوقع |
|---|---|
| WhatsApp/Telegram: إرسال الدعوة | يظهر الرابط جزءًا قابلًا للنقر |
| الضغط على الرابط مع التطبيق المثبت | فتح التطبيق على شاشة الانضمام بالرمز، أو صفحة `/join` مع زر فتح |
| الضغط بدون التطبيق | صفحة `/join` تعرض الرمز ورسالة التثبيت |
| رمز غير صالح | رسالة خطأ محلية، بلا زر فتح |
| العربية/الإنجليزية | الصفحة تتبع `lang`، وتبديل اللغة يعمل |
| نسخ الرمز | يعمل على HTTPS وعلى `file://` عبر fallback |
| الانضمام بعد فتح التطبيق | يجب أن ينجح باستخدام APK الجديد؛ إذا فشل، تظهر رسالة عربية واضحة تحدد السبب (غرفة غير متاحة/شبكة/مصادقة) |

## 6. استكشاف الأخطاء

- **الصفحة تعيد 404:** لم يُنشر الموقع، أو `build/web/join/index.html` غير موجود. نفّذ `flutter build web --release` ثم `firebase deploy --only hosting`.
- **الرابط يفتح المتصفح دائمًا:** هذا متوقع قبل `autoVerify` و`assetlinks.json`. استخدم زر «افتح التطبيق» مؤقتًا.
- **زر «افتح التطبيق» لا يفعل شيئًا:** تأكد أن التطبيق مثبت، وأن `applicationId` هو `com.antigravity.xo.xo_neon_app`، وأن `xoneon` ما زال مسجلًا في `AndroidManifest.xml` و`Info.plist`.
- **التطبيق يفتح لكن لا يملأ الرمز:** تحقق من `parseRoomCode` ومن وصول `app_links` إلى الرابط. اختبر `xoneon://join?code=TEST99` مباشرة.
- **الصفحة تفتح لكن الانضمام يفشل:** لم تعد تظهر رسالة `Permission denied` الخام. إذا ظهرت «تعذر العثور على الغرفة» فالرمز غير صحيح أو الغرفة انتهت/أُغلقت. إذا ظهرت رسالة المصادقة، تحقق من الاتصال بـ`accounts:signUp` (يجب أن يعيد 200). إذا ظهر خطأ شبكة، تحقق من الاتصال ثم أعد المحاولة. استخدم APK الجديد من `release/`، ولا تفتح RTDB للعامة كحل مؤقت.
- **تغييرات الصفحة لا تظهر:** تحقق من رأس `Cache-Control` في `firebase.json`، ثم أعد النشر.

## 7. ملاحظات أمان

- الصفحة ثابتة ولا تقرأ RTDB ولا تعرض أسماء اللاعبين أو UIDs أو النتائج.
- لا تضع أي أسرار في `web/join/index.html`.
- نشر الاستضافة لا يغيّر قواعد قاعدة البيانات. قاعدة RTDB الإنتاجية مغلقة حاليًا (401)، والمصادقة تعمل بالمفاتيح الحقيقية؛ لا تُعد فتح RTDB للعامة كحل مؤقت لرابط الدعوة.
