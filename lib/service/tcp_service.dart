import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import '../controller/webview_controller.dart';
import '../utils/command_parser.dart';

class TCPService {
  static final TCPService _instance = TCPService._internal();
  factory TCPService() => _instance;
  TCPService._internal();

  Socket? _socket;
  final _controller = Get.find<WebViewController>();
  final String host = "192.168.0.16";
  final int port = 9000;

  StringBuffer _jsonBuffer = StringBuffer();

  Future<void> connect() async {
    try {
      _socket = await Socket.connect(host, port);
      _controller.addLog("🔌 TCP 서버에 연결됨");

      _socket!.listen(_onData, onError: _onError, onDone: _onDone);
    } catch (e) {
      _controller.addLog("❌ TCP 연결 오류: $e");
    }
  }

  void send(String message) {
    _socket?.write(message);
  }

  void _onData(List<int> data) async {
    final chunk = utf8.decode(data);
    _controller.addLog("📩 수신 chunk: $chunk");

    // 명령 파싱 → 따로 분리
    await CommandParser().parse(chunk, _controller, this);
  }

  void _onError(error) {
    _controller.addLog("❌ TCP 에러: $error");
  }

  void _onDone() {
    _controller.addLog("🔌 TCP 연결 종료됨");
  }

  void sendJson(Map<String, dynamic> json) {
    if (_socket != null) {
      final message = "${jsonEncode(json)}<EOF>";
      _socket!.write(message);
    }
  }
}
