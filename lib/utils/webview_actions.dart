import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../controller/webview_controller.dart';
import '../service/tcp_service.dart';

class WebViewActions {
  static Future<void> setElement(
    String id,
    String value,
    WebViewController controller,
  ) async {
    await controller.webViewController?.evaluateJavascript(
      source: "document.getElementById('$id').value = '$value';",
    );
  }

  static Future<void> callFunction(
    String fn,
    WebViewController controller,
  ) async {
    if (fn == 'applydb') {
      await controller.webViewController?.evaluateJavascript(
        source: "document.frmApplyDB.submit();",
      );
    } else {
      await controller.webViewController?.evaluateJavascript(source: "$fn();");
    }
  }

  static Future<void> deleteXml(
    Map<String, dynamic> json,
    WebViewController controller,
    TCPService tcp,
  ) async {
    final filename = json['filename'];
    final command = json['command'];
    controller.addLog("🗑️ 삭제 명령: $filename - $command");
    await controller.webViewController?.evaluateJavascript(source: command);
    await sendExtractedXmlSection(controller);
    tcp.send("REFRESH:/Xml");
  }

  static Future<void> uploadXml(
    Map<String, dynamic> json,
    WebViewController controller,
    TCPService tcp,
  ) async {
    final filename = json['filename'];
    final base64 = json['base64'];
    controller.addLog("📦 업로드 명령 수신: $filename");

    await controller.webViewController?.evaluateJavascript(
      source: "uploadFileToForm('$filename', '$base64');",
    );
    controller.addLog("📤 WebView에 업로드 명령 전달 완료");
    await Future.delayed(Duration(seconds: 1));
    await sendExtractedXmlSection(controller);
    tcp.send("REFRESH:/Xml");
  }

  static Future<void> sendExtractedXmlSection(
    WebViewController controller,
  ) async {
    final extractedHtml = await controller.webViewController
        ?.evaluateJavascript(
          source: r"""
(() => {
  const frmContent = document.getElementById('frmContent');
  const frmApplyDB = document.getElementById('frmApplyDB');
  if (!frmContent || !frmApplyDB) return "폼 요소 없음";

  const parent = frmContent.parentNode;
  const children = Array.from(parent.children);
  const startIndex = children.indexOf(frmContent);
  const endIndex = children.indexOf(frmApplyDB);

  if (startIndex === -1 || endIndex === -1 || startIndex > endIndex)
    return "범위 오류";

  return children.slice(startIndex, endIndex + 1)
                 .map(child => child.outerHTML)
                 .join('');
})()
""",
        );

    final apiUrl = "${controller.httpUrl}/api/panel-xml-section";
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "text/plain"},
        body: extractedHtml,
      );
      controller.addLog(
        response.statusCode == 200
            ? "📤 XML 파일 섹션 전송 완료"
            : "❌ 전송 실패: ${response.statusCode}",
      );
    } catch (e) {
      controller.addLog("❌ 전송 오류: $e");
    }
  }

  static Future<void> injectUploadFunction(
    InAppWebViewController? webviewController,
  ) async {
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

    await webviewController?.evaluateJavascript(source: jsCode);
  }

  ///LogFiles
  static Future<void> sendExtractedLogSection(
    WebViewController controller,
  ) async {
    final extractedHtml = await controller.webViewController
        ?.evaluateJavascript(
          source: r"""
(() => {
  const result = {};

  const titleElements = Array.from(document.querySelectorAll("td.td_top"));
  for (const td of titleElements) {
    const title = td.textContent.trim();
    const sectionTable = td.closest("table");
    if (!title || !sectionTable) continue;

    result[title] = sectionTable.outerHTML;
  }

  return JSON.stringify(result);
})()
""",
        );
    if (extractedHtml == null || extractedHtml.isEmpty) return;

    final apiUrl = "${controller.httpUrl}/api/log-sections";
    try {
      final res = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: extractedHtml,
      );
      if (res.statusCode == 200) {
        controller.addLog("📤 로그 섹션 전송 성공");
      } else {
        controller.addLog("❌ 로그 섹션 전송 실패 - 상태: ${res.statusCode}");
      }
    } catch (e) {
      controller.addLog("❌ 로그 섹션 전송 중 오류: $e");
    }
  }

  /// LogFiles 페이지에서 다운로드 명령을 실행하고, base64로 인코딩된 파일을
  /// TCPService를 통해 서버로 전송합니다.
  late String downLoadCommand = '';
  static Future<void> downloadLogFile(
    Map<String, dynamic> decoded,
    WebViewController controller,
    TCPService tcp,
  ) async {
    final dynamic cmdDyn = decoded['command'];
    if (cmdDyn == null) {
      controller.addLog("❌ 다운로드 명령(cmd) 누락");
      return;
    }
    final String command = cmdDyn.toString();
    controller.addLog("📥 다운로드 명령 실행 중: $command");

    try {
      final regex = RegExp(
        r'''downloadfile\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]\s*\)''',
      ).firstMatch(command);
      if (regex == null) {
        controller.addLog("❌ 잘못된 다운로드 커맨드 포맷");
        return;
      }
      final filename = regex.group(1)!;
      final filetype = regex.group(2)!;
      // 3️⃣ 실제 다운로드 URL 조립
      String url;
      if (filetype == "capturescreen_data") {
        url =
            "${controller.baseUrl}/Capture?cmd=download&filename=$filename&filetype=$filetype";
      } else if (filetype.startsWith("qrcodeimage")) {
        url =
            "${controller.baseUrl}/QRCodeImage?cmd=download&filename=$filename&filetype=$filetype";
      } else {
        url =
            "${controller.baseUrl}/LogFiles?cmd=download&filename=$filename&filetype=$filetype";
      }
      controller.addLog("🌐 다운로드 URL 로드: $url");

      // 4️⃣ URL 로드 → onDownloadStartRequest 콜백 타게 하기
      await controller.webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );

      controller.addLog("📤 base64 파일 데이터 전송 완료");
    } catch (e) {
      controller.addLog("❌ JS 실행 오류: $e");
    }
  }

  /// fileBytes: 다운로드된 바이너리, filename: ex) "sba.zip"
  static Future<void> uploadFileMultipart(
    Uint8List fileBytes,
    String filename,
    WebViewController controller,
  ) async {
    print('✅ Multipart upload 00000');

    final uri = Uri.parse('${controller.httpUrl}/api/upload-file');
    final request = http.MultipartRequest('POST', uri)
      // 필드 이름 'file' 은 자유롭게 정하되, 서버와 맞춰야 합니다.
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filename,
          contentType: MediaType('application', 'zip'), // 필요에 따라 변경
        ),
      );
    print('✅ Multipart upload 성공222');
    // 실행
    final streamedResponse = await request.send();
    print('✅ 서버 응답 상태: ${streamedResponse.statusCode}');
    // 응답 바디(파일 다운로드 스트림)를 모두 버리고 닫기
    await streamedResponse.stream.drain();
    print('✅ Multipart upload 성공333');
  }

  static Future<void> sendTcpDownFile(
    Uint8List fileBytes,
    TCPService tcp,
    String fileName,
  ) async {
    print('senddownfilesendtcp');
    tcp.sendJson({
      "type": "download-result",
      "base64": fileBytes,
      "fileName": fileName,
    });
  }
}
