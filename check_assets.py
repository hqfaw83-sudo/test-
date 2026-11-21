from pathlib import Path

app = Path('build/Build/Products/Release-iphoneos/AirPodsHealthProbe.app')
names = ['apple-airpods2', 'apple-airpods3', 'apple-airpods4', 'apple-airpods5', 'apple-airpods5-wireless', 'apple-pro1', 'apple-pro2', 'apple-pro3', 'apple-max']
for name in names:
    path = app / (name + '.png')
    assert path.exists(), f'Missing bundled image: {path}'
    assert path.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'), f'Not a PNG: {path}'
print('All nine original Apple PNG resources are bundled')
