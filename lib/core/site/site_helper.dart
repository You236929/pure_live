import 'dart:convert';

import 'package:pure_live/model/live_play_quality.dart';

dynamic decodeJson(dynamic value) {
  if (value is String) return jsonDecode(value);
  return value;
}

String validImageUrl(dynamic value) {
  final url = value?.toString() ?? '';
  if (url.isEmpty) return '';
  if (url.startsWith('//')) return 'https:$url';
  return url;
}

String appendTimestamp(String url) {
  if (url.isEmpty) return url;
  final sep = url.contains('?') ? '&' : '?';
  return '$url${sep}t=${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
}

int resolutionToBitRate(int resolution) {
  if (resolution >= 2160) return 20000;
  if (resolution >= 1440) return 10000;
  if (resolution >= 1080) return 8000;
  if (resolution >= 720) return 4000;
  if (resolution >= 480) return 1000;
  if (resolution >= 360) return 500;
  return 250;
}

String resolutionToQualityName(int resolution) {
  if (resolution >= 2160) return '4K';
  if (resolution >= 1440) return '2K';
  if (resolution >= 1080) return '1080P';
  if (resolution >= 720) return '720P';
  if (resolution >= 480) return '480P';
  if (resolution >= 360) return '360P';
  return '流畅';
}

Uri _resolveUri(String baseUrl, String url) {
  final uri = Uri.parse(url.trim());
  if (uri.hasScheme) return uri;
  return Uri.parse(baseUrl).resolve(url.trim());
}

List<LivePlayQuality> parseM3u8Qualities(String content, String baseUrl, {RegExp? otherInfoPattern}) {
  final lines = const LineSplitter().convert(content);
  final qualities = <LivePlayQuality>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('#EXT-X-STREAM-INF')) continue;

    String? urlLine;
    for (var j = i + 1; j < lines.length; j++) {
      final next = lines[j].trim();
      if (next.isEmpty) continue;
      if (!next.startsWith('#')) {
        urlLine = next;
        break;
      }
    }
    if (urlLine == null) continue;

    final resolutionMatch = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line);
    final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
    final infoMatch = otherInfoPattern?.firstMatch(line);
    final resolution = int.tryParse(resolutionMatch?.group(1) ?? '') ?? 0;
    final bandwidth = int.tryParse(bandwidthMatch?.group(1) ?? '') ?? 0;
    final bitRate = resolution > 0 ? resolutionToBitRate(resolution) : (bandwidth / 1000).round();
    final qualityName = resolution > 0 ? resolutionToQualityName(resolution) : (bitRate > 0 ? '${bitRate}K' : '自动');
    final info = infoMatch?.group(1);
    final playUrl = _resolveUri(baseUrl, urlLine).toString();

    final existing = qualities.firstWhere(
      (item) => item.sort == bitRate,
      orElse: () {
        final item = LivePlayQuality(quality: qualityName, sort: bitRate, data: <String>[]);
        qualities.add(item);
        return item;
      },
    );
    (existing.data as List<String>).add(info == null || info.isEmpty ? playUrl : '$playUrl#$info');
  }

  if (qualities.isEmpty && content.contains('#EXTM3U')) {
    qualities.add(LivePlayQuality(quality: '原画', sort: 99999, data: [baseUrl]));
  }

  qualities.sort((a, b) => b.sort.compareTo(a.sort));
  return qualities;
}

List<String> qualityUrls(LivePlayQuality quality) {
  final data = quality.data;
  if (data is List) {
    return data.map((e) => e.toString().split('#').first).where((e) => e.isNotEmpty).toList();
  }
  final value = data?.toString() ?? '';
  return value.isEmpty ? <String>[] : <String>[value];
}
