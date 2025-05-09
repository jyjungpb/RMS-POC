// import 'package:flutter/foundation.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:get/get.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// class WebViewControllerX extends GetxController {
//   InAppWebViewController? webViewController;
//   RxString url = "".obs;
//   RxDouble progress = 0.0.obs;
//   final urlController = RxString("");
//
//   InAppWebViewSettings settings = InAppWebViewSettings(
//     isInspectable: kDebugMode,
//     mediaPlaybackRequiresUserGesture: false,
//     allowsInlineMediaPlayback: true,
//     iframeAllow: "camera; microphone",
//     useHybridComposition: true,
//     iframeAllowFullscreen: true,
//     javaScriptCanOpenWindowsAutomatically: true,
//     javaScriptEnabled: true,
//     isFraudulentWebsiteWarningEnabled: true,
//     mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
//   );
//
//   late PullToRefreshController pullToRefreshController;
//
//   @override
//   void onInit() {
//     super.onInit();
//
//     pullToRefreshController = PullToRefreshController(
//       settings: PullToRefreshSettings(color: Get.theme.primaryColor),
//       onRefresh: () async {
//         webViewController?.reload();
//       },
//     );
//   }
//
//   void loadUrl(String newUrl) {
//     var uri = WebUri(newUrl);
//     if (uri.scheme.isEmpty) {
//       uri = WebUri("https://www.google.com/search?q=$newUrl");
//     }
//     webViewController?.loadUrl(urlRequest: URLRequest(url: uri));
//   }
//
//   void goBack() => webViewController?.goBack();
//   void goForward() => webViewController?.goForward();
//   void reload() => webViewController?.reload();
//
//   Future<NavigationActionPolicy> shouldOverrideUrlLoading(
//       InAppWebViewController controller,
//       NavigationAction navigationAction) async {
//     var uri = navigationAction.request.url!;
//     if (!["http", "https", "file", "chrome", "data", "javascript", "about"]
//         .contains(uri.scheme)) {
//       if (await canLaunchUrl(uri)) {
//         await launchUrl(uri);
//         return NavigationActionPolicy.CANCEL;
//       }
//     }
//     return NavigationActionPolicy.ALLOW;
//   }
//
//   void updateProgress(double value) {
//     progress.value = value / 100;
//   }
// }
