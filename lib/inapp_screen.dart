import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:ivdm_client/utils/webview_actions.dart';

import 'controller/webview_controller.dart';

class WebViewPage extends StatelessWidget {
  final WebViewController webViewController = Get.put(WebViewController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("InAppWebView - 자동 로그인")),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              return Stack(
                children: [
                  Container(
                    color: Colors.black,
                    child: ListView.builder(
                      reverse: true,
                      itemCount: webViewController.logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            webViewController.logs[index],
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Visibility(
                    visible: !webViewController.isLoading.value,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ],
              );
            }),
          ),
          Offstage(
            offstage: true,
            child: SizedBox(
              height: 1,
              child: Obx(() {
                webViewController.isLoading.value;
                return InAppWebView(
                  onProgressChanged: (controller, percent) async {
                    print('percent. :${percent}');
                    webViewController.isLoading.value = false;
                    if (percent == 100) {
                      print('percentcc. :${percent}');

                      webViewController.isLoading.value = true;
                    }
                  },
                  // 2) 다운로드 클릭 감지 → JS fetch 실행
                  onDownloadStartRequest: (controller, download) async {
                    final url = download.url.toString();
                    print('url :${url}');
                    webViewController.isLoading.value = false;
                    final filename = download.suggestedFilename ?? 'file';
                    webViewController.addLog("📥 다운로드 요청: $url");
                    print("📥 다운로드 요청: $url");

                    final js = """
                            fetch("$url", { credentials: 'include' })
                .then(resp => resp.arrayBuffer())
                .then(buf => {
                  let binary = '';
                  let bytes = new Uint8Array(buf);
                  for (let i = 0; i < bytes.byteLength; i++) {
                    binary += String.fromCharCode(bytes[i]);
                  }
                  let b64 = btoa(binary);
                  window.flutter_inappwebview.callHandler('onFileDownloaded', b64, "$filename");
                })
                .catch(err => {
                  window.flutter_inappwebview.callHandler('onFileDownloaded', '', "$filename");
                });
                          """;
                    await controller.evaluateJavascript(source: js);
                  },
                  initialUrlRequest: URLRequest(
                    url: WebUri(webViewController.loginUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    mixedContentMode:
                        MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    javaScriptEnabled: true,
                    allowFileAccessFromFileURLs:
                        true, // file:// 로드 시 파일 접근 허용 (필요 시)
                    allowUniversalAccessFromFileURLs:
                        true, // file:// → 네트워크 요청 허용 (필요 시)
                    // Android 다운로드 콜백이 필요하면:
                    useOnDownloadStart:
                        true, // onDownloadStart 콜백을 활성화                  userAgent: "Mozilla/5.0 (Flutter InAppWebView)",
                  ),
                  onWebViewCreated: (controller) {
                    webViewController.setWebViewController(controller);
                    // 1) JS → Flutter 메시지 핸들러 등록
                    controller.addJavaScriptHandler(
                      handlerName: 'onFileDownloaded',

                      callback: (args) async {
                        // args[0]: base64 string, args[1]: filename
                        final base64Str = args[0] as String;
                        final filename = args[1] as String;
                        webViewController.addLog(
                          "✅ 파일 패치 완료: $filename, 크기=${base64Str.length} ",
                        );

                        // 2) base64 → Uint8List
                        Uint8List fileBytes = base64.decode(base64Str);
                        await WebViewActions.uploadFileMultipart(
                          fileBytes,
                          filename,
                          webViewController,
                        );
                        webViewController.addLog("✅ 파일 업로드 완료 ");
                        webViewController.isLoading.value = true;
                      },
                    );
                  },
                  shouldOverrideUrlLoading: (
                    controller,
                    navigationAction,
                  ) async {
                    return await webViewController.handleNavigation(
                      controller,
                      navigationAction,
                    );
                  },
                  onJsConfirm: (controller, JsConfirmRequest request) async {
                    // 여기가 중요 — 자동으로 "확인" 선택해줌
                    return JsConfirmResponse(
                      handledByClient: true,
                      action: JsConfirmResponseAction.CONFIRM,
                    );
                  },
                  onJsAlert: (controller, JsAlertRequest request) async {
                    return JsAlertResponse(
                      handledByClient: true,
                      action: JsAlertResponseAction.CONFIRM,
                    );
                  },
                  onLoadStop: (controller, url) async {
                    await webViewController.handleLoadStop(controller, url);
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
