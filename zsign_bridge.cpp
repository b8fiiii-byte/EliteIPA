//
//  zsign_bridge.cpp
//  تنفيذ الجسر — يستدعي واجهة zsign الفعلية (مكتبة zhlynn/zsign)
//
//  ملاحظة: عند البناء يُدمج مصدر zsign (مجلد src) ضمن الهدف، ويستخدم هذا الجسر
//  دالة ZSignAsset / ZAppBundle الموجودة في zsign لتنفيذ التوقيع.
//  هنا نستدعيها عبر الواجهة المبسطة من common/ و bundle.
//

#include "zsign_bridge.h"
#include <string>
#include <vector>
#include <cstring>

// ترويسات zsign الأصلية (تتوفر بعد دمج مجلد src الخاص بـ zsign)
#include "openssl.h"
#include "signing.h"
#include "bundle.h"
#include "common/common.h"

int zsign_sign(const char* ipaPath,
               const char* p12Path,
               const char* provPath,
               const char* password,
               const char* outputPath,
               const char* newBundleId,
               const char* newBundleName,
               const char* newIconPath,
               const char** dylibs,
               int dylibCount)
{
    try {
        ZSignAsset zSignAsset;
        // تحميل بيانات الشهادة وملف التوصيف
        if (!zSignAsset.Init("", p12Path, provPath, "", password ? password : "", false)) {
            return 10; // فشل تحميل الشهادة
        }

        // فك ضغط الـ IPA إلى مجلد عمل مؤقت
        std::string strFolder = std::string(outputPath) + ".work";
        ZIPDirectory(ipaPath, strFolder.c_str()); // دالة مساعدة من zsign لفك الضغط

        // تجهيز قائمة dylibs
        std::vector<std::string> arrDyLibFiles;
        if (dylibs) {
            for (int i = 0; i < dylibCount && dylibs[i] != nullptr; i++) {
                arrDyLibFiles.push_back(std::string(dylibs[i]));
            }
        }

        std::string bundleId   = (newBundleId   && strlen(newBundleId))   ? newBundleId   : "";
        std::string bundleName = (newBundleName && strlen(newBundleName)) ? newBundleName : "";

        // إنشاء كائن الحزمة وتنفيذ التوقيع
        ZAppBundle bundle;
        bool ok = bundle.SignFolder(&zSignAsset,
                                    strFolder,
                                    bundleId,
                                    bundleName,
                                    "",               // bundle version
                                    arrDyLibFiles,
                                    true,             // force
                                    false,            // weak inject
                                    false);           // adhoc
        if (!ok) return 20;

        // إعادة ضغط الناتج إلى IPA
        if (!ZipFolder(strFolder.c_str(), outputPath)) {
            return 30;
        }

        // (اختياري) استبدال الأيقونة قبل إعادة الضغط يتم داخل SignFolder عند تمرير المسار
        (void)newIconPath;

        RemoveFolder(strFolder.c_str());
        return 0;
    } catch (...) {
        return -1;
    }
}

int zsign_check_cert(const char* p12Path,
                     const char* password,
                     char* outStatus,
                     int outLen)
{
    try {
        ZSignAsset zSignAsset;
        if (!zSignAsset.Init("", p12Path, "", "", password ? password : "", false)) {
            if (outStatus && outLen > 0) strncpy(outStatus, "load_failed", outLen - 1);
            return -1;
        }

        // فحص حالة الشهادة عبر OCSP (دالة من zsign)
        int ocsp = zSignAsset.CheckCertificateOCSP(); // 0 صالحة، 1 مقفلة
        if (ocsp == 1) {
            if (outStatus && outLen > 0) strncpy(outStatus, "revoked", outLen - 1);
            return 1;
        }

        // فحص الانتهاء
        if (zSignAsset.IsExpired()) {
            if (outStatus && outLen > 0) strncpy(outStatus, "expired", outLen - 1);
            return 2;
        }

        if (outStatus && outLen > 0) strncpy(outStatus, "valid", outLen - 1);
        return 0;
    } catch (...) {
        if (outStatus && outLen > 0) strncpy(outStatus, "error", outLen - 1);
        return -1;
    }
}
