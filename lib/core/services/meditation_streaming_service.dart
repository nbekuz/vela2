import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../pages/meditation_streaming/helpers.dart';
import '../../core/stores/meditation_store.dart';

/// Service for handling meditation audio streaming
class MeditationStreamingService {
  http.Client? _client;
  StreamSubscription<List<int>>? _streamSub;
  File? _tempAudioFile;
  final List<Uint8List> _pcmChunks = [];

  // Callbacks
  Function(List<Uint8List>)? onChunkReceived; // Barcha chunks ro'yxati
  Function(Uint8List)? onNewChunkReceived; // Faqat yangi chunk
  Function(Uint8List)? onStreamComplete;
  Function(String)? onError;
  Function(bool)? onStreamingStateChanged;
  Function(int)? onProgressUpdate;

  /// Start streaming meditation audio
  Future<File?> startStreaming(
    BuildContext context, {
    Function(List<Uint8List>)? onChunk,
    Function(Uint8List)? onNewChunk,
    Function(Uint8List)? onComplete,
    Function(String)? onErrorCallback,
    Function(bool)? onStateChanged,
    Function(int)? onProgress,
  }) async {
    // Set callbacks
    onChunkReceived = onChunk;
    onNewChunkReceived = onNewChunk;
    onStreamComplete = onComplete;
    onError = onErrorCallback;
    onStreamingStateChanged = onStateChanged;
    onProgressUpdate = onProgress;

    try {
      _client = http.Client();
      _pcmChunks.clear();

      // Get ritualType from context to determine endpoint
      String? ritualType;
      if (context != null) {
        try {
          final meditationStore = Provider.of<MeditationStore>(
            context,
            listen: false,
          );
          ritualType =
              meditationStore.storedRitualType ??
              meditationStore.storedRitualId ??
              '1';
        } catch (e) {
          ritualType = '1';
        }
      } else {
        ritualType = '1';
      }

      final endpoint = getEndpoint(ritualType);
      final requestBody = buildRequestBody(context);

      final request = http.Request('POST', Uri.parse(endpoint));

      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(requestBody);

      final streamedResponse = await _client!.send(request);

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        String errorBody = '';
        try {
          final chunks = <List<int>>[];
          await for (final chunk in streamedResponse.stream) {
            chunks.add(chunk);
          }
          if (chunks.isNotEmpty) {
            final allBytes = chunks.expand((chunk) => chunk).toList();
            errorBody = utf8.decode(allBytes);
          }
        } catch (e) {
          print('❌ SERVER ERROR: ${streamedResponse.statusCode}');
        }
        throw Exception(
          "Server error: ${streamedResponse.statusCode} - $errorBody",
        );
      }

      onStreamingStateChanged?.call(true);

      // Create temporary file for streaming
      final tempDir = await getTemporaryDirectory();
      _tempAudioFile = File(
        '${tempDir.path}/meditation_stream_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      _streamSub = streamedResponse.stream.listen(
        (List<int> chunk) async {
          final data = Uint8List.fromList(chunk);
          _pcmChunks.add(data);

          final totalBytes = _pcmChunks.fold<int>(
            0,
            (sum, c) => sum + c.length,
          );

          // Calculate audio duration in seconds
          final bytesPerSecond = SAMPLE_RATE * CHANNELS * BYTES_PER_SAMPLE;
          final audioSeconds = totalBytes / bytesPerSecond;
          final requiredBytes = 2 * SAMPLE_RATE * CHANNELS * BYTES_PER_SAMPLE;

          onProgressUpdate?.call(totalBytes);
          onChunkReceived?.call(_pcmChunks);
          // Yangi chunk ni alohida yuborish
          onNewChunkReceived?.call(data);

          // 🔴 CRITICAL: DO NOT write to file during streaming!
          // This causes file locks that prevent just_audio seek() and stop() from working
          // File will be written ONLY in onDone callback when stream is complete
        },
        onDone: () async {
          try {
            final totalBytes = _pcmChunks.fold<int>(
              0,
              (sum, c) => sum + c.length,
            );

            // Calculate final audio duration
            final bytesPerSecond = SAMPLE_RATE * CHANNELS * BYTES_PER_SAMPLE;
            final finalAudioSeconds = totalBytes / bytesPerSecond;

            if (_pcmChunks.isNotEmpty) {
              try {
                // 🔴 CRITICAL: Create WAV file ONLY when stream is complete
                // This prevents file locks during streaming that block just_audio seek() and stop()
                final wav = createWavBytes(_pcmChunks, SAMPLE_RATE, CHANNELS);
                final wavSize = wav.length;

                // 🔴 CRITICAL: Write file ONLY once, when stream is done
                // This ensures file is not locked when just_audio tries to open it
                if (_tempAudioFile != null) {
                  await _tempAudioFile!.writeAsBytes(wav);
                  print('✅ [Stream] WAV file written: ${wavSize} bytes');
                }

                // 🔴 CRITICAL: Close HTTP stream BEFORE calling callbacks
                // This releases audio engine locks (iOS AVAudioSession, Android AudioTrack)
                await _streamSub?.cancel();
                _streamSub = null;

                _client?.close();
                _client = null;

                onStreamingStateChanged?.call(false);
                onStreamComplete?.call(wav);
              } catch (e, stackTrace) {
                // Ensure cleanup even on error
                await _streamSub?.cancel();
                _streamSub = null;
                _client?.close();
                _client = null;

                onStreamingStateChanged?.call(false);
                onError?.call("WAV creation error: $e");
              }
            } else {
              // Ensure cleanup even if empty
              await _streamSub?.cancel();
              _streamSub = null;
              _client?.close();
              _client = null;

              onStreamingStateChanged?.call(false);
              onError?.call("Empty stream from server");
            }
          } catch (e) {
            // Final safety cleanup
            await _streamSub?.cancel();
            _streamSub = null;
            _client?.close();
            _client = null;
            onStreamingStateChanged?.call(false);
            onError?.call("Stream completion error: $e");
          }
        },
        onError: (err, stackTrace) async {
          // 🔴 CRITICAL: Close HTTP stream on error
          // This releases audio engine locks immediately
          await _streamSub?.cancel();
          _streamSub = null;

          _client?.close();
          _client = null;

          onStreamingStateChanged?.call(false);
          onError?.call(err.toString());
        },
        cancelOnError: true,
      );
      return _tempAudioFile;
    } catch (e, stackTrace) {
      onStreamingStateChanged?.call(false);
      onError?.call(e.toString());
      return null;
    }
  }

  /// Stop streaming
  Future<void> stopStreaming() async {
    // 🔴 CRITICAL: Properly await cancellation to ensure stream is fully closed
    await _streamSub?.cancel();
    _streamSub = null;

    _client?.close();
    _client = null;
    // Callback'ni chaqirmaslik - widget dispose bo'lganda xatolik yuzaga kelmasligi uchun
    // onStreamingStateChanged?.call(false);
  }

  /// Get current PCM chunks
  List<Uint8List> get pcmChunks => List.unmodifiable(_pcmChunks);

  /// Get temporary audio file
  File? get tempAudioFile => _tempAudioFile;

  /// Calculate minimum bytes for initial playback
  int get bytesForInitialPlayback =>
      2 * SAMPLE_RATE * CHANNELS * BYTES_PER_SAMPLE;

  /// Dispose resources
  Future<void> dispose() async {
    await stopStreaming();
    // Clean up temp file
    if (_tempAudioFile != null) {
      _tempAudioFile!.delete().catchError((e) {
        return _tempAudioFile!;
      });
    }
    _tempAudioFile = null;
    _pcmChunks.clear();
  }
}
