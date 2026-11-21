import hashlib
import json
from pathlib import Path
import urllib.request

folder = Path('Resources')
manifest = json.loads((folder / 'AppleArtworkSources.json').read_text(encoding='utf-8'))
for item in manifest['assets']:
    request = urllib.request.Request(item['url'], headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(request, timeout=120) as response:
        data = response.read()
    assert data.startswith(b'\x89PNG\r\n\x1a\n'), 'Expected original Apple PNG: ' + item['file']
    assert hashlib.sha256(data).hexdigest() == item['sha256'], 'Apple resource changed: ' + item['file']
    (folder / item['file']).write_bytes(data)
    print('Verified official image:', item['file'])
