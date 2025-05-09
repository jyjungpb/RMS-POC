import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import '../service/tcp_service.dart';
import '../utils/webview_actions.dart';

class WebViewController extends GetxController {
  InAppWebViewController? webViewController;
  RxString currentUrl = "".obs;
  RxBool isLoggedIn = false.obs;
  RxBool isWaiting = false.obs;
  RxBool isMainLoaded = false.obs;
  RxList<String> logs = <String>[].obs;

  RxBool isLoading = false.obs;

  final String baseUrl = "http://192.168.0.204:8070";
  final String httpUrl = "http://192.168.0.16:8080";
  final String loginUrl =
      "http://192.168.0.25:8070/Authenticate?userid=dev&passwd=elqpffhvj&language=kor";

  void addLog(String log) => logs.insert(0, log);

  void setWebViewController(InAppWebViewController controller) {
    webViewController = controller;
  }

  Future<void> navigateToPage(String pagePath) async {
    final url = "$baseUrl$pagePath";
    await webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    addLog("🌐 페이지 이동 명령 수행: $url");
  }

  Future<NavigationActionPolicy> handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    currentUrl.value = action.request.url.toString();
    addLog("🔄 이동 감지: ${currentUrl.value}");
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> handleLoadStop(
    InAppWebViewController controller,
    Uri? url,
  ) async {
    final html = await controller.evaluateJavascript(
      source: "document.documentElement.outerHTML",
    );

    currentUrl.value = url.toString();

    if (url.toString().contains("/Waiting")) {
      isWaiting.value = true;
      if (html.contains("WaitingRefresh")) {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri("$baseUrl/WaitingRefresh")),
        );
        addLog("페이지 이동 감지: WaitingRefresh");
      }
    } else if (url.toString().contains("/WaitingRefresh")) {
      isWaiting.value = true;
      if (html.contains('window.top.location.href = "/"')) {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri("$baseUrl/Main")),
        );
        addLog("페이지 이동 감지: Main");
      } else {
        Future.delayed(Duration(seconds: 1), () async {
          await controller.reload();
        });
      }
    } else if (url.toString().contains("/Main")) {
      await TCPService().connect();
      addLog("페이지 이동 감지: Main");
      isLoggedIn.value = true;
      isMainLoaded.value = true;
    } else if (url.toString().contains("/Xml")) {
      addLog("페이지 이동 완료: XML");
      await WebViewActions.injectUploadFunction(webViewController);
      await WebViewActions.sendExtractedXmlSection(this);
      isLoggedIn.value = true;
      isMainLoaded.value = true;
    } else if (url.toString().contains("/Config")) {
      isLoggedIn.value = true;
      isMainLoaded.value = true;
    } else if (url.toString().contains("/LogFiles")) {
      await WebViewActions.sendExtractedLogSection(this);

      isLoggedIn.value = true;
      isMainLoaded.value = true;
    }
  }

  // Future<void> updateCalibrationExpire(
  //   InAppWebViewController controller,
  // ) async {
  //   await controller.evaluateJavascript(
  //     source: "document.getElementById('CalibrationExpire').value = '301';",
  //   );
  //   await controller.evaluateJavascript(
  //     source: "document.getElementById('MobileAccessCode').value = '0001';",
  //   );
  //   await controller.evaluateJavascript(source: "config_submit();");
  //   print("✅ 면역 보정 만료일 45일로 설정하고 저장 완료");
  // }
}
