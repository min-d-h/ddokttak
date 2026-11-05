import 'package:flutter/material.dart';

import '../../app.dart';
import '../../state/mock_metronome_controller.dart';
import '../library_screen.dart';
import 'name_dialog.dart';

/// ④ 연주목록 = 지금 폴더의 곡들.
/// 목록 머리: [+ 담기] 곡 보관함 열기, [📁 폴더 이름 ▾] 폴더 바꾸기, [↺] 되돌리기.
/// 곡 줄: 누르면 불러오기, 길게 누르면 메뉴, 오른쪽 손잡이로 순서 바꾸기.
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.controller,
    this.expand = false,
    this.fill = false,
    this.small = false,
    this.rows,
  });

  final MockMetronomeController controller;

  /// 공연 모드에서는 남은 공간을 모두 쓰고 글자를 크게 한다.
  final bool expand;

  /// 남은 공간을 모두 쓴다.
  final bool fill;

  /// 가로 화면용: 머리·BPM 글자는 작게, 곡 제목만 조금 크게(13).
  final bool small;

  /// 정해 주면 이 줄 수만큼만 보이고 넘치면 스크롤한다 (세로 공연은 4줄).
  final int? rows;

  /// 공연(큰 글자) 한 줄 높이.
  static const double largeRowHeight = 44;

  /// 연습 모드에서 한 화면에 보이는 곡 수와 한 줄 높이. 넘치면 스크롤한다.
  static const int visibleRows = 6;
  static const double rowHeight = 34;

  /// 세로 화면의 연주목록 글자는 모두 18 (2026-11-04 사용자 결정).
  static const double portraitText = 18;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final songs = c.playlist;
    final Widget list = songs.isEmpty
        ? Center(
            child: Text(
              c.folder == null ? '📁 를 눌러 폴더를 만들어 보세요' : '+ 담기로 곡을 넣어 보세요',
              style: TextStyle(color: AppColors.subtext),
            ),
          )
        : ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemExtent: small ? 28 : (expand ? largeRowHeight : rowHeight),
            itemCount: songs.length,
            onReorderItem: c.reorderInFolder,
            itemBuilder: (context, i) {
              final song = songs[i];
              final selected = c.currentSongId == song.id;
              final s = song.settings;
              // 왼쪽으로 밀면 이 폴더에서 뺀다 (곡은 보관함에 남는다). 길게 누르면 메뉴.
              return Dismissible(
                key: ValueKey(song.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => c.removeFromFolder(song.id),
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '빼기',
                    style: TextStyle(fontSize: small ? 11 : 16),
                  ),
                ),
                child: Material(
                  color: selected ? AppColors.display : AppColors.card,
                  child: InkWell(
                    onTap: () => confirmLoad(context, c, song.id),
                    onLongPress: () => _songMenu(context, song.id, song.name),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i + 1}. ${song.name}${selected && c.isModified ? ' •' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: small ? 13 : portraitText,
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.text,
                              ),
                            ),
                          ),
                          Text(
                            '${s.bpm.round()} bpm ${s.timeSignature.id}',
                            style: TextStyle(
                              fontSize: small ? 8 : portraitText,
                              color: AppColors.subtext,
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(
                                Icons.drag_handle,
                                size: 18,
                                color: AppColors.subtext,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          SizedBox(
            height: small ? 30 : 42,
            child: Row(
              children: [
                IconButton(
                  iconSize: small ? 16 : 24,
                  visualDensity: small ? VisualDensity.compact : null,
                  tooltip: '불러오기 (곡 보관함에서 담기)',
                  onPressed: c.folder == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LibraryScreen(controller: c),
                          ),
                        ),
                  icon: const Icon(Icons.library_music_outlined),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _folderSheet(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_outlined, size: small ? 13 : 18),
                        SizedBox(width: small ? 3 : 6),
                        Flexible(
                          child: Text(
                            c.folder?.name ?? '폴더 없음',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: small ? 11 : portraitText,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, size: small ? 16 : 24),
                      ],
                    ),
                  ),
                ),
                // 저장은 아래 저장 버튼 하나로. 이 자리는 폴더 이름을 가운데에 두려고 같은 크기로 비운다.
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: IconButton(
                    iconSize: small ? 16 : 24,
                    visualDensity: small ? VisualDensity.compact : null,
                    onPressed: null,
                    icon: const Icon(Icons.library_music_outlined),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.outline),
          if (rows != null)
            SizedBox(
              height: (expand ? largeRowHeight : rowHeight) * rows!,
              child: list,
            )
          else if (expand || fill)
            Expanded(child: list)
          else
            SizedBox(height: rowHeight * visibleRows, child: list),
        ],
      ),
    );
  }

  void _songMenu(BuildContext context, String id, String name) =>
      showActionSheet(context, [
        (
          Icons.edit,
          '이름 바꾸기',
          false,
          () => askName(
            context,
            '곡 이름',
            name,
            (n) => controller.renameSong(id, n),
          ),
        ),
        (
          Icons.playlist_remove,
          '이 폴더에서 빼기 (보관함에는 남아요)',
          true,
          () => controller.removeFromFolder(id),
        ),
      ]);

  void _folderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      builder: (sheet) => SingleChildScrollView(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final c = controller;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('폴더', style: TextStyle(fontSize: 18)),
                  ),
                  for (var i = 0; i < c.folders.length; i++)
                    ListTile(
                      leading: Icon(
                        Icons.folder,
                        color: i == c.currentFolder ? AppColors.accent : null,
                      ),
                      title: Text(
                        c.folders[i].name,
                        style: TextStyle(
                          color: i == c.currentFolder ? AppColors.accent : null,
                        ),
                      ),
                      trailing: Text(
                        '${c.folders[i].songIds.length}곡',
                        style: TextStyle(color: AppColors.subtext),
                      ),
                      onTap: () {
                        c.selectFolder(i);
                        Navigator.pop(sheet);
                      },
                      onLongPress: () => showActionSheet(context, [
                        (
                          Icons.edit,
                          '폴더 이름 바꾸기',
                          false,
                          () => askName(
                            context,
                            '폴더 이름',
                            c.folders[i].name,
                            (n) => c.renameFolder(i, n),
                          ),
                        ),
                        (
                          Icons.delete_outline,
                          '폴더 삭제 (곡은 보관함에 남아요)',
                          true,
                          () => c.deleteFolder(i),
                        ),
                      ]),
                    ),
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: const Text('새 폴더'),
                    onTap: () =>
                        askName(context, '새 폴더 이름', '', c.createFolder),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 저장 입구 하나.
