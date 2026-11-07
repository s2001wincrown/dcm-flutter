from pathlib import Path
text = Path('lib/backend/utils/encoder_utils.dart').read_text(encoding='utf-8')
start = text.index("final hexCiphertext = hexCiphertext1 ??")
end = text.index("final passphrase = passphrase1 ?? cDCMFILECRYPTKEY;", start)
block = text[start:end]
quote_start = block.index("'") + 1
quote_end = block.rindex("'")
lit = block[quote_start:quote_end]
print('literal len', len(lit))
print('raw len', len(lit) // 2)
print('raw mod8', (len(lit) // 2) % 8)
print('first 64', lit[:64])
print('last 64', lit[-64:])
print('line count', block.count('\n'))
print('contains truncated?', 'truncated' in block)
