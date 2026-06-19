//
//  zsign_bridge.h
//  جسر يربط محرك zsign (C++) مع كود Swift عبر واجهة C
//

#ifndef zsign_bridge_h
#define zsign_bridge_h

#ifdef __cplusplus
extern "C" {
#endif

/// توقيع IPA
/// @return 0 عند النجاح، قيمة غير صفرية عند الفشل
int zsign_sign(const char* ipaPath,
               const char* p12Path,
               const char* provPath,
               const char* password,
               const char* outputPath,
               const char* newBundleId,    // "" لتجاهله
               const char* newBundleName,  // "" لتجاهله
               const char* newIconPath,    // "" لتجاهله
               const char** dylibs,        // مصفوفة منتهية بـ NULL
               int dylibCount);

/// فحص صلاحية الشهادة عبر OCSP
/// @return 0 صالحة، 1 مقفلة، 2 منتهية، -1 خطأ
int zsign_check_cert(const char* p12Path,
                     const char* password,
                     char* outStatus,
                     int outLen);

#ifdef __cplusplus
}
#endif

#endif /* zsign_bridge_h */
