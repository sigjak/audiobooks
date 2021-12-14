import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './common.dart';
import '../models/book.dart';

class PageTwo extends StatefulWidget {
  const PageTwo({required this.sections, required this.selectedBook, Key? key})
      : super(key: key);

  final List<String> sections;
  final Book selectedBook;
  @override
  _PageTwoState createState() => _PageTwoState();
}

class _PageTwoState extends State<PageTwo> with WidgetsBindingObserver {
  late ConcatenatingAudioSource _playlist;
  List<AudioSource> source = [];
  late AudioPlayer _player;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    prepPlaylist();
    _init();
    _player = AudioPlayer();
  }

  prepPlaylist() {
    for (int i = 0; i < widget.sections.length; i++) {
      var bookSection = AudioSource.uri(Uri.parse(widget.sections[i]),
          // tag: AudioMetadata(
          //     album: '${widget.selectedBook.bookTitle} - ${i + 1}',
          //     title: widget.selectedBook.bookAuthor!,
          //     artwork: widget.selectedBook.bookImage!)
          tag: MediaItem(
            id: i.toString(),
            album: '${widget.selectedBook.bookTitle} - ${i + 1}',
            title: widget.selectedBook.bookAuthor!,
            extras: {'artwork': widget.selectedBook.bookImage!},
          ));

      source.add(bookSection);
    }
    _playlist = ConcatenatingAudioSource(children: source);
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // Listen to errors during playback.

    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('A stream error occurred: $e')));
      // print('A stream error occurred: $e');
    });

    try {
      // Preloading audio is not currently supported on Linux.
      await _player.setAudioSource(_playlist);
      String temp = await _player.sequenceState!.currentSource!.tag.album;
      String currentSelection = temp.split(' -').first;
      print(currentSelection);
      // await getSavedPosition();
    } catch (e) {
      // Catch load errors: 404, invalid url...
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading audio source: $e")));
      // print("Error loading audio source: $e");
    }
  }

  Future<void> savePosition() async {
    int sectionIndex = _player.sequenceState!.currentIndex;
    String temp = _player.sequenceState?.currentSource!.tag.album;
    String current = temp.split(' -').first;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    int pos = _player.position.inMilliseconds;
    if (pos > 125000) {
      await prefs.setStringList(
          'playerPosition', [current, pos.toString(), sectionIndex.toString()]);
    }
  }

  Future getSavedPosition() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> saved =
        prefs.getStringList('playerPosition') ?? ['', '0', '0'];
    String temp = _player.sequenceState?.currentSource!.tag.album;
    String currentSelection = temp.split(' -').first;

    String savedSection = saved[0];
    Duration pos = Duration(milliseconds: int.parse(saved[1]));
    // print(pos);
    int sect = int.parse(saved[2]);
    if (currentSelection == savedSection) {
      _player.seek(pos, index: sect);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    savePosition();
    _player.dispose();
    super.dispose();
  }

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audiobooks'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
            image: DecorationImage(
          image: AssetImage("assets/images/gos2.jpg"),
          fit: BoxFit.cover,
        )),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StreamBuilder<SequenceState?>(
                stream: _player.sequenceStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  if (state?.sequence.isEmpty ?? true) return const SizedBox();
                  final metadata = state!.currentSource!.tag as MediaItem;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image(
                          image: MemoryImage(metadata.extras!['artwork']),
                          fit: BoxFit.cover,
                          width: 280,
                        ),
                      ),
                      Text(metadata.album!),
                      Text(metadata.title),
                    ],
                  );
                }),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                    onPressed: () {
                      Duration newPos =
                          _player.position - const Duration(seconds: 30);
                      if (newPos.inMilliseconds < 0) {
                        newPos = Duration.zero;
                      }
                      _player.seek(newPos);
                      _player.play();
                    },
                    icon: const Icon(Icons.replay_30)),
                IconButton(
                    onPressed: () {
                      Duration newPos =
                          _player.position + const Duration(seconds: 30);
                      if (newPos.inMilliseconds >
                          _player.duration!.inMilliseconds) {
                        newPos = _player.duration! - const Duration(seconds: 5);
                      }
                      _player.seek(newPos);
                      _player.play();
                    },
                    icon: const Icon(Icons.forward_30))
              ],
            ),
            StreamBuilder<PositionData>(
              stream: _positionDataStream,
              builder: (context, snapshot) {
                final positionData = snapshot.data;
                return SeekBar(
                  duration: positionData?.duration ?? Duration.zero,
                  position: positionData?.position ?? Duration.zero,
                  bufferedPosition:
                      positionData?.bufferedPosition ?? Duration.zero,
                  onChangeEnd: (newPosition) {
                    _player.seek(newPosition);
                  },
                );
              },
            ),
            ControlButtons(_player),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        child: const Icon(Icons.exit_to_app),
        onPressed: () {
          savePosition();
          dispose();
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        },
      ),
    );
  }
}

class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),
        StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, snapshot) => IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: player.hasPrevious ? player.seekToPrevious : null,
          ),
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: const Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero,
                    index: player.effectiveIndices!.first),
              );
            }
          },
        ),
        StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, snapshot) => IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: player.hasNext ? player.seekToNext : null,
          ),
        ),
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                value: player.speed,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}

// class AudioMetadata {
//   final String album;
//   final String title;
//   final Uint8List artwork;

//   AudioMetadata({
//     required this.album,
//     required this.title,
//     required this.artwork,
//   });
// }
