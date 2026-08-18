import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 마이페이지의 iOS식 토글 스위치.
/// 트랙 46×27, 노브 21, on 색 `#2ED8A7`, 전환 200ms.
///
/// Material `Switch` 대신 직접 그리는 이유는 프로토타입의 트랙 색·크기를
/// 정확히 맞추기 위해서다.
class IosSwitch extends StatelessWidget {
  const IosSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  static const _trackWidth = 46.0;
  static const _trackHeight = 27.0;
  static const _knob = 21.0;
  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: _trackWidth,
            height: _trackHeight,
            decoration: BoxDecoration(
              color: value ? AppColors.mint : AppColors.inkA(.15),
              borderRadius: AppRadius.pill,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _inset),
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: AppShadows.knob,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
