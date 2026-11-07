from pathlib import Path
for path in ['temp_try_dcm_decrypt.dart', 'lib/backend/utils/encoder_utils.dart']:
    text = Path(path).read_text(encoding='utf-8')
    if 'temp_try_dcm_decrypt.dart' in path:
        start = text.index("final String hexCiphertext")
        first_quote = text.index("'''", start)
        second_quote = text.index("'''", first_quote + 3)
        hexcontent = text[first_quote + 3:second_quote]
        print(path)
        print('  len', len(hexcontent), 'raw bytes', len(hexcontent)//2, 'even', len(hexcontent)%2==0)
        print('  first', hexcontent[:64])
        print('  last', hexcontent[-64:])
        print()
    else:
        marker = "'8E524060A10351BC"
        start = text.index(marker)
        end = text.index("'", start + 1)
        hexcontent = text[start + 1:end]
        print(path)
        print('  len', len(hexcontent), 'raw bytes', len(hexcontent)//2, 'even', len(hexcontent)%2==0)
        print('  first', hexcontent[:64])
        print('  last', hexcontent[-64:])
        print()
