# صانع الريلز (Reels Maker)

تطبيق لويندوز (exe) وأندرويد (apk) بيصنع ريلز كاملة لحاله: بيجيب التريند، بيكتب السكربت بـ Claude، بيعمل تعليق صوتي بلهجة سعودية/شامية، بيجيب مقاطع، بيعمل مونتاج وموشن جرافيك وكابشن عربي متحرك، وبيرفع الفيديو على Google Drive.

## التنزيل

من صفحة **Releases** بالمستودع (بتتحدث تلقائياً مع كل تعديل):

- **ويندوز:** `ReelsMaker-Setup.exe` (مثبّت) أو `ReelsMaker-Windows-Portable.zip` (فك الضغط وشغّل `ReelsMaker.exe`).
- **أندرويد:** `ReelsMaker-Android-arm64.apk` لأغلب الجوالات، و `arm32` للجوالات القديمة.

## شو بيعمل

| المرحلة | أونلاين | بدون نت |
|---|---|---|
| التريند | Google Trends، Google News، Reddit، YouTube، وبحث Claude على النت | — |
| السكربت | Claude (Opus 5.5 افتراضياً) بلهجة بتختارها | مولّد بسيط بيقسم نصك لمشاهد |
| التعليق الصوتي | منصت، ElevenLabs، Hugging Face | صوت الجهاز (ويندوز وأندرويد) |
| المقاطع | Pexels، Pixabay، صور AI من Hugging Face | ملفاتك، أو خلفيات متحركة |
| المونتاج | ffmpeg جوا التطبيق: انتقالات، زوم على الصور، خلفية مموهة للمقاطع الأفقية، فلاتر لونية | نفس الشي |
| الموشن جرافيك | جملة افتتاح متحركة، كابشن كلمة بكلمة، عناوين المشاهد، شريط تقدم، علامة مائية، جملة نهاية | نفس الشي |
| الموسيقى | ملفاتك (عشوائي) مع توطية وقت الكلام | موسيقى هادئة مولدة |
| النشر | رفع على Google Drive، مشاركة لانستغرام وتيك توك | حفظ بالجهاز |

وفوق هيك: 7 قوالب شكل (نيون، أخبار عاجلة، قصص، رعب، هادئ، رياضة، فخامة)، محرر يدوي للمشاهد (تعديل النص، إعادة كتابة بالذكاء الاصطناعي، تبديل المقطع، ترتيب)، ملف SRT ونص المنشور مع الهاشتاجات لكل ريل، وتشغيل تلقائي كل كم ساعة.

## الإعداد (مرة وحدة)

كل شي من صفحة **الإعدادات** بالتطبيق:

1. **Claude:** مفتاح من [console.anthropic.com](https://console.anthropic.com/settings/keys).
2. **الصوت:** مفتاح منصت واختار صوت (نجدي أو حجازي أقرب للشامي)، أو مفتاح ElevenLabs واختار صوت سعودي.
3. **المقاطع:** مفتاح Pexels المجاني من [pexels.com/api](https://www.pexels.com/api/new/).
4. **Google Drive:** اعمل OAuth Client من نوع *TVs and Limited Input devices* بـ Google Cloud Console، حط الـ Client ID والـ Secret، واضغط "ربط". الشرح بالتفصيل جوا التطبيق.

بعدين من **الرئيسية** اختار موضوع واضغط **ابدأ الآن**.

## للمطوّرين

- Flutter 3.47، الكود بـ `lib/`:
  - `services/renderer.dart` و `services/captions.dart`: المونتاج والموشن جرافيك (ffmpeg + ASS).
  - `services/script_writer.dart`: Claude API (Structured Outputs + Web Search).
  - `services/tts.dart`، `media.dart`، `trends.dart`، `drive.dart`، `pipeline.dart`.
- تجربة المونتاج من سطر الأوامر (بدها ffmpeg مثبت): `dart run tool/render_test.dart <مجلد>`
- البناء: GitHub Actions بـ `.github/workflows/build.yml` بيبني exe و apk وبينشرهم بـ Releases.
- الخط: Tajawal (رخصة OFL، `assets/fonts/OFL.txt`).