/// 불러온 곡을 고친 상태면 [덮어쓰기 / 새 곡으로] 를 묻고, 아니면 바로 간편 저장한다.
Future<void> saveCurrent(
  BuildContext context,
  MockMetronomeController c,
) async {
  if (c.folder == null) return;
  if (!c.isModified) {
    _quickSave(context, c);
    return;
  }
  final name = c.currentSong!.name;
  final choice = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('"$name" 이(가) 바뀌었어요'),
      content: Text(c.changeSummary),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, 'new'),
          child: const Text('새 곡으로'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, 'update'),
          child: const Text('덮어쓰기'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'update':
      c.updateCurrentSong();
      _snack(context, '"$name" 에 덮어썼어요');
    case 'new':
      _quickSave(context, c);
  }
}

/// 이름 창 없이 "120 · 4/4" 로 새 곡 저장 + 지금 폴더에 담기. 알림에서 이름을 바꿀 수 있다.
void _quickSave(BuildContext context, MockMetronomeController c) {
  final id = c.quickSave();
  final name = c.songById(id)!.name;
  _snack(
    context,
    '"$name" 저장했어요',
    action: SnackBarAction(
      label: '이름 바꾸기',
      onPressed: () =>
          askName(context, '곡 이름', name, (n) => c.renameSong(id, n)),
    ),
  );
}

void _snack(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 3),
        action: action,
      ),
    );
}

/// 저장 안 한 변경이 있으면 물어본 뒤 다른 곡을 불러온다.
Future<void> confirmLoad(
  BuildContext context,
  MockMetronomeController c,
  String id,
) async {
  if (!c.isModified || c.currentSongId == id) {
    if (c.currentSongId != id) c.loadSong(id);
    return;
  }
  final name = c.currentSong!.name;
  final choice = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('"$name" 이(가) 바뀌었어요'),
      content: Text(c.changeSummary),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, 'discard'),
          child: const Text('저장 안 함'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, 'new'),
          child: const Text('새 곡으로'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, 'update'),
          child: const Text('덮어쓰기'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'update':
      c.updateCurrentSong();
      c.loadSong(id);
    case 'new':
      _quickSave(context, c);
      c.loadSong(id);
    case 'discard':
      c.loadSong(id);
  }
}
