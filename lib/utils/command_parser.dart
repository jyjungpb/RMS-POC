import 'dart:convert';

import 'package:ivdm_client/utils/webview_actions.dart';

import '../controller/webview_controller.dart';
import '../service/tcp_service.dart';

class CommandParser {
  static final CommandParser _instance = CommandParser._internal();
  factory CommandParser() => _instance;
  CommandParser._internal();

  final _jsonBuffer = StringBuffer();

  Future<void> parse(
    String chunk,
    WebViewController controller,
    TCPService tcp,
  ) async {
    // 즉시 실행 가능한 명령
    if (chunk.startsWith("NAVIGATE:")) {
      final target = chunk.replaceFirst("NAVIGATE:", "");
      await controller.navigateToPage(target);
      controller.addLog("🌐 페이지 이동 감지: $target");
      return;
    }

    if (chunk.startsWith("SET:") || chunk.startsWith("CALL:")) {
      final parts = chunk.split(":");
      if (parts[0] == 'SET' && parts.length >= 3) {
        await WebViewActions.setElement(parts[1], parts[2], controller);
        return;
      } else if (parts[0] == 'CALL' && parts.length >= 2) {
        await WebViewActions.callFunction(parts[1], controller);
        return;
      }
    }

    // JSON 명령 누적
    _jsonBuffer.write(chunk);
    final bufferStr = _jsonBuffer.toString();

    if (bufferStr.contains("<EOF>")) {
      final completeJson = bufferStr.replaceAll("<EOF>", "").trim();

      try {
        final decoded = jsonDecode(completeJson);
        _jsonBuffer.clear();
        controller.addLog("📬 JSON 파싱 성공: ${decoded['type']}");

        if (controller.currentUrl.value.contains("/Xml")) {
          if (decoded['type'] == 'delete') {
            await WebViewActions.deleteXml(decoded, controller, tcp);
          } else if (decoded['type'] == 'upload') {
            await WebViewActions.uploadXml(decoded, controller, tcp);
          }
        } else if (controller.currentUrl.value.contains('/LogFiles')) {
          if (decoded['type'] == 'download') {
            await WebViewActions.downloadLogFile(decoded, controller, tcp);
          }
        }
      } catch (e) {
        controller.addLog("❌ JSON 파싱 실패: $e");
        _jsonBuffer.clear();
      }
    }
  }
}
