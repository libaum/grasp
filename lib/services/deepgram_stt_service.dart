import 'dart:async';

import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
// Das Paket exportiert seinen eigenen Ergebnistyp nicht (Stand 4.2.0).
// ignore: implementation_imports
import 'package:deepgram_speech_to_text/src/listen/deepgram_listen_result.dart';
import 'package:record/record.dart';

import 'stt_service.dart';

/// Live-Transkription über Deepgram: PCM vom Mikrofon direkt in den Websocket.
///
/// Bewusst nicht Androids eigene Spracherkennung – die bricht nach wenigen
/// Sekunden Stille ab, und beim freien Erklären denkt man nun mal nach.
class DeepgramSttService implements SttService {
  DeepgramSttService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  static const String apiKey = String.fromEnvironment('DEEPGRAM_API_KEY');
  static bool get hasKey => apiKey.isNotEmpty;

  static const int _sampleRate = 16000;

  /// Wie lange nach dem Stopp noch auf nachlaufende Segmente gewartet wird.
  static const Duration _flushTimeout = Duration(milliseconds: 1500);

  final AudioRecorder _recorder;

  final _updates = StreamController<SttUpdate>.broadcast();
  final _levels = StreamController<double>.broadcast();

  DeepgramLiveListener? _listener;
  StreamSubscription<DeepgramListenResult>? _resultSub;
  StreamSubscription<Amplitude>? _amplitudeSub;

  final List<String> _settled = [];
  String _interim = '';
  bool _isRecording = false;
  Completer<void>? _flushed;

  @override
  Stream<SttUpdate> get updates => _updates.stream;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> start() async {
    if (_isRecording) return;
    if (!hasKey) {
      throw SttException('Kein Deepgram-Key konfiguriert. Starte die App mit '
          '--dart-define-from-file=dart_defines.json.');
    }
    if (!await _recorder.hasPermission()) {
      throw SttException('Ohne Mikrofon-Erlaubnis kann ich nicht zuhören.');
    }

    _settled.clear();
    _interim = '';
    _flushed = null;

    final Stream<List<int>> audio = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );

    final listener = Deepgram(apiKey).listen.liveListener(
      audio,
      queryParams: const {
        'model': 'nova-3',
        'language': 'de',
        'encoding': 'linear16',
        'sample_rate': _sampleRate,
        'channels': 1,
        'punctuate': true,
        'smart_format': true,
        'interim_results': true,
      },
    );
    _listener = listener;

    _resultSub = listener.stream.listen(_onResult, onError: (Object e) {
      _updates.addError(SttException('Verbindung zur Spracherkennung '
          'unterbrochen: $e'));
    });

    _amplitudeSub =
        _recorder.onAmplitudeChanged(const Duration(milliseconds: 120)).listen(
      (amp) {
        // dBFS (ca. -45..0) auf 0..1 abbilden.
        _levels.add(((amp.current + 45) / 45).clamp(0.0, 1.0));
      },
    );

    await listener.start();
    _isRecording = true;
  }

  void _onResult(DeepgramListenResult result) {
    if (!result.isResults) return;
    final text = result.transcript?.trim() ?? '';

    if (result.isFinal) {
      if (text.isNotEmpty) _settled.add(text);
      _interim = '';
      // Nach dem Finalize kommt das letzte Segment – dann darf geschlossen werden.
      if (result.fromFinalize && !(_flushed?.isCompleted ?? true)) {
        _flushed!.complete();
      }
    } else {
      _interim = text;
    }

    _updates.add(SttUpdate(settled: _settled.join(' '), interim: _interim));
  }

  @override
  Future<String> stop() async {
    if (!_isRecording) return _settled.join(' ');
    _isRecording = false;

    // Deepgram anstoßen, das gepufferte Audio noch auszuwerten, damit der
    // letzte Satz nicht verloren geht.
    final flushed = _flushed = Completer<void>();
    _listener?.finalize();
    await flushed.future.timeout(_flushTimeout, onTimeout: () {});

    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _recorder.stop();
    await _listener?.close();
    await _resultSub?.cancel();
    _resultSub = null;
    _listener = null;

    final transcript = [..._settled, _interim]
        .where((s) => s.trim().isNotEmpty)
        .join(' ')
        .trim();
    _interim = '';
    return transcript;
  }

  @override
  Future<void> dispose() async {
    if (_isRecording) await stop();
    await _updates.close();
    await _levels.close();
    await _recorder.dispose();
  }
}
