// import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:get/get.dart';
// import 'package:ivdm_client/webview_controller.dart';
//
// class WebViewPage extends StatelessWidget {
//   final WebViewControllerX webViewControllerX = Get.put(WebViewControllerX());
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("GetX InAppWebView")),
//       body: SafeArea(
//         child: Column(
//           children: <Widget>[
//             TextField(
//               decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
//               onSubmitted: (value) => webViewControllerX.loadUrl(value),
//             ),
//             Expanded(
//               child: Stack(
//                 children: [
//                   InAppWebView(
//                     initialUrlRequest: URLRequest(
//                       url: WebUri(
//                         "http://192.168.0.25:8070/Authenticate?userid=dev&passwd=elqpffhvj&language=kor",
//                       ),
//                     ),
//                     initialSettings: webViewControllerX.settings,
//                     pullToRefreshController:
//                         webViewControllerX.pullToRefreshController,
//                     onWebViewCreated: (controller) {
//                       webViewControllerX.webViewController = controller;
//                     },
//                     onLoadStart: (controller, url) {
//                       webViewControllerX.url.value = url.toString();
//                     },
//                     onPermissionRequest: (controller, request) async {
//                       return PermissionResponse(
//                         resources: request.resources,
//                         action: PermissionResponseAction.GRANT,
//                       );
//                     },
//                     shouldOverrideUrlLoading:
//                         webViewControllerX.shouldOverrideUrlLoading,
//                     onLoadStop: (controller, url) async {
//                       webViewControllerX.pullToRefreshController
//                           .endRefreshing();
//                       webViewControllerX.url.value = url.toString();
//                     },
//                     onReceivedError: (controller, request, error) {
//                       webViewControllerX.pullToRefreshController
//                           .endRefreshing();
//                     },
//                     onProgressChanged: (controller, progress) {
//                       webViewControllerX.updateProgress(progress.toDouble());
//                     },
//                   ),
//                   Obx(
//                     () =>
//                         webViewControllerX.progress.value < 1.0
//                             ? LinearProgressIndicator(
//                               value: webViewControllerX.progress.value,
//                             )
//                             : Container(),
//                   ),
//                 ],
//               ),
//             ),
//             ButtonBar(
//               alignment: MainAxisAlignment.center,
//               children: <Widget>[
//                 ElevatedButton(
//                   child: const Icon(Icons.arrow_back),
//                   onPressed: webViewControllerX.goBack,
//                 ),
//                 ElevatedButton(
//                   child: const Icon(Icons.arrow_forward),
//                   onPressed: webViewControllerX.goForward,
//                 ),
//                 ElevatedButton(
//                   child: const Icon(Icons.refresh),
//                   onPressed: webViewControllerX.reload,
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
