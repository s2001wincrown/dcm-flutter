import 'package:dcm/backend/services/rss_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses RSS items into title and content pages', () {
    const body = '''
<rss><channel>
  <item>
    <title>First title</title>
    <description><![CDATA[<p>First summary</p>]]></description>
    <link>https://example.com/1</link>
  </item>
</channel></rss>
''';

    final items = RssFeedService().parse(body);

    expect(items, hasLength(1));
    expect(items.single.title, 'First title');
    expect(items.single.content, 'First summary');
    expect(items.single.pageText, 'First title\n\nFirst summary');
    expect(items.single.link, 'https://example.com/1');
  });

  test('parses Atom summary and href links', () {
    const body = '''
<feed><entry>
  <title>Atom title</title>
  <summary>Atom summary</summary>
  <link href="https://example.com/atom" />
</entry></feed>
''';

    final item = RssFeedService().parse(body).single;

    expect(item.title, 'Atom title');
    expect(item.content, 'Atom summary');
    expect(item.link, 'https://example.com/atom');
  });
}
