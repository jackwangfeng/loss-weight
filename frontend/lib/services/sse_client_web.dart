import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart' as http;

/// Web 平台：用 fetch_client 包装的 fetch API。
/// 标准 Dio / BrowserClient 在 Web 上会 buffer 整个响应，拿不到增量；
/// fetch + ReadableStream 才能真正流式。
http.Client createStreamingClient() => FetchClient(mode: RequestMode.cors);
