import 'package:flutter/material.dart';

import '../../domain/click_sound.dart';
import 'wheel_select_box.dart';

const soundLabels = {
  ClickSoundId.wood: '우드블록',
  ClickSoundId.electronic: '전자 클릭',
  ClickSoundId.beep: '비프',
  ClickSoundId.mechanical: '기계식 틱',
  ClickSoundId.clave: '클라베스',
  ClickSoundId.cowbell: '카우벨',
  ClickSoundId.digital: '디지털',
};

/// 소리 선택 상자. 휠을 굴리는 동안 고른 소리를 한 번씩 들려준다.
class SoundPicker extends StatelessWidget {
  const SoundPicker({super.key, required this.value, required this.onSelected});

  final ClickSoundId value;
  final ValueChanged<ClickSoundId> onSelected;

  @override
  Widget build(BuildContext context) => WheelSelectBox<ClickSoundId>(
    items: ClickSoundId.values,
    value: value,
    labelOf: (s) => soundLabels[s]!,
    onChanged: onSelected,
  );
}
