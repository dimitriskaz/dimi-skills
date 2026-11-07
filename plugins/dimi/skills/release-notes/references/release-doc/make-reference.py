# Rebuilds reference.docx, the default Word template for release documents, from pandoc's own reference.docx:
#   pandoc -o pandoc-reference.docx --print-default-data-file reference.docx && python3 make-reference.py pandoc-reference.docx reference.docx
# Needs python-docx (pip install python-docx); only maintainers run this, never the skill.
import sys, copy
from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

src, out = sys.argv[1], sys.argv[2]
d = Document(src)
INK, MUTED, ACCENT = RGBColor(0x1F, 0x29, 0x37), RGBColor(0x5A, 0x65, 0x72), RGBColor(0x0E, 0x4F, 0x8B)
BODY, HEAD = 'Calibri', 'Calibri'

def font(style, name=BODY, size=None, color=None, bold=None, italic=None):
    f = style.font; f.name = name
    rpr = style.element.get_or_add_rPr(); fonts = rpr.find(qn('w:rFonts'))
    if fonts is None: fonts = OxmlElement('w:rFonts'); rpr.append(fonts)
    for a in ('w:ascii', 'w:hAnsi', 'w:cs', 'w:eastAsia'): fonts.set(qn(a), name)
    for a in ('w:asciiTheme', 'w:hAnsiTheme', 'w:cstheme', 'w:eastAsiaTheme'):
        if fonts.get(qn(a)) is not None: del fonts.attrib[qn(a)]
    if size: f.size = Pt(size)
    if color is not None: f.color.rgb = color
    if bold is not None: f.bold = bold
    if italic is not None: f.italic = italic

def spacing(style, before=None, after=None, line=None):
    pf = style.paragraph_format
    if before is not None: pf.space_before = Pt(before)
    if after is not None: pf.space_after = Pt(after)
    if line is not None: pf.line_spacing = line

S = {st.name: st for st in d.styles}   # by stored name: python-docx's own lookup renames built-in headings
from docx.enum.style import WD_STYLE_TYPE

def ensure(name, base='Normal'):
    if name not in S:
        st = d.styles.add_style(name, WD_STYLE_TYPE.PARAGRAPH); st.base_style = S[base]; S[name] = st
    return S[name]

def border(style, side, sz, color, space):
    ppr = style.element.get_or_add_pPr(); bdr = ppr.find(qn('w:pBdr'))
    if bdr is None: bdr = OxmlElement('w:pBdr'); ppr.append(bdr)
    old = bdr.find(qn(f'w:{side}'))
    if old is not None: bdr.remove(old)
    e = OxmlElement(f'w:{side}')
    for k, v in (('w:val', 'single'), ('w:sz', str(sz)), ('w:space', str(space)), ('w:color', color)): e.set(qn(k), v)
    bdr.append(e)

def left(style): style.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT

# body: 11 pt, 1.15 lines, 8 pt between paragraphs; lists tighter
for name in ('Normal', 'Body Text', 'First Paragraph'):
    font(S[name], size=11, color=INK); spacing(S[name], before=0, after=8, line=1.15)
font(S['Compact'], size=11, color=INK); spacing(S['Compact'], before=0, after=4, line=1.15)

# cover: everything left-aligned under a rule, a third of the way down, with room to breathe
for name in ('Title', 'Subtitle', 'Date', 'Abstract'): left(S[name])
font(S['Title'], HEAD, 32, INK, True); spacing(S['Title'], before=150, after=4, line=1.0)
border(S['Title'], 'top', 24, '0E4F8B', 18)
font(S['Subtitle'], HEAD, 18, ACCENT, False); spacing(S['Subtitle'], before=0, after=18, line=1.0)
font(S['Date'], size=11, color=MUTED); spacing(S['Date'], before=0, after=30)
font(S['Abstract'], size=12.5, color=INK, italic=False); spacing(S['Abstract'], before=0, after=0, line=1.3)
S['Abstract'].paragraph_format.right_indent = Cm(3)
S['Abstract'].paragraph_format.left_indent = Cm(0)

# headings: clear steps, a hairline under each section, always with what follows
font(S['Heading 1'], HEAD, 18, INK, True); spacing(S['Heading 1'], before=24, after=10, line=1.0)
border(S['Heading 1'], 'bottom', 4, 'D7DDE4', 4)
font(S['Heading 2'], HEAD, 14, ACCENT, True); spacing(S['Heading 2'], before=18, after=6, line=1.0)
font(S['Heading 3'], HEAD, 12, INK, True); spacing(S['Heading 3'], before=12, after=4, line=1.0)
for name in ('Heading 1', 'Heading 2', 'Heading 3'): S[name].paragraph_format.keep_with_next = True

# contents: a quiet column of links, no bullets
ce = ensure('Contents Entry'); font(ce, size=11, color=INK); spacing(ce, before=0, after=5, line=1.0)

# figures: space above (never against a table), the picture kept with its caption
spacing(S['Captioned Figure'], before=10, after=4, line=1.0); S['Captioned Figure'].paragraph_format.keep_with_next = True
spacing(S['Figure'], before=10, after=10, line=1.0)
font(S['Image Caption'], size=9.5, color=MUTED, italic=True); spacing(S['Image Caption'], before=0, after=14, line=1.1)

