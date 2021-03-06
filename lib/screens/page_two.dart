import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/section_model.dart';
import '../sql/sql_functions.dart';
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
  late String currentTitle;
  List<AudioSource> source = [];
  late AudioPlayer _player;
  List<Section> sectionList = [];
  List<int> sleepingTime = [10, 20, 30, 60];
  late int sleepTime;
  late Timer sleepTimer;
  bool isLoaded = false;
  bool isSleep = false;
  String dropdownValue = 'Sleep';
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
          tag: MediaItem(
            id: i.toString(),
            album: '${widget.selectedBook.bookTitle} - ${i + 1}',
            title: widget.selectedBook.bookAuthor!,
            extras: {
              'artwork': widget.selectedBook.bookImage!,
            },
          ));
      String sp = widget.sections[i].split('/').last;
      String sectionName = sp.substring(0, sp.length - 4);
      Section tempSection = Section(
          sectionName: sectionName,
          sectionSource: widget.sections[i],
          sectionIndex: i);
      sectionList.add(tempSection);
      source.add(bookSection);
    }
    _playlist = ConcatenatingAudioSource(children: source);
    setState(() {
      isLoaded = true;
    });
  }

  Future<void> savePosition() async {
    await context
        .read<SqlFunctions>()
        .updatePosition(currentTitle, _player.position, _player.currentIndex!);
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
      await _player.setAudioSource(_playlist);
      setState(() {
        currentTitle = widget.selectedBook.bookTitle!;
      });

      Book currentPosition =
          await context.read<SqlFunctions>().getSavedPosition(currentTitle);
      if (currentPosition.bookTitle == 'Nothing saved') {
        Book initPos = Book(
            bookTitle: currentTitle,
            lastPosition: _player.position,
            sectionIndex: _player.currentIndex);
        await context.read<SqlFunctions>().savePosition(initPos);
      } else {
        // seek to a saved position

        await _player.seek(currentPosition.lastPosition,
            index: currentPosition.sectionIndex);
      }
    } catch (e) {
      // Catch load errors: 404, invalid url...
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading audio source: $e")));
      //print("Error loading audio source: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);

    _player.dispose();
    super.dispose();
  }

  goToSleep(int value) async {
    setState(() {
      sleepTime = value;
      isSleep = true;
    });
    sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      setState(() {
        sleepTime = value;
      });
      value--;
      if (value <= 0) {
        await savePosition();
        timer.cancel();
        dispose();
        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        exit(0);
      }
    });
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
    return WillPopScope(
      onWillPop: () async {
        await savePosition();
        // await context.read<SqlFunctions>().updatePosition(
        //     currentTitle, _player.position, _player.currentIndex!);
        return Future.value(true);
      },
      child: Scaffold(
        body: StreamBuilder<SequenceState?>(
            stream: _player.sequenceStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              if (state?.sequence.isEmpty ?? true) {
                return const SizedBox();
              }
              final metadata = state!.currentSource!.tag as MediaItem;
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    actions: [
                      isSleep
                          ? Row(
                              children: [
                                Text(
                                  'Will sleep in ${sleepTime.toString()} minutes',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(
                                  width: 20,
                                ),
                                TextButton(
                                  onPressed: () {
                                    sleepTimer.cancel();
                                    setState(() {
                                      isSleep = false;
                                    });
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                        'Sleep canceled',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ));
                                    //wdata.snack('Sleep cancelled !', context);
                                  },
                                  child: const Text('Cancel Sleep',
                                      style: TextStyle(color: Colors.white)),
                                )
                              ],
                            )
                          : PopupMenuButton<int>(
                              offset: const Offset(60, 40),
                              child: const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('Sleep'),
                              ),
                              onSelected: (value) {
                                goToSleep(value);
                                // data.snack(
                                //     'Sleeping in $value minutes', context);
                              },
                              itemBuilder: (context) {
                                return sleepingTime.map((item) {
                                  return PopupMenuItem<int>(
                                    value: item,
                                    child: Text('${item.toString()} minutes.'),
                                  );
                                }).toList();
                              })
                    ],
                    backgroundColor: const Color(0x002e2e2e),
                    shadowColor: const Color(0x002e2e2e),
                    snap: true,
                    floating: true,
                    expandedHeight: 380,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Image(
                              image: MemoryImage(metadata.extras!['artwork']),
                              // fit: BoxFit.fitHeight,
                              height: 160,
                              // width: 280,
                            ),
                            //      Text(metadata.id),
                            Text(metadata.album!),
                            Text(metadata.title),
                            ControlButtons(_player),
                            StreamBuilder<PositionData>(
                              stream: _positionDataStream,
                              builder: (context, snapshot) {
                                final positionData = snapshot.data;
                                return SeekBar(
                                  duration:
                                      positionData?.duration ?? Duration.zero,
                                  position:
                                      positionData?.position ?? Duration.zero,
                                  bufferedPosition:
                                      positionData?.bufferedPosition ??
                                          Duration.zero,
                                  onChangeEnd: (newPosition) {
                                    _player.seek(newPosition);
                                  },
                                );
                              },
                            ),
                          ]),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(
                    height: 20,
                  )),
                  isLoaded
                      ? SliverList(
                          // itemExtent: 100,
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final section = sectionList[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: GestureDetector(
                                  onTap: () {
                                    _player.seek(Duration.zero,
                                        index: section.sectionIndex);
                                    _player.play();
                                  },
                                  child: Card(
                                    shape: int.parse(metadata.id) == index
                                        ? RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            side: const BorderSide(
                                                color: Colors.white))
                                        : null,
                                    child: ListTile(
                                      title: Text(section.sectionName),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: sectionList.length,
                          ),
                        )
                      : const SliverToBoxAdapter(
                          child: Center(
                          child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator()),
                        )),
                ],
              );
            }),
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
            onPressed: () {
              Duration newPos = player.position - const Duration(seconds: 30);
              if (newPos.inMilliseconds < 0) {
                newPos = Duration.zero;
              }
              player.seek(newPos);
              player.play();
            },
            icon: const Icon(Icons.replay_30)),
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
        IconButton(
            onPressed: () {
              Duration newPos = player.position + const Duration(seconds: 30);
              if (newPos.inMilliseconds > player.duration!.inMilliseconds) {
                newPos = player.duration! - const Duration(seconds: 5);
              }
              player.seek(newPos);
              player.play();
            },
            icon: const Icon(Icons.forward_30))
      ],
    );
  }
}
