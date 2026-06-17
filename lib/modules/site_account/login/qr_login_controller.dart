import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/sites.dart';

class SiteQRLoginController extends GetxController {
  final Site site;

  SiteQRLoginController({required this.site});

  Timer? timer;
  final qrcodeUrl = ''.obs;
  var qrcodeKey = '';
  final qrStatus = QRStatus.loading.obs;

  @override
  void onInit() {
    super.onInit();
    loadQRCode();
  }

  Future<void> loadQRCode() async {
    try {
      timer?.cancel();
      timer = null;
      qrStatus.value = QRStatus.loading;

      final qrBean = await site.liveSite.loadQRCode();
      qrStatus.value = qrBean.qrStatus;
      qrcodeUrl.value = qrBean.qrcodeUrl;
      qrcodeKey = qrBean.qrcodeKey;
      startPoll();
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
      qrStatus.value = QRStatus.failed;
    }
  }

  void startPoll() {
    timer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      pollQRStatus();
    });
  }

  Future<void> pollQRStatus() async {
    try {
      var qrBean = QRBean()
        ..qrcodeUrl = qrcodeUrl.value
        ..qrcodeKey = qrcodeKey
        ..qrStatus = qrStatus.value;

      qrBean = await site.liveSite.pollQRStatus(site, qrBean);
      qrStatus.value = qrBean.qrStatus;
      qrcodeUrl.value = qrBean.qrcodeUrl;
      qrcodeKey = qrBean.qrcodeKey;

      switch (qrStatus.value) {
        case QRStatus.expired:
        case QRStatus.failed:
          timer?.cancel();
          timer = null;
          break;
        case QRStatus.success:
          timer?.cancel();
          timer = null;
          Navigator.of(Get.context!).pop(true);
          break;
        default:
          break;
      }
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
      qrStatus.value = QRStatus.failed;
    }
  }

  @override
  void onClose() {
    timer?.cancel();
    super.onClose();
  }
}
