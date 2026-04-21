// 条件导入：Web 用 fetch_client，其他平台用标准 http Client。
export 'sse_client_io.dart' if (dart.library.js_interop) 'sse_client_web.dart';
