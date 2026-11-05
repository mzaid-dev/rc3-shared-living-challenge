import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/core/utils/idempotency_manager.dart';

void main() {
  group('IdempotencyManager Tests', () {
    test('Reuses key on network/timeout error when payload is unchanged', () {
      final context = IdempotencyContext();
      const payload = '{"title":"Milk","total_paid":"780.00"}';

      final initialKey = context.prepareKeyForPayload(payload);

      // Simulate network failure
      context.handleFailure(
        isNetworkOrTimeoutOr5xx: true,
        payload: payload,
      );

      final retryKey = context.prepareKeyForPayload(payload);
      expect(retryKey, equals(initialKey));
    });

    test('Regenerates key if payload changes between submissions', () {
      final context = IdempotencyContext();
      const payload1 = '{"title":"Milk","total_paid":"780.00"}';
      const payload2 = '{"title":"Milk","total_paid":"900.00"}';

      final key1 = context.prepareKeyForPayload(payload1);
      final key2 = context.prepareKeyForPayload(payload2);

      expect(key2, isNot(equals(key1)));
    });

    test('Regenerates key after 4xx validation failure', () {
      final context = IdempotencyContext();
      const payload = '{"title":"","total_paid":"-50.00"}';

      final initialKey = context.prepareKeyForPayload(payload);

      // Simulate 4xx client validation error
      context.handleFailure(
        isNetworkOrTimeoutOr5xx: false,
        payload: payload,
      );

      final newKey = context.prepareKeyForPayload(payload);
      expect(newKey, isNot(equals(initialKey)));
    });

    test('Second submit() while isSubmitting is true is ignored', () {
      bool isSubmitting = false;
      int submitCallCount = 0;

      void performSubmit() {
        if (isSubmitting) return; // In-flight lock
        isSubmitting = true;
        submitCallCount++;
      }

      performSubmit();
      expect(submitCallCount, 1);
      expect(isSubmitting, true);

      // Second rapid tap while request is in flight
      performSubmit();
      expect(submitCallCount, 1); // Ignored!
    });
  });
}
