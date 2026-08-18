import '../../../core/util/format.dart';

enum PermitType {
  self('self', '본인 운전', '본인 운전용'),
  guardian('guardian', '보호자 운전', '보호자 운전용');

  const PermitType(this.code, this.label, this.permitLabel);

  final String code;

  /// 온보딩 토글 버튼 라벨
  final String label;

  /// 마이페이지 "주차 표지" 값
  final String permitLabel;

  static PermitType fromCode(String? code) =>
      values.firstWhere((e) => e.code == code, orElse: () => PermitType.self);
}

/// 혜택 알림 토글 5종 — 마이페이지와 혜택 카테고리가 같은 코드를 쓴다.
const notifCategories = <String, String>{
  'mobility': '이동·교통',
  'care': '돌봄·활동지원',
  'health': '건강·재활',
  'culture': '문화·체육',
  'tax': '세금·요금 감면',
};

/// 복지카드로 확인된 자격 정보. 촬영본은 저장하지 않고 여기 결과만 남는다.
class Profile {
  const Profile({
    required this.id,
    this.name,
    this.disabilityType,
    this.disabilityGrade,
    this.walkingImpaired = false,
    this.sido,
    this.sigungu,
    this.birthYear,
    this.householdSize,
    this.incomeBracket,
    this.permitType = PermitType.self,
    this.interests = const [],
    this.notif = const {},
    this.cardVerifiedAt,
    this.onboardedAt,
  });

  final String id;
  final String? name;
  final String? disabilityType;
  final String? disabilityGrade;
  final bool walkingImpaired;
  final String? sido;
  final String? sigungu;
  final int? birthYear;
  final int? householdSize;
  final String? incomeBracket;
  final PermitType permitType;
  final List<String> interests;
  final Map<String, bool> notif;
  final DateTime? cardVerifiedAt;
  final DateTime? onboardedAt;

  bool get isVerified => cardVerifiedAt != null;
  bool get isOnboarded => onboardedAt != null;

  int? get age =>
      birthYear == null ? null : DateTime.now().year - birthYear! + 1;

  String get initials => initialsOf(name);

  /// `지체장애 2급` — 유형과 정도를 한 줄로
  String get disabilityLabel =>
      [disabilityType, disabilityGrade].whereType<String>().join(' ');

  /// `지체장애 2급 · 성남시 중원구` — 프로필 카드 부제
  String get profileSummary =>
      [disabilityLabel, sigungu].where((e) => e != null && e.isNotEmpty).join(' · ');

  /// `지체장애 2급 · 성남시 · 42세 · 2인가구` — 혜택 피드 헤더의 자격 요약
  String get eligibilitySummary {
    final city = sigungu?.split(' ').first;
    return [
      if (disabilityLabel.isNotEmpty) disabilityLabel,
      if (city != null && city.isNotEmpty) city,
      if (age != null) '$age세',
      if (householdSize != null) '$householdSize인가구',
    ].join(' · ');
  }

  Profile copyWith({
    String? name,
    String? disabilityType,
    String? disabilityGrade,
    bool? walkingImpaired,
    String? sido,
    String? sigungu,
    int? birthYear,
    int? householdSize,
    String? incomeBracket,
    PermitType? permitType,
    List<String>? interests,
    Map<String, bool>? notif,
    DateTime? cardVerifiedAt,
    DateTime? onboardedAt,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      disabilityType: disabilityType ?? this.disabilityType,
      disabilityGrade: disabilityGrade ?? this.disabilityGrade,
      walkingImpaired: walkingImpaired ?? this.walkingImpaired,
      sido: sido ?? this.sido,
      sigungu: sigungu ?? this.sigungu,
      birthYear: birthYear ?? this.birthYear,
      householdSize: householdSize ?? this.householdSize,
      incomeBracket: incomeBracket ?? this.incomeBracket,
      permitType: permitType ?? this.permitType,
      interests: interests ?? this.interests,
      notif: notif ?? this.notif,
      cardVerifiedAt: cardVerifiedAt ?? this.cardVerifiedAt,
      onboardedAt: onboardedAt ?? this.onboardedAt,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        name: m['name'] as String?,
        disabilityType: m['disability_type'] as String?,
        disabilityGrade: m['disability_grade'] as String?,
        walkingImpaired: m['walking_impaired'] as bool? ?? false,
        sido: m['sido'] as String?,
        sigungu: m['sigungu'] as String?,
        birthYear: m['birth_year'] as int?,
        householdSize: m['household_size'] as int?,
        incomeBracket: m['income_bracket'] as String?,
        permitType: PermitType.fromCode(m['permit_type'] as String?),
        interests: (m['interests'] as List?)?.cast<String>() ?? const [],
        notif: ((m['notif'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, v == true)),
        cardVerifiedAt: DateTime.tryParse(m['card_verified_at'] as String? ?? ''),
        onboardedAt: DateTime.tryParse(m['onboarded_at'] as String? ?? ''),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'disability_type': disabilityType,
        'disability_grade': disabilityGrade,
        'walking_impaired': walkingImpaired,
        'sido': sido,
        'sigungu': sigungu,
        'birth_year': birthYear,
        'household_size': householdSize,
        'income_bracket': incomeBracket,
        'permit_type': permitType.code,
        'interests': interests,
        'notif': notif,
        if (cardVerifiedAt != null)
          'card_verified_at': cardVerifiedAt!.toIso8601String(),
        if (onboardedAt != null) 'onboarded_at': onboardedAt!.toIso8601String(),
      };
}

/// 등록 차량 — 주차장 카메라가 읽은 번호와 대조할 대상.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    this.isPrimary = true,
  });

  final String id;
  final String plate;
  final bool isPrimary;

  factory Vehicle.fromMap(Map<String, dynamic> m) => Vehicle(
        id: m['id'] as String,
        plate: m['plate'] as String,
        isPrimary: m['is_primary'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {'plate': plate, 'is_primary': isPrimary};
}
