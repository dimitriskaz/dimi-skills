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
for name in ('Normal', 'Body Text', 'First Paragraph', 'Compact'):
    font(S[name], size=11, color=INK); spacing(S[name], after=6, line=1.15)
spacing(S['Compact'], after=2)
font(S['Title'], HEAD, 30, INK, True); spacing(S['Title'], before=120, after=6)
font(S['Subtitle'], HEAD, 16, ACCENT, False); spacing(S['Subtitle'], after=24)
font(S['Date'], size=12, color=MUTED); spacing(S['Date'], after=24)
font(S['Abstract'], size=12, color=INK, italic=False); spacing(S['Abstract'], after=12)
font(S['Heading 1'], HEAD, 18, INK, True); spacing(S['Heading 1'], before=18, after=8)
font(S['Heading 2'], HEAD, 14, ACCENT, True); spacing(S['Heading 2'], before=14, after=6)
font(S['Heading 3'], HEAD, 12, INK, True); spacing(S['Heading 3'], before=10, after=4)
for name in ('Heading 1', 'Heading 2', 'Heading 3'): S[name].paragraph_format.keep_with_next = True
font(S['Image Caption'], size=9.5, color=MUTED, italic=True); spacing(S['Image Caption'], before=2, after=10)
S['Captioned Figure'].paragraph_format.keep_with_next = True
# Block Text: the "Action required" / note box, a left rule and a light fill
bt = S['Block Text']; font(bt, size=11, color=INK, italic=False); spacing(bt, before=6, after=6)
ppr = bt.element.get_or_add_pPr()
for tag in ('w:pBdr', 'w:shd', 'w:ind'):
    old = ppr.find(qn(tag))
    if old is not None: ppr.remove(old)
bdr = OxmlElement('w:pBdr'); left = OxmlElement('w:left')
for k, v in (('w:val', 'single'), ('w:sz', '24'), ('w:space', '8'), ('w:color', '0E4F8B')): left.set(qn(k), v)
bdr.append(left); ppr.append(bdr)
shd = OxmlElement('w:shd'); shd.set(qn('w:val'), 'clear'); shd.set(qn('w:color'), 'auto'); shd.set(qn('w:fill'), 'EEF3F8'); ppr.append(shd)
ind = OxmlElement('w:ind'); ind.set(qn('w:left'), '240'); ind.set(qn('w:right'), '240'); ppr.append(ind)
# hyperlinks
if 'Hyperlink' in S: font(S['Hyperlink'], color=ACCENT)

# the cover shows the summary without an "Abstract" label
at = S['Abstract Title'].element.get_or_add_rPr(); v = OxmlElement('w:vanish'); at.append(v)
S['Abstract Title'].paragraph_format.space_after = Pt(0); S['Abstract Title'].paragraph_format.space_before = Pt(0)
# tables: a bold header row on a light fill with a rule under it, thin rules between rows
tbl = S['Table'].element
for old in tbl.findall(qn('w:tblStylePr')): tbl.remove(old)
tpr = tbl.find(qn('w:tblPr'))
if tpr is None: tpr = OxmlElement('w:tblPr'); tbl.append(tpr)
for old in tpr.findall(qn('w:tblBorders')): tpr.remove(old)
borders = OxmlElement('w:tblBorders')
for side in ('top', 'bottom', 'insideH'):
    e = OxmlElement(f'w:{side}')
    for k, v in (('w:val', 'single'), ('w:sz', '4'), ('w:space', '0'), ('w:color', 'D7DDE4')): e.set(qn(k), v)
    borders.append(e)
tpr.append(borders)
mar = OxmlElement('w:tblCellMar')
for side, w in (('top', '60'), ('bottom', '60'), ('left', '100'), ('right', '100')):
    e = OxmlElement(f'w:{side}'); e.set(qn('w:w'), w); e.set(qn('w:type'), 'dxa'); mar.append(e)
tpr.append(mar)
first = OxmlElement('w:tblStylePr'); first.set(qn('w:type'), 'firstRow')
rpr = OxmlElement('w:rPr'); b = OxmlElement('w:b'); rpr.append(b); first.append(rpr)
tcpr = OxmlElement('w:tcPr'); shd = OxmlElement('w:shd'); shd.set(qn('w:val'), 'clear'); shd.set(qn('w:color'), 'auto'); shd.set(qn('w:fill'), 'EEF3F8'); tcpr.append(shd)
tcb = OxmlElement('w:tcBorders'); bot = OxmlElement('w:bottom')
for k, v in (('w:val', 'single'), ('w:sz', '8'), ('w:space', '0'), ('w:color', '5A6572')): bot.set(qn(k), v)
tcb.append(bot); tcpr.append(tcb); first.append(tcpr); tbl.append(first)

sec = d.sections[0]
for side in ('left_margin', 'right_margin'): setattr(sec, side, Cm(2.2))
sec.top_margin = Cm(2.0); sec.bottom_margin = Cm(2.0)
# footer: Page X of Y, muted, centred
p = sec.footer.paragraphs[0] if sec.footer.paragraphs else sec.footer.add_paragraph()
for r in list(p.runs): r._element.getparent().remove(r._element)
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
def run(text=None, field=None):
    r = p.add_run(text or ''); r.font.size = Pt(9); r.font.color.rgb = MUTED; r.font.name = BODY
    if field:
        r.text = ''
        for kind, val in (('begin', None), ('instr', field), ('separate', None), ('text', '1'), ('end', None)):
            if kind == 'instr':
                e = OxmlElement('w:instrText'); e.set(qn('xml:space'), 'preserve'); e.text = f' {val} '; r._element.append(e)
            elif kind == 'text':
                e = OxmlElement('w:t'); e.text = '1'; r._element.append(e)
            else:
                e = OxmlElement('w:fldChar'); e.set(qn('w:fldCharType'), kind); r._element.append(e)
run('Page '); run(field='PAGE'); run(' of '); run(field='NUMPAGES')
d.save(out)
print('written', out)
