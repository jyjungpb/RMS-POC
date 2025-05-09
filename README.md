# RMS-POC Flutter App

## 프로젝트 개요

이 Flutter 앱은 WebView + TCP 통신 기반의 하이브리드 애플리케이션입니다.  
Node.js 서버와의 실시간 명령 송수신을 통해 XML 파일 삭제, 업로드, 데이터 추출 등을 WebView 내부에서 제어합니다.

---

## 디렉터리 구조

```
lib/
├── main.dart                  # 앱 시작점
├── inapp_screen.dart          # 메인 WebView 스크린
├── controller/
│   └── inapp_controller.dart  # WebView 상태 및 로직 제어
├── service/
│   └── tcp_service.dart       # TCP 소켓 통신 처리
├── utils/
│   ├── command_parser.dart    # 문자열 명령 파싱
│   └── webview_actions.dart   # JS 주입 유틸 함수
```

---

## 핵심 동작

- 앱 시작 → `main.dart` → `inapp_screen.dart`
- `WebViewControllerX`가 URL 이동 추적 및 상태관리 수행
- TCP 통신으로 외부 명령 수신 → `CommandParser`로 해석 → WebView에 반영
- WebView에서는 `common.js` 기반 함수 호출로 실제 동작 수행

---

## 주요 메소드 요약

| 위치 | 메소드 | 설명 |
|------|--------|------|
| `tcp_service.dart` | `connect()` | TCP 서버 연결 |
| `tcp_service.dart` | `listen()` | 데이터 수신 및 명령 처리 |
| `command_parser.dart` | `parseMessage()` | 명령어 해석 및 분기 |
| `webview_actions.dart` | `uploadFileToForm()` | JS로 파일 업로드 주입 |
| `inapp_controller.dart` | `handleNavigation()` | URL 기반 상태 판별 |

---

## 사용 기술

- Flutter WebView (`flutter_inappwebview`)
- GetX 상태관리
- TCP Socket (`dart:io`)
- JavaScript-injected command control

---

## 파일별 클래스 및 주요 메소드 설명

### `main.dart`
- **클래스**: 없음 (entry point)
- **기능**:
  - `runApp(...)`으로 앱 시작
  - `GetMaterialApp`을 통해 라우팅 설정 (`home: InAppScreen()`)

---

### `inapp_screen.dart`
- **클래스**: `InAppScreen extends StatelessWidget`
- **역할**:
  - 앱의 메인 WebView 화면
  - `Obx`를 통해 `WebViewControllerX` 상태를 실시간 감시
- **주요 로직**:
  - `InAppWebView`에 `controller.webViewController` 연결
  - URL 이동을 감지해 `handleNavigation` 호출

---

### `webview_screen.dart`
- **클래스**: `WebViewScreen extends StatelessWidget`
- **역할**:
  - 보조 웹뷰 화면으로 추정
  - 독립적 WebView 로딩을 위한 화면

---

### `controller/inapp_controller.dart`
- **클래스**: `WebViewControllerX extends GetxController`
- **역할**:
  - WebView 상태 관리 및 TCP 명령 대응
  - 로그인 여부, 대기 상태, 메인화면 여부 등을 `RxBool`로 추적
- **주요 메소드**:
  - `handleNavigation(NavigationAction)` : URL에 따라 상태 갱신
  - `evaluateJS(String js)` : JS 명령 실행
  - `sendLogToServer(String log)` : 로그 전송

---

### `service/tcp_service.dart`
- **클래스**: `TCPService` (싱글톤)
- **역할**:
  - TCP 서버에 연결 및 수신 메시지 처리
  - WebView 관련 명령 전달
- **주요 메소드**:
  - `connect()` : 서버에 연결
  - `listen()` : 데이터 수신 후 `CommandParser` 호출
  - `sendMessage(String msg)` : 서버로 메시지 전송

---

### `utils/command_parser.dart`
- **클래스**: 없음
- **역할**:
  - TCP 메시지를 명령 단위로 파싱하여 제어 흐름 분기
- **주요 메소드**:
  - `parseMessage(String msg)` : CALL/NAVIGATE/DELETE 등 분기

---

### `utils/webview_actions.dart`
- **클래스**: 없음
- **역할**:
  - WebView에서 실행할 자바스크립트 문자열 생성/전송
- **주요 메소드**:
  - `uploadFileToForm(filename, base64Data)` : 업로드 폼 채우기
  - `deleteXmlFile(filename)` : XML 삭제 명령 생성

---

## inapp_controller.dart 상세 분석

### 클래스: `WebViewControllerX extends GetxController`

> WebView 상태를 추적하고, TCP 명령을 받아 WebView에서 JS 실행 및 화면 제어를 수행합니다.

---

### 상태 변수

| 변수 | 설명 |
|------|------|
| `webViewController` | WebView 인스턴스를 제어하기 위한 컨트롤러 |
| `currentUrl` | 현재 웹뷰의 URL 상태 |
| `isLoggedIn` | 로그인 상태 |
| `isWaiting` | `/Waiting` or `/WaitingRefresh` 상태 여부 |
| `isMainLoaded` | `/Main`, `/Xml`, `/Config` 등 주요 페이지 진입 여부 |
| `socket` | TCP 연결 소켓 객체 |
| `logs` | TCP 및 WebView 이벤트 로그 리스트 |

