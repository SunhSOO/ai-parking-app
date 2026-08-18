import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 로컬 알림.
///
/// 지오펜스 진입은 **백그라운드 isolate**에서 콜백이 오므로, 앱 UI가 떠 있지 않아도
/// 알림을 띄울 수 있어야 한다. 그래서 이 클래스는 어느 isolate에서든
/// [ensureInitialized]만 부르면 쓸 수 있게 만들었다.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'certification',
    '주차 인증',
    description: '장애인주차면 도착과 자동 인증 진행 상황을 알려 줍니다.',
    importance: Importance.high,
  );

  Future<void> ensureInitialized() async {
    if (_ready) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    _ready = true;
  }

  /// 알림 권한 요청. 온보딩에서 위치 권한과 함께 한 번만 물어본다.
  Future<bool> requestPermission() async {
    await ensureInitialized();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true, badge: true) ??
          false;
    }
    return false;
  }

  /// 주차면 진입 알림 — "누르지 않아도 끝나요"를 알림에서도 그대로 전한다.
  Future<void> showArrival(String spotName) => _show(
        id: 1001,
        title: '장애인주차면에 도착했어요',
        body: '$spotName · 자동 인증을 시작했어요. 누르지 않아도 끝나요.',
      );

  Future<void> showVerified(String spotName) => _show(
        id: 1002,
        title: '인증됐어요 🎉',
        body: '$spotName · 단속 대상에서 제외됐어요.',
      );

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await ensureInitialized();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
