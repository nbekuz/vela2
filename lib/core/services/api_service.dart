import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import '../constants/navigator_key.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://31.97.98.47:9000/api/',
      ),
      connectTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(minutes: 10),
    ),
  );

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static String? _memoryToken; // Store token from memory

  // Get memory token for debugging
  static String? get memoryToken => _memoryToken;

  // Set token from memory (called by AuthStore)
  static void setMemoryToken(String? token) {
    _memoryToken = token;
  }

  static void init() {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            var token = await _storage.read(key: 'access_token');

            // If token not in storage, try to get from memory
            if (token == null &&
                _memoryToken != null &&
                !(options.extra['open'] == true)) {
              // Save token to storage for future use
              try {
                await _storage.write(key: 'access_token', value: _memoryToken);
                token = _memoryToken;
              } catch (e) {
                // If token already exists, delete it first then write
                if (e.toString().contains('already exists')) {
                  try {
                    await _storage.delete(key: 'access_token');
                    await _storage.write(
                      key: 'access_token',
                      value: _memoryToken,
                    );
                    token = _memoryToken;
                  } catch (deleteError) {
                    token = _memoryToken;
                  }
                } else {
                  token = _memoryToken;
                }
              }
            }

            if (token != null && !(options.extra['open'] == true)) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            // Continue without token if there's an error
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            try {
              await _storage.delete(key: 'access_token');
            } catch (deleteError) {
              // Error deleting token
            }
            // Optionally, you can use a callback or event to trigger navigation to login
            if (navigatorKey.currentState != null) {
              navigatorKey.currentState!.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            }
          }

          return handler.next(e);
        },
      ),
    );
  }

  static Future<Response<T>> request<T>({
    required String url,
    bool open = false,
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    
    final options = Options(
      method: method,
      headers: headers,
      extra: {'open': open},
    );
    
    try {
      final response = await _dio.request<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      
      
      return response;
    } catch (e) {
      print('❌ API Error: $e');
      rethrow;
    }
  }

  // Method for file uploads
  static Future<Response<T>> uploadFile<T>({
    required String url,
    bool open = false,
    String method = 'POST',
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    final token = await _storage.read(key: 'access_token');

    final options = Options(
      method: method,
      headers: {
        ...headers ?? {},
        'Content-Type': 'multipart/form-data',
        if (token != null && !open) 'Authorization': 'Bearer $token',
      },
    );

    // Convert data to FormData if it contains file paths
    dynamic formData;
    if (data != null) {
      formData = FormData();

      for (var entry in data.entries) {
        if (entry.value is Uint8List) {
          // This is image bytes, add as file
          formData.files.add(
            MapEntry(
              'avatar', // Use 'avatar' as the field name for the API
              MultipartFile.fromBytes(entry.value, filename: 'avatar.jpg'),
            ),
          );
        } else if (entry.value is String &&
            entry.value.toString().startsWith('/')) {
          // This is a file path, add as file
          final file = File(entry.value);
          if (await file.exists()) {
            formData.files.add(
              MapEntry(
                entry.key,
                await MultipartFile.fromFile(
                  file.path,
                  filename: file.path.split('/').last,
                ),
              ),
            );
          }
        } else if (entry.value is String &&
            entry.value.toString().startsWith('blob:')) {
          // This is a blob URL, we need to convert it to bytes
          try {
            // For web, we need to fetch the blob data
            // This is a simplified approach - in a real app you might want to use a different method
            final response = await _dio.get(
              entry.value.toString(),
              options: Options(responseType: ResponseType.bytes),
            );

            if (response.data is Uint8List) {
              formData.files.add(
                MapEntry(
                  entry.key,
                  MultipartFile.fromBytes(
                    response.data,
                    filename: 'avatar.jpg',
                  ),
                ),
              );
            }
          } catch (e) {
            // If blob conversion fails, send as field
            formData.fields.add(MapEntry(entry.key, entry.value.toString()));
          }
        } else {
          // This is regular data
          formData.fields.add(MapEntry(entry.key, entry.value.toString()));
        }
      }
    }

    return _dio.request<T>(
      url,
      data: formData,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