---

### 🧩 주요 메소드 설명

#### `void onInit()`
- GetX 생명주기 메소드, 초기화 시점.
- 현재는 `connectToTCPServer()`는 주석 처리됨.

---

#### `void addLog(String log)`
- 로그를 리스트 최상단에 추가하여 UI 갱신 가능하게 함 (`RxList` 사용)

---

#### `Future<void> connectToTCPServer()`
- `Socket.connect()`로 TCP 서버 연결
- 수신 데이터 `chunk`를 구문별로 분기 처리:
  - `NAVIGATE:` → WebView에서 페이지 이동
  - `SET:id:value` → DOM에 값 주입
  - `CALL:fn` → 자바스크립트 함수 실행
  - `<EOF>` 포함 시 JSON 파싱 시도
    - `type: delete` → 삭제 명령 실행 후 `REFRESH:/Xml` 전송
    - `type: upload` → 파일 업로드 후 `REFRESH:/Xml` 전송

---

#### `Future<void> navigateToPage(String path)`
- WebView에 URL 로드 명령 전달

---

#### `void setWebViewController(...)`
- 외부에서 InAppWebViewController 객체 주입

---

#### `Future<NavigationActionPolicy> handleNavigation(...)`
- URL 이동 감지시 상태 업데이트 (`currentUrl`)
- Navigation 허용 (`ALLOW` 반환)

---

#### `Future<void> sendExtractedXmlSection()`
- WebView 내 특정 HTML 구간을 추출 (`frmContent` ~ `frmApplyDB`)
- 추출된 HTML을 `$httpUrl/api/panel-xml-section`로 POST 전송

---

#### `Future<void> handleLoadStop(...)`
- 웹페이지 로딩 완료 시점에 호출됨
- URL에 따라 분기 처리:
  - `/Waiting` → `WaitingRefresh` 탐색 후 자동 로딩
  - `/WaitingRefresh` → `/Main` 전환 시도
  - `/Main`, `/Config`, `/Xml`, `/log` → 상태값 업데이트 및 기능 삽입
- `/Xml`일 경우 → `injectUploadFunction()` 호출 → `sendExtractedXmlSection()` 전송

---

#### `Future<void> injectUploadFunction()`
- WebView 내부에 파일 업로드용 JS 함수 `uploadFileToForm(...)`를 삽입
- base64 인코딩된 파일을 `DataTransfer`를 이용해 `<input type="file">`에 삽입
- `frmUpload.submit()` 호출로 업로드 수행

---

#### `Future<void> updateCalibrationExpire(...)`
- 특정 Config 페이지에서
  - `CalibrationExpire` 값을 `301`로 세팅
  - `MobileAccessCode`를 `0001`로 세팅
  - `config_submit()` 실행으로 저장

---

이 메소드는 Config 설정 자동화를 위한 전용 기능

---

## service/tcp_service.dart 상세 분석

### 클래스: `TCPService`

> 외부 Node.js 서버와의 TCP 통신을 담당하는 싱글톤 서비스 클래스입니다.

---

### 주요 메소드 설명

#### `TCPService._internal()`
- 싱글톤 생성을 위한 private 생성자

#### `factory TCPService()`
- TCPService의 인스턴스를 반환 (싱글톤 보장)

#### `void connect(Function(String) onMessageReceived)`
- TCP 서버 (`192.168.0.16:9000`)에 연결
- 수신된 메시지를 `onMessageReceived` 콜백으로 전달
- 예외 발생 시 내부 로그 출력

#### `void sendMessage(String message)`
- 연결된 소켓을 통해 문자열 메시지를 전송

####  `void close()`
- TCP 소켓 연결 종료

#### `bool get isConnected`
- 소켓 연결 여부 반환 (`socket != null`)

---

## utils/webview_actions.dart 상세 분석

### 파일: WebView에서 실행할 JS 명령 생성 헬퍼

> 이 파일은 WebView에 삽입할 자바스크립트 명령어를 Dart에서 문자열로 생성해주는 유틸리티 역할을 합니다.

---

### 주요 메소드 설명

#### `String generateUploadScript(String filename, String base64)`
- 업로드용 JS 문자열 생성 (`uploadFileToForm(...)`)
- base64 → Blob → File → input[type="file"]에 할당 후 `frmUpload.submit()` 실행

#### `String generateDeleteScript(String filename)`
- XML 파일 삭제용 JS 명령 (`deletexmlfile(filename)` 호출) 생성

---

## utils/command_parser.dart 상세 분석

### 파일: TCP 명령 파서

> TCP를 통해 수신된 문자열 또는 JSON 메시지를 파싱하고 이에 대한 명령을 수행하도록 분기합니다.

---

### 주요 메소드 설명

#### `void parseMessage(String message, WebViewControllerX controller)`
- 메시지 접두사(`SET`, `CALL`, `NAVIGATE`, `DELETE`, `upload`, `delete`)에 따라 분기
- 분기 예시:
  - `SET:id:value` → JS: `document.getElementById(id).value = value`
  - `CALL:fn` → JS: `fn();`
  - `NAVIGATE:/Xml` → controller.navigateToPage("/Xml")
  - JSON인 경우:
    - `type: upload` → upload 실행
    - `type: delete` → delete 실행
