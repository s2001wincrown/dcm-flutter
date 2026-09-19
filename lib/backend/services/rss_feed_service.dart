import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

class RssFeedItem {
  const RssFeedItem({
    required this.title,
    required this.content,
    this.link,
    this.publishedAt,
  });

  final String title;
  final String content;
  final String? link;
  final DateTime? publishedAt;

  String get pageText =>
      content.trim().isEmpty ? title : '$title\n\n${content.trim()}';
}

class RssFeedService {
  RssFeedService({Dio? client}) : _client = client ?? Dio();

  final Dio _client;

  Future<List<RssFeedItem>> fetch(String url) async {
    final response = await _client.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data;
    if (body == null || body.trim().isEmpty) {
      return const [];
    }
    return parse(body);
  }

  List<RssFeedItem> parse(String body) {
    final document = XmlDocument.parse(body);
    final items = <RssFeedItem>[];
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'item' && element.name.local != 'entry') {
        continue;
      }
      final title = _childText(element, 'title');
      if (title.isEmpty) {
        continue;
      }
      final content = _childText(element, 'description').isNotEmpty
          ? _childText(element, 'description')
          : _childText(element, 'summary').isNotEmpty
              ? _childText(element, 'summary')
              : _childText(element, 'content');
      final linkElement = element.children
          .whereType<XmlElement>()
          .where((child) => child.name.local == 'link')
          .firstOrNull;
      final link = linkElement?.getAttribute('href') ?? linkElement?.innerText;
      final dateText = _childText(element, 'pubDate').isNotEmpty
          ? _childText(element, 'pubDate')
          : _childText(element, 'published').isNotEmpty
              ? _childText(element, 'published')
              : _childText(element, 'updated');
      items.add(
        RssFeedItem(
          title: _stripMarkup(title),
          content: _stripMarkup(content),
          link: link?.trim().isEmpty == true ? null : link?.trim(),
          publishedAt: DateTime.tryParse(dateText),
        ),
      );
    }
    return items;
  }

  String _childText(XmlElement element, String name) {
    return element.children
            .whereType<XmlElement>()
            .where((child) => child.name.local == name)
            .map((child) => child.innerText)
            .firstOrNull
            ?.trim() ??
        '';
  }

  String _stripMarkup(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
