-- Pandoc filter for the release document: the cover (title, subtitle, date, abstract) gets a page of its own, and a
-- heading marked {.newpage} starts a new page.
local pagebreak = pandoc.RawBlock('openxml', '<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
function Pandoc(doc)
  local blocks = { pagebreak }
  for _, b in ipairs(doc.blocks) do
    if b.t == 'Header' and b.classes:includes('newpage') then table.insert(blocks, pagebreak) end
    table.insert(blocks, b)
  end
  doc.blocks = blocks
  return doc
end
