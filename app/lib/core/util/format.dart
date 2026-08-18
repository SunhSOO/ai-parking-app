/// 프로토타입의 한국어 표기를 그대로 만들어 내는 포맷 헬퍼.
/// 화면에서 날짜 문자열을 직접 조립하지 않는다.
library;

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// `수` — 요일 한 글자
String weekdayLabel(DateTime d) => _weekdays[d.weekday - 1];

/// `8월 12일` — 예약 카드, 날짜 칩
String monthDay(DateTime d) => '${d.month}월 ${d.day}일';

/// `8월 12일 (수) 10:30` — 내 예약 카드의 일시
String bookingWhen(DateTime d) =>
    '${monthDay(d)} (${weekdayLabel(d)}) ${hhmm(d)}';

/// `10:30`
String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// `2026. 8. 11. 09:41` — 인증 확인증의 시각
String receiptTime(DateTime d) =>
    '${d.year}. ${d.month}. ${d.day}. ${hhmm(d)}';

/// `8월 9일 14:22` — 이력 메타
String historyTime(DateTime d) => '${monthDay(d)} ${hhmm(d)}';

/// 오늘이면 `오늘 09:41`, 아니면 `8월 9일 14:22`
String relativeTime(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final isToday = d.year == n.year && d.month == n.month && d.day == n.day;
  return isToday ? '오늘 ${hhmm(d)}' : historyTime(d);
}

/// 마감일 표기.
/// - 날짜가 없으면 [fallback] (예: `상시 신청`)
/// - 9일 남았으면 `D-9 · 8/20 마감`
/// - 그보다 여유 있으면 `9/5 마감`
String dueLabel(DateTime? due, {String fallback = '상시 신청', DateTime? now}) {
  if (due == null) return fallback;
  final n = now ?? DateTime.now();
  final days = DateTime(due.year, due.month, due.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;

  final date = '${due.month}/${due.day} 마감';
  if (days < 0) return '마감됨';
  if (days == 0) return '오늘 마감';
  if (days <= 30) return 'D-$days · $date';
  return date;
}

/// 마감이 임박(30일 이내)했는지 — 빨간 글씨로 보일지 결정한다.
bool isUrgentDue(DateTime? due, {DateTime? now}) {
  if (due == null) return false;
  final n = now ?? DateTime.now();
  final days = DateTime(due.year, due.month, due.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;
  return days >= 0 && days <= 30;
}

/// `180m` / `1.2km` — 주차면·시설 거리
String distanceLabel(double? meters) {
  if (meters == null) return '';
  if (meters < 1000) return '${meters.round()}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}

/// 도보로 안내할 최대 거리.
///
/// 이 앱 사용자는 보행상 장애가 있는 경우가 많다. 1km가 넘는 거리를 "도보 18분"으로
/// 안내하는 것은 현실적이지 않아, 이 거리부터는 차량 시간으로 바꿔 보여 준다.
/// (프로토타입도 180m는 "도보 3분", 1.2km는 "차량 4분"으로 구분했다)
const _walkableMeters = 800.0;

/// 이동 시간 — 가까우면 도보, 멀면 차량.
/// 도보 분속 67m, 도심 차량 분속 300m(≈18km/h) 기준. 최소 1분.
String travelLabel(double? meters) {
  if (meters == null) return '';
  if (meters <= _walkableMeters) {
    return '도보 ${(meters / 67).ceil()}분';
  }
  return '차량 ${(meters / 300).ceil()}분';
}

/// `2시간 12분 남음` — 인증 남은 시간
String remaining(Duration d) {
  if (d.isNegative) return '종료됨';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '$h시간 $m분 남음';
  return '$m분 남음';
}

/// 이름에서 아바타 이니셜을 만든다. `선형수` → `SH` 는 프로토타입 값이라
/// 한글 이름은 뒤 두 글자를 쓴다.
String initialsOf(String? name) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return '·';
  if (n.length <= 2) return n;
  return n.substring(n.length - 2);
}
