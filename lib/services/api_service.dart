import 'package:dio/dio.dart';

/// Legacy API service — kept for any direct REST calls not covered by Supabase.
/// For most operations, use supabase_flutter directly via the service classes.
class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://dvzqgsukcmdhwwxsynwg.supabase.co/functions/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  Dio get dio => _dio;
}
