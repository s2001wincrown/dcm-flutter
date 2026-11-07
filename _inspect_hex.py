from pathlib import Path
p = Path('temp_try_dcm_decrypt.dart')
text = p.read_text(encoding='utf-8')
start = text.index("final String hexCiphertext")
first_quote = text.index("'''", start)
second_quote = text.index("'''", first_quote + 3)
hexcontent = text[first_quote + 3:second_quote]
print('len', len(hexcontent))
print('first100', hexcontent[:100])
print('last100', hexcontent[-100:])
print('endswith 24:', hexcontent.endswith('24'))
print('contains newline', '\n' in hexcontent)
print('raw bytes', len(hexcontent) // 2)
