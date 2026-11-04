import 'package:flutter/material.dart';

import '../app.dart';
import '../state/mock_metronome_controller.dart';
import 'widgets/name_dialog.dart';

/// 곡 보관함. 만든 곡이 모두 쌓여 있고, 쇼핑하듯 골라 지금 폴더에 담는다.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.controller});

  final MockMetronomeController controller;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _picked = <String>{};
  String _query = '';

  MockMetronomeController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final inFolder = c.folder?.songIds.toSet() ?? const <String>{};
        final songs = [
          for (final s in c.library)
            if (_query.isEmpty || s.name.toLowerCase().contains(_query)) s,
        ];
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: Text(
              '곡 보관함 → ${c.folder?.name ?? ''}',
              style: const TextStyle(fontSize: 17),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '곡 검색',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              Divider(height: 1, color: AppColors.outline),
              Expanded(
                child: ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) {
                    final song = songs[i];
                    final already = inFolder.contains(song.id);
                    final s = song.settings;
                    return CheckboxListTile(
                      value: already || _picked.contains(song.id),
                      onChanged: already
                          ? null
                          : (v) => setState(
                              () => v!
                                  ? _picked.add(song.id)
                                  : _picked.remove(song.id),
                            ),
                      activeColor: AppColors.accent,
                      checkColor: AppColors.onAccent,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(song.name),
                      subtitle: Text(
                        '${s.bpm.round()} bpm · ${s.timeSignature.id}${already ? '  · 이미 담김' : ''}',
                        style: TextStyle(color: AppColors.subtext),
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => showActionSheet(context, [
                          (
                            Icons.edit,
                            '이름 바꾸기',
                            false,
                            () => askName(
                              context,
                              '곡 이름',
                              song.name,
                              (n) => c.renameSong(song.id, n),
                            ),
                          ),
                          (
                            Icons.delete_outline,
                            '보관함에서 삭제 (모든 폴더에서 빠져요)',
                            true,
                            () {
                              _picked.remove(song.id);
                              c.deleteSongFromLibrary(song.id);
                            },
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                ),
                onPressed: _picked.isEmpty
                    ? null
                    : () {
                        c.addToFolder(_picked);
                        Navigator.pop(context);
                      },
                child: Text(
                  _picked.isEmpty ? '담을 곡을 골라 주세요' : '${_picked.length}곡 담기',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
