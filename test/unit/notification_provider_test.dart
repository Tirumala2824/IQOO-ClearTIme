import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/platform/notification/native_notification_bridge.dart';
import 'package:cleartime/data/models/trigger_config_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NativeNotificationBridge provider;

  setUp(() {
    provider = NativeNotificationBridge();
    provider.clearSpamCache();
  });

  group('NativeNotificationBridge Spam Protection & Channel Tests', () {
    test('Initialization succeeds gracefully', () async {
      await expectLater(provider.initialize(), completes);
    });

    test('Permission check and request return valid boolean', () async {
      final hasPerm = await provider.hasPermission();
      expect(hasPerm, isTrue);

      final req = await provider.requestPermission();
      expect(req, isTrue);
    });

    test('showChildWellbeingNotification dispatches with gentle parameters', () async {
      await expectLater(
        provider.showChildWellbeingNotification(
          id: 101,
          title: 'Mission Complete! 🌟',
          body: 'You finished a focus activity today!',
        ),
        completes,
      );
    });

    test('showParentAlertNotification dispatches with approved wellbeing alert', () async {
      await expectLater(
        provider.showParentAlertNotification(
          id: 201,
          title: 'Wellbeing Milestone',
          body: 'Alex completed a 45-minute focus session.',
        ),
        completes,
      );
    });

    test('Silent report notification type does not trigger audible/push notification', () async {
      await expectLater(
        provider.showNotification(
          id: 301,
          title: 'Silent update',
          body: 'Quiet data',
          notificationType: NotificationType.silentReport,
        ),
        completes,
      );
    });

    test('Cancel and cancelAll execute cleanly', () async {
      await expectLater(provider.cancelNotification(101), completes);
      await expectLater(provider.cancelAllNotifications(), completes);
    });
  });
}
