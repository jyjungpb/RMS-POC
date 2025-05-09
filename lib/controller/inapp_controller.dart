import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class WebViewControllerX extends GetxController {
  InAppWebViewController? webViewController;
  RxString currentUrl = "".obs;
  RxBool isLoggedIn = false.obs;
  RxBool isWaiting = false.obs;
  RxBool isMainLoaded = false.obs;
  final String baseUrl = "http://192.168.0.204:8070";
  final String httpUrl = "http://192.168.0.16:8080";
  final String loginUrl =
      "http://192.168.0.25:8070/Authenticate?userid=dev&passwd=elqpffhvj&language=kor";
  Socket? socket;
  RxList<String> logs = <String>[].obs;

  @override
  void onInit() {
    //connectToTCPServer();
    super.onInit();
  }

  void addLog(String log) {
    logs.insert(0, log);
  }

  void connectToTCPServer() async {
    try {
      socket = await Socket.connect("192.168.0.16", 9000);
      addLog("🔌 TCP 서버에 연결됨");

      StringBuffer jsonBuffer = StringBuffer();

      socket!.listen((data) async {
        final chunk = utf8.decode(data);
        print('🔹 수신 chunk: $chunk');
        addLog("수신 chunk: $chunk");

        // 1️⃣ 단일 명령 (즉시 처리 후 종료)
        if (chunk.startsWith("NAVIGATE:")) {
          final target = chunk.replaceFirst("NAVIGATE:", "");
          await navigateToPage(target);
          addLog("🌐 페이지 이동 감지: $target");
          return; // ✅ 버퍼에 안쌓이게 바로 리턴
        }

        if (chunk.startsWith("SET:") || chunk.startsWith("CALL:")) {
          final parts = chunk.split(":");
          if (parts[0] == 'SET' && parts.length >= 3) {
            final id = parts[1];
            final value = parts[2];
            await webViewController?.evaluateJavascript(
              source: "document.getElementById('$id').value = '$value';",
            );
            return; // ✅ 바로 리턴
          } else if (parts[0] == 'CALL' && parts.length >= 2) {
            final fn = parts[1];
            if (fn == 'applydb') {
              await webViewController?.evaluateJavascript(
                source: "document.frmApplyDB.submit();",
              );
            } else {
              await webViewController?.evaluateJavascript(source: "$fn();");
            }
            return; // ✅ 여기서도 리턴
          }
        }

        // 2️⃣ 그 외는 JSON 명령일 가능성 → 버퍼에 누적
        jsonBuffer.write(chunk);

        final bufferStr = jsonBuffer.toString();

        if (bufferStr.contains("<EOF>")) {
          final completeJson = bufferStr.replaceAll("<EOF>", "").trim();

          try {
            final decoded = jsonDecode(completeJson);
            jsonBuffer.clear(); // ✅ 파싱 성공 시 초기화
            addLog("📬 JSON 파싱 성공: ${decoded['type']}");

            if (currentUrl.value.contains("/Xml")) {
              if (decoded['type'] == 'delete') {
                final filename = decoded['filename'];
                final command = decoded['command'];
                addLog("🗑️ 삭제 명령: $filename - $command");
                await webViewController?.evaluateJavascript(source: command);
                await sendExtractedXmlSection();
                socket?.write("REFRESH:/Xml");
              } else if (decoded['type'] == 'upload') {
                final filename = decoded['filename'];
                final base64 = decoded['base64'];
                addLog("📦 업로드 명령 수신: $filename");
                await webViewController?.evaluateJavascript(
                  source: "uploadFileToForm('$filename', '$base64');",
                );
                addLog("📤 WebView에 업로드 명령 전달 완료");
                await Future.delayed(Duration(seconds: 1)); // 업로드 완료 대기 (필요 시)
                await sendExtractedXmlSection(); // 반드시 호출
                socket?.write("REFRESH:/Xml");
              }
            }
          } catch (e) {
            addLog("❌ JSON 파싱 실패: $e");
            jsonBuffer.clear(); // 실패해도 초기화
          }
        }
      });
    } catch (e) {
      addLog("❌ TCP 연결 오류: $e");
    }
  }

  Future<void> navigateToPage(String pagePath) async {
    if (webViewController != null) {
      final url = "$baseUrl$pagePath";
      await webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
      addLog("🌐 페이지 이동 명령 수행: $url");
    }
  }

  void setWebViewController(InAppWebViewController controller) {
    webViewController = controller;
  }

  Future<NavigationActionPolicy> handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final url = action.request.url.toString();
    addLog("🔄 이동 감지: $url");

    currentUrl.value = url;

    return NavigationActionPolicy.ALLOW;
  }

  Future<void> sendExtractedXmlSection() async {
    if (webViewController != null) {
      final extractedHtml = await webViewController!.evaluateJavascript(
        source: r"""
(() => {
  const frmContent = document.getElementById('frmContent');
  const frmApplyDB = document.getElementById('frmApplyDB');
  
  if (!frmContent || !frmApplyDB) {
    return "필요한 폼 요소를 찾지 못했습니다.";
  }
  
  // 두 폼이 같은 부모를 가진다고 가정
  const parent = frmContent.parentNode;
  const children = Array.from(parent.children);
  
  const startIndex = children.indexOf(frmContent);
  const endIndex = children.indexOf(frmApplyDB);
  
  if (startIndex === -1 || endIndex === -1 || startIndex > endIndex) {
    return "범위 설정에 오류가 있습니다.";
  }
  
  let extractedHtml = "";
  for (let i = startIndex; i <= endIndex; i++) {
    extractedHtml += children[i].outerHTML;
  }
  
  return extractedHtml;
})()
      """,
      );

      // 추출한 HTML을 서버 API로 전송하는 코드
      final apiUrl = "$httpUrl/api/panel-xml-section";
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "text/plain"},
          body: extractedHtml,
        );
        if (response.statusCode == 200) {
          addLog("📤 XML 파일 섹션 전송 완료");
        } else {
          addLog("❌ 전송 실패, 상태 코드: ${response.statusCode}");
        }
      } catch (e) {
        addLog("❌ 전송 오류: $e");
      }
    }
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
      connectToTCPServer();
      addLog("페이지 이동 감지: Main");
      isLoggedIn.value = true;
      isMainLoaded.value = true;
    } else if (url.toString().contains("/Config")) {
      addLog("페이지 이동 완료: Config");

      isLoggedIn.value = true;
      isMainLoaded.value = true;
    } else if (url.toString().contains("/Xml")) {
      addLog("페이지 이동 완료: XML");
      await injectUploadFunction();
      addLog("XML 페이지 로드 완료: HTML 전송 시도");
      await sendExtractedXmlSection();
      isLoggedIn.value = true;
      isMainLoaded.value = true;
    } else if (url.toString().contains("/log")) {
      addLog("페이지 이동 완료: LOG");

      isLoggedIn.value = true;
      isMainLoaded.value = true;
    }
  }

  Future<void> injectUploadFunction() async {
    const jsCode = """
    window.uploadFileToForm = function(filename, base64Data) {
      const byteCharacters = atob(base64Data);
      const byteNumbers = new Array(byteCharacters.length);
      for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
      }
      const byteArray = new Uint8Array(byteNumbers);
      const blob = new Blob([byteArray], { type: 'text/xml' });

      const file = new File([blob], filename, { type: 'text/xml' });

      const dataTransfer = new DataTransfer();
      dataTransfer.items.add(file);
      document.getElementById('xmlfile').files = dataTransfer.files;

      document.getElementById('frmUpload').submit();
    };
  """;

    await webViewController?.evaluateJavascript(source: jsCode);
    addLog('XML 페이지 기능 추가 완료');
  }

  Future<void> updateCalibrationExpire(
    InAppWebViewController controller,
  ) async {
    // 1. 값 수정
    await controller.evaluateJavascript(
      source: "document.getElementById('CalibrationExpire').value = '301';",
    );

    await controller.evaluateJavascript(
      source: "document.getElementById('MobileAccessCode').value = '0001';",
    );
    // 2. 저장 실행
    await controller.evaluateJavascript(source: "config_submit();");

    print("✅ 면역 보정 만료일 45일로 설정하고 저장 완료");
  }
}
