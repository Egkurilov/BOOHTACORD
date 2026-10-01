import 'package:http/http.dart' as http;

class ProgressMultipartRequest extends http.MultipartRequest {
  ProgressMultipartRequest(super.method, super.url, this.onProgress);

  final void Function(int sent, int total)? onProgress;

  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      super.finalize().map((chunk) {
        sent += chunk.length;
        onProgress?.call(sent, total);
        return chunk;
      }),
    );
  }
}
