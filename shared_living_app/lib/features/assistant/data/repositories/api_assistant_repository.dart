import 'package:dio/dio.dart';
import 'package:shared_living_app/core/errors/app_failure.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../models/assistant_dtos.dart';
import 'mock_assistant_repository.dart';

class ApiAssistantRepository implements AssistantRepository {
  final Dio dio;
  final bool enableFallbackOnUnavailable;
  final MockAssistantRepository _fallbackRepo;

  ApiAssistantRepository({
    required this.dio,
    this.enableFallbackOnUnavailable = true,
  }) : _fallbackRepo = MockAssistantRepository();

  @override
  Future<AssistantChatResponse> sendMessage(
    AssistantChatRequest request, {
    String? idempotencyKey,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        headers['Idempotency-Key'] = idempotencyKey;
      }

      final response = await dio.post(
        '/api/assistant/chat',
        data: request.toJson(),
        options: Options(headers: headers),
      );

      final data = response.data as Map<String, dynamic>;
      return AssistantChatResponse.fromJson(data);
    } on DioException catch (e) {
      if (enableFallbackOnUnavailable &&
          (e.response?.statusCode == 404 ||
              e.response?.statusCode == 501 ||
              e.type == DioExceptionType.connectionError)) {
        return _fallbackRepo.sendMessage(request, idempotencyKey: idempotencyKey);
      }
      _handleDioError(e);
    } catch (e) {
      if (enableFallbackOnUnavailable) {
        return _fallbackRepo.sendMessage(request, idempotencyKey: idempotencyKey);
      }
      throw AppFailure(code: 'ASSISTANT_CHAT_FAILED', message: e.toString());
    }
  }

  @override
  Future<AssistantConfirmationResponse> confirmAction(
    AssistantConfirmationRequest request, {
    String? idempotencyKey,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        headers['Idempotency-Key'] = idempotencyKey;
      }

      final response = await dio.post(
        '/api/assistant/confirm',
        data: request.toJson(),
        options: Options(headers: headers),
      );

      final data = response.data as Map<String, dynamic>;
      return AssistantConfirmationResponse.fromJson(data);
    } on DioException catch (e) {
      if (enableFallbackOnUnavailable &&
          (e.response?.statusCode == 404 ||
              e.response?.statusCode == 501 ||
              e.type == DioExceptionType.connectionError)) {
        return _fallbackRepo.confirmAction(request, idempotencyKey: idempotencyKey);
      }
      _handleDioError(e);
    } catch (e) {
      if (enableFallbackOnUnavailable) {
        return _fallbackRepo.confirmAction(request, idempotencyKey: idempotencyKey);
      }
      throw AppFailure(code: 'ASSISTANT_CONFIRM_FAILED', message: e.toString());
    }
  }

  @override
  Future<void> clearConversation({String? conversationId}) async {
    try {
      if (conversationId != null && conversationId.isNotEmpty) {
        await dio.delete('/api/assistant/conversations/$conversationId');
      }
    } catch (_) {}
  }

  Never _handleDioError(DioException e) {
    if (e.response != null && e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw AppFailure.fromJson(data);
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const AppFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Connection to assistant timed out. Please retry.',
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      throw const AppFailure(
        code: 'NETWORK_UNREACHABLE',
        message: 'Unable to reach the Hisab AI assistant service.',
      );
    }

    throw AppFailure(
      code: 'HTTP_ERROR_${e.response?.statusCode ?? 500}',
      message: e.message ?? 'An unexpected assistant communication error occurred.',
    );
  }
}
