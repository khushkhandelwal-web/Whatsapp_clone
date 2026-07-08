import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

const _kGeminiApiKey  = '';
const _kGeminiBaseUrl = 'https://generativelanguage.googleapis.com';
const _kGeminiModel   = 'gemini-2.5-flash';

class DioService {
  static final DioService _instance = DioService._internal();
  factory DioService() => _instance;

  late final Dio dio;

  DioService._internal() {
    dio = Dio(BaseOptions(
      baseUrl: _kGeminiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': _kGeminiApiKey,
      },
    ));
    dio.interceptors.add(PrettyDioLogger(
        requestBody: true, responseBody: true, error: true));
  }

  Future<String> askGemini(String prompt) async {
    final res = await dio.post(
      '/v1beta/models/$_kGeminiModel:generateContent',
      data: {
        'contents': [
          {'parts': [{'text': prompt}]}
        ]
      },
    );
    return res.data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}