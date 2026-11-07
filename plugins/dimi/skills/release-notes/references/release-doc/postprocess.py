# Build helpers for the release document, standard library only.
#   postprocess.py dpi <png>...        tag Playwright's 2x screenshots as 240 dpi, so Word shows every one at 80% of its
#                                      on-screen size: panels and whole screens read at one consistent scale
#   postprocess.py border <docx>       give every picture a thin grey border, so a white screen stands out from the page;
#                                      keep the paragraph before each picture (its step) on the same page as it; and line
#                                      every picture and caption up with the text of the step it sits in
#   postprocess.py count <docx>        print the number of pictures in the document
import re, struct, sys, zipfile, zlib, os

def set_dpi(path, dpi=240):
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

def list_indents(numbering_xml):
    # numId -> {level: left indent in twips}, from the document's own list definitions
    abstract = {}
    for m in re.finditer(r'<w:abstractNum w:abstractNumId="(\d+)".*?</w:abstractNum>', numbering_xml, re.S):
        levels = {}
        for lv in re.finditer(r'<w:lvl w:ilvl="(\d+)".*?</w:lvl>', m.group(0), re.S):
            ind = re.search(r'<w:ind [^>]*w:left="(\d+)"', lv.group(0))
            if ind: levels[lv.group(1)] = ind.group(1)
        abstract[m.group(1)] = levels
    nums = {}
    for m in re.finditer(r'<w:num w:numId="(\d+)"><w:abstractNumId w:val="(\d+)"', numbering_xml):
        nums[m.group(1)] = abstract.get(m.group(2), {})
    return nums

def align_figures(xml, indents):
    # Pandoc gives a picture inside a list step the list's hanging indent, so each picture starts somewhere slightly
    # different. Replace its list membership with a plain left indent equal to the step's text, and do the same for
    # the caption under it; a picture outside a list keeps the body's left edge.
    def fix(m):
        p = m.group(0)
        style = re.search(r'<w:pStyle w:val="(CaptionedFigure|ImageCaption|Figure)" />', p)
        if not style: return p
        num = re.search(r'<w:numPr><w:ilvl w:val="(\d+)" /><w:numId w:val="(\d+)" /></w:numPr>', p)
        left = indents.get(num.group(2), {}).get(num.group(1), '0') if num else '0'
        ppr = re.search(r'<w:pPr>.*?</w:pPr>', p, re.S)
        if not ppr: return p
        keep = '<w:keepNext />' if '<w:keepNext' in ppr.group(0) else ''
        new = f'<w:pPr><w:pStyle w:val="{style.group(1)}" />{keep}<w:ind w:left="{left}" w:firstLine="0" /></w:pPr>'
        return p[:ppr.start()] + new + p[ppr.end():]
    return PARA.sub(fix, xml)

def border(path):
    tmp = path + '.tmp'
    with zipfile.ZipFile(path) as z:
        indents = list_indents(z.read('word/numbering.xml').decode('utf-8')) if 'word/numbering.xml' in z.namelist() else {}
    with zipfile.ZipFile(path) as zin, zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/document.xml':
                xml = data.decode('utf-8')
                xml = xml.replace('<a:ln w="9525"><a:noFill />', '<a:ln w="9525"><a:solidFill><a:srgbClr val="C9D1DA" /></a:solidFill>')
                # no gap around a picture: Word assumes none, LibreOffice adds its own when the attributes are missing
                xml = xml.replace('<wp:inline>', '<wp:inline distT="0" distB="0" distL="0" distR="0">')
                data = align_figures(keep_steps_with_pictures(xml), indents).encode('utf-8')
            zout.writestr(item, data)
    os.replace(tmp, path)

PARA = re.compile(r'<w:p(?: [^>]*)?>.*?</w:p>', re.S)

def keep_next(p):
    # keepNext goes right after pStyle when there is one, else first in pPr: the schema order Word expects
    if '<w:keepNext' in p: return p
    if '<w:pPr>' not in p: return re.sub(r'^(<w:p(?: [^>]*)?>)', r'\1<w:pPr><w:keepNext /></w:pPr>', p, count=1)
    if re.search(r'<w:pPr>.*?<w:pStyle [^>]*/>', p, re.S): return re.sub(r'(<w:pPr>.*?<w:pStyle [^>]*/>)', r'\1<w:keepNext />', p, count=1, flags=re.S)
    return p.replace('<w:pPr>', '<w:pPr><w:keepNext />', 1)

def keep_steps_with_pictures(xml):
    spans = [m.span() for m in PARA.finditer(xml)]
    out, last = [], 0
    for i, (a, b) in enumerate(spans):
        p = xml[a:b]
        nxt = xml[spans[i + 1][0]:spans[i + 1][1]] if i + 1 < len(spans) else ''
        if '<w:drawing' in nxt and '<w:drawing' not in p and spans[i + 1][0] - b < 8: p = keep_next(p)
        out.append(xml[last:a]); out.append(p); last = b
    out.append(xml[last:])
    return ''.join(out)

def count(path):
    with zipfile.ZipFile(path) as z: return z.read('word/document.xml').decode('utf-8').count('<pic:pic')

if __name__ == '__main__':
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == 'dpi': print(sum(1 for a in args if set_dpi(a)), 'images tagged')
    elif cmd == 'border': border(args[0]); print('bordered')
    elif cmd == 'count': print(count(args[0]))
