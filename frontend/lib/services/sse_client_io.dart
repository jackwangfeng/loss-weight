import 'package:http/http.dart' as http;

/// Native (iOS / Android / desktop) 平台：标准 http Client 就能流式。
http.Client createStreamingClient() => http.Client();
