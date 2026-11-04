import 'package:ddokttak/audio/preview_player.dart';
import 'package:ddokttak/state/mock_metronome_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MockMetronomeController make() => MockMetronomeController(PreviewPlayer());

  test('곡을 고쳐도 자동 저장하지 않고, 업데이트하면 저장', () {
    final c = make()..loadSong('s1');
    expect(c.isModified, isFalse);
    c.setBpm(100);
    expect(c.isModified, isTrue);
    expect(c.changeSummary, '템포 82 → 100 바뀜');
    expect(c.songById('s1')!.settings.bpm, 82);
    c.updateCurrentSong();
    expect(c.songById('s1')!.settings.bpm, 100);
    expect(c.isModified, isFalse);
  });

  test('새로 저장하면 원래 곡은 그대로, 새 곡이 폴더에 담기고 지금 곡이 된다', () {
    final c = make()..loadSong('s1');
    c.setBpm(80);
    expect(c.suggestedNewName, '밤편지 (80)');
    final id = c.saveAsNewSong('밤편지 (80)');
    expect(c.songById('s1')!.settings.bpm, 82);
    expect(c.songById(id)!.settings.bpm, 80);
    expect(c.folder!.songIds.last, id);
    expect(c.currentSongId, id);
    expect(c.isModified, isFalse);
  });

  test('저장 안 하고 다른 곡을 부르면 원래 곡은 그대로', () {
    final c = make()..loadSong('s1');
    c.setBpm(70);
    c.loadSong('s3');
    expect(c.songById('s1')!.settings.bpm, 82);
    expect(c.settings.bpm, 96);
  });

  test('같은 곡을 여러 폴더에 담으면 한 곳에서 고친 게 모두에 반영', () {
    final c = make();
    expect(c.folders[0].songIds, contains('s1'));
    expect(c.folders[1].songIds, contains('s1'));
    c.loadSong('s1');
    c.setBpm(90);
    c.updateCurrentSong();
    c.selectFolder(1);
    expect(c.playlist.firstWhere((s) => s.id == 's1').settings.bpm, 90);
  });

  test('담기는 중복을 건너뛰고, 빼기는 보관함에 남긴다', () {
    final c = make();
    c.addToFolder(['s1', 's2', 's2']);
    expect(c.folder!.songIds, ['s1', 's3', 's4', 's2']);
    c.removeFromFolder('s2');
    expect(c.folder!.songIds, isNot(contains('s2')));
    expect(c.songById('s2'), isNotNull);
  });

  test('보관함에서 지우면 모든 폴더에서 빠진다', () {
    final c = make()..deleteSongFromLibrary('s1');
    for (final f in c.folders) {
      expect(f.songIds, isNot(contains('s1')));
    }
  });

  test('순서 바꾸기와 다음 곡', () {
    final c = make()..reorderInFolder(0, 2);
    expect(c.folder!.songIds, ['s3', 's4', 's1']);
    c.loadSong('s3');
    c.nextSong();
    expect(c.currentSongId, 's4');
  });
}
