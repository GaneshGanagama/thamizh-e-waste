// lib/services/cloudinary_service.dart
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String _cloudName = 'dsyc9stin';
  static const String _uploadPreset = 'ecomeel_uploads';

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Uploads image bytes to Cloudinary and returns the public HTTPS URL.
  /// Returns null on failure — never throws.
  static Future<String?> uploadImage(
    Uint8List bytes, {
    String folder = 'ecomeel',
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = folder;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['secure_url'] as String?;
      } else {
        _log('Upload failed ${response.statusCode}: $body');
        return null;
      }
    } catch (e) {
      _log('Upload error: $e');
      return null;
    }
  }

  static void _log(String msg) {
    assert(() {
      // ignore: avoid_print
      print('[Cloudinary] $msg');
      return true;
    }());
  }
}
