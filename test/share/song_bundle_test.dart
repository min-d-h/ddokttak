import 'dart:convert';
import 'dart:io';

import 'package:ddokttak/domain/metronome_settings.dart';
import 'package:ddokttak/share/song_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bundle = SongBundle(
    folderName: '주일 예배',
    songs: [
      (name: '밤편지', settings: MetronomeSettings.defaults().withBpm(82)),
      (name: '왈츠 연습', settings: MetronomeSettings.defaults().withBpm(150)),
    ],
  );

  void expectSame(SongBundle? got) {
    expect(got, isNotNull);
    expect(got!.folderName, '주일 예배');
    expect(got.songs.map((s) => s.name), ['밤편지', '왈츠 연습']);
    expect(
      got.songs.map((s) => s.settings),
      bundle.songs.map((s) => s.settings),
    );
  }

  test('파일 내용으로 바꿨다 되읽으면 같다', () {
    expectSame(SongBundle.fromJsonText(bundle.toJsonText()));
  });

  test('QR 링크로 바꿨다 되읽으면 같고, 링크는 QR 한도 안이다', () {
    final link = bundle.toLink();
    expect(link, startsWith('ddokttak://import?d='));
    expect(link.length, lessThan(SongBundle.maxQrLinkLength));
    expectSame(SongBundle.fromLink(link));
  });

  test('똑딱 묶음이 아니거나 깨진 내용은 거절한다', () {
    for (final bad in [
      '',
      'hello',
      '[]',
      '{"app":"other","v":1,"songs":[{"name":"a","settings":{}}]}',
      '{"app":"ddokttak","v":99,"songs":[{"name":"a","settings":{}}]}',
      '{"app":"ddokttak","v":1,"songs":[]}',
      '{"app":"ddokttak","v":1,"songs":[{"name":"","settings":{}}]}',
      '{"app":"ddokttak","v":1,"songs":[{"name":3,"settings":{}}]}',
      '{"app":"ddokttak","v":1,"songs":["x"]}',
    ]) {
      expect(SongBundle.fromJsonText(bad), isNull, reason: bad);
    }
    for (final bad in [
      'https://example.com/import?d=abc',
      'ddokttak://other?d=abc',
      'ddokttak://import',
      'ddokttak://import?d=!!!',
      'ddokttak://import?d=${base64Url.encode(utf8.encode('not gzip'))}',
    ]) {
      expect(SongBundle.fromLink(bad), isNull, reason: bad);
    }
  });

  test('곡이 너무 많으면 거절, 이상한 설정 값은 안전한 범위로', () {
    final many = jsonEncode({
      'app': 'ddokttak',
      'v': 1,
      'songs': List.filled(SongBundle.maxSongs + 1, {
        'name': 'a',
        'settings': {},
      }),
    });
    expect(SongBundle.fromJsonText(many), isNull);

    final weird = SongBundle.fromJsonText(
      jsonEncode({
        'app': 'ddokttak',
        'v': 1,
        'songs': [
          {
            'name': '  탭\t이름\n${'가' * 200}  ',
            'settings': {'bpm': 99999, 'sound': 'nope'},
          },
        ],
      }),
    );
    expect(weird, isNotNull);
    final s = weird!.songs.single;
    expect(s.name.length, SongBundle.maxNameLength);
    expect(s.name, startsWith('탭이름'));
    expect(s.settings.bpm, lessThanOrEqualTo(400));
  });

  test('압축을 풀면 너무 커지는 링크는 거절한다', () {
    final huge = gzip.encode(List.filled(SongBundle.maxTextBytes + 10, 32));
    final d = base64Url.encode(huge).replaceAll('=', '');
    if (d.length <= SongBundle.maxQrLinkLength * 2) {
      expect(SongBundle.fromLink('ddokttak://import?d=$d'), isNull);
    }
  });

  test('파일 이름에서 쓸 수 없는 글자를 뺀다', () {
    expect(SongBundle.safeFileName('a/b:c?'), 'abc');
    expect(SongBundle.safeFileName(' / '), '똑딱 곡 묶음');
  });
}
