# Build helpers for the release document, standard library only.
#   postprocess.py dpi <png>...        tag Playwright's 2x screenshots as 192 dpi, so Word shows them at their on-screen size
#   postprocess.py border <docx>       give every picture a thin grey border, so a white screen stands out from the page
#   postprocess.py count <docx>        print the number of pictures in the document
import struct, sys, zipfile, zlib, os, shutil, tempfile

def set_dpi(path, dpi=192):
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n': return False
    ppm = round(dpi / 0.0254)
    body = struct.pack('>IIB', ppm, ppm, 1)
    chunk = struct.pack('>I', len(body)) + b'pHYs' + body + struct.pack('>I', zlib.crc32(b'pHYs' + body) & 0xffffffff)
    out, i = [data[:8]], 8
    while i < len(data):
        n = struct.unpack('>I', data[i:i + 4])[0]; kind = data[i + 4:i + 8]; end = i + 12 + n
        if kind != b'pHYs': out.append(data[i:end])
        if kind == b'IHDR': out.append(chunk)
        i = end
    open(path, 'wb').write(b''.join(out)); return True

def border(path):
    tmp = path + '.tmp'
    with zipfile.ZipFile(path) as zin, zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/document.xml':
                xml = data.decode('utf-8')
                xml = xml.replace('<a:ln w="9525"><a:noFill />', '<a:ln w="9525"><a:solidFill><a:srgbClr val="C9D1DA" /></a:solidFill>')
                data = xml.encode('utf-8')
            zout.writestr(item, data)
    os.replace(tmp, path)

def count(path):
    with zipfile.ZipFile(path) as z: return z.read('word/document.xml').decode('utf-8').count('<pic:pic')

if __name__ == '__main__':
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == 'dpi': print(sum(1 for a in args if set_dpi(a)), 'images tagged')
    elif cmd == 'border': border(args[0]); print('bordered')
    elif cmd == 'count': print(count(args[0]))