# Block Text: the "action required" box: a left rule, a light fill, and padding on every side
bt = S['Block Text']; font(bt, size=11, color=INK, italic=False); spacing(bt, before=10, after=12, line=1.2)
ppr = bt.element.get_or_add_pPr()
for tag in ('w:pBdr', 'w:shd', 'w:ind'):
    old = ppr.find(qn(tag))
    if old is not None: ppr.remove(old)
border(bt, 'top', 4, 'EEF3F8', 8); border(bt, 'left', 24, '0E4F8B', 10); border(bt, 'bottom', 4, 'EEF3F8', 8); border(bt, 'right', 4, 'EEF3F8', 10)
shd = OxmlElement('w:shd'); shd.set(qn('w:val'), 'clear'); shd.set(qn('w:color'), 'auto'); shd.set(qn('w:fill'), 'EEF3F8'); ppr.append(shd)
ind = OxmlElement('w:ind'); ind.set(qn('w:left'), '260'); ind.set(qn('w:right'), '260'); ppr.append(ind)
if 'Hyperlink' in S: font(S['Hyperlink'], color=ACCENT)

# the cover shows the summary without an "Abstract" label
at = S['Abstract Title'].element.get_or_add_rPr(); v = OxmlElement('w:vanish'); at.append(v)
S['Abstract Title'].paragraph_format.space_after = Pt(0); S['Abstract Title'].paragraph_format.space_before = Pt(0)

# tables: a bold header row on a light fill with a rule under it, thin rules between rows, roomy cells
tbl = S['Table'].element
for old in tbl.findall(qn('w:tblStylePr')): tbl.remove(old)
tpr = tbl.find(qn('w:tblPr'))
if tpr is None: tpr = OxmlElement('w:tblPr'); tbl.append(tpr)
for tag in ('w:tblBorders', 'w:tblCellMar'):
    for old in tpr.findall(qn(tag)): tpr.remove(old)
borders = OxmlElement('w:tblBorders')
for side in ('top', 'bottom', 'insideH'):
    e = OxmlElement(f'w:{side}')
    for k, v in (('w:val', 'single'), ('w:sz', '4'), ('w:space', '0'), ('w:color', 'D7DDE4')): e.set(qn(k), v)
    borders.append(e)
tpr.append(borders)
mar = OxmlElement('w:tblCellMar')
for side, w in (('top', '80'), ('bottom', '80'), ('left', '120'), ('right', '120')):
    e = OxmlElement(f'w:{side}'); e.set(qn('w:w'), w); e.set(qn('w:type'), 'dxa'); mar.append(e)
tpr.append(mar)
first = OxmlElement('w:tblStylePr'); first.set(qn('w:type'), 'firstRow')
rpr = OxmlElement('w:rPr'); b = OxmlElement('w:b'); rpr.append(b); first.append(rpr)
tcpr = OxmlElement('w:tcPr'); shd = OxmlElement('w:shd'); shd.set(qn('w:val'), 'clear'); shd.set(qn('w:color'), 'auto'); shd.set(qn('w:fill'), 'EEF3F8'); tcpr.append(shd)
tcb = OxmlElement('w:tcBorders'); bot = OxmlElement('w:bottom')
for k, v in (('w:val', 'single'), ('w:sz', '8'), ('w:space', '0'), ('w:color', '5A6572')): bot.set(qn(k), v)
tcb.append(bot); tcpr.append(tcb); first.append(tcpr); tbl.append(first)

# page: one-inch margins (about 90 characters a line), no number on the cover, "Page X of Y" after it
sec = d.sections[0]
for side in ('left_margin', 'right_margin', 'top_margin', 'bottom_margin'): setattr(sec, side, Cm(2.54))
sec.different_first_page_header_footer = True
footer = ensure('Footer'); font(footer, size=9, color=MUTED); spacing(footer, before=0, after=0, line=1.0)
footer.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
p = sec.footer.paragraphs[0] if sec.footer.paragraphs else sec.footer.add_paragraph()
for r in list(p.runs): r._element.getparent().remove(r._element)
p.style = footer
def run(text=None, field=None):
    r = p.add_run(text or '')
    if field:
        r.text = ''
        for kind in ('begin', 'instr', 'separate', 'text', 'end'):
            if kind == 'instr':
                e = OxmlElement('w:instrText'); e.set(qn('xml:space'), 'preserve'); e.text = f' {field} '; r._element.append(e)
            elif kind == 'text':
                e = OxmlElement('w:t'); e.text = '1'; r._element.append(e)
            else:
                e = OxmlElement('w:fldChar'); e.set(qn('w:fldCharType'), kind); r._element.append(e)
run('Page '); run(field='PAGE'); run(' of '); run(field='NUMPAGES')
fp = sec.first_page_footer.paragraphs[0] if sec.first_page_footer.paragraphs else sec.first_page_footer.add_paragraph()
fp.style = footer
d.save(out)
print('written', out)
