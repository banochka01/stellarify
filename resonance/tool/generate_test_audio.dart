import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const sampleRate = 44100;
  const durationSeconds = 8;
  const channels = 1;
  const bitsPerSample = 16;
  const sampleCount = sampleRate * durationSeconds;
  const bytesPerSample = bitsPerSample ~/ 8;
  const dataLength = sampleCount * channels * bytesPerSample;
  const fileLength = 44 + dataLength;

  final bytes = ByteData(fileLength);

  void writeAscii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  writeAscii(0, 'RIFF');
  bytes.setUint32(4, fileLength - 8, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  bytes.setUint16(32, channels * bytesPerSample, Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);

  for (var index = 0; index < sampleCount; index++) {
    final seconds = index / sampleRate;
    final pulse = sin(2 * pi * 220 * seconds) * 0.16;
    final overtone = sin(2 * pi * 330 * seconds) * 0.07;
    final envelope = min(1.0, min(seconds / 0.08, (8 - seconds) / 0.2));
    final sample = ((pulse + overtone) * envelope * 32767).round();
    bytes.setInt16(44 + index * bytesPerSample, sample, Endian.little);
  }

  final output = File('assets/audio/resonance_test.wav');
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
}
