-- Pandoc filter for the release document.
--   The cover (title, subtitle, date, abstract) gets a page of its own.
--   A heading marked {.newpage} starts a new page.
--   The list under a heading marked {.contents} becomes a column of links in the "Contents Entry" style, without bullets.
local pagebreak = pandoc.RawBlock('openxml', '<w:p><w:r><w:br w:type="page"/></w:r></w:p>')

local function entries(list)
  local out = {}
  for _, item in ipairs(list.content) do
    local first = item[1]
    if first and (first.t == 'Plain' or first.t == 'Para') then
      table.insert(out, pandoc.Div({ pandoc.Para(first.content) }, pandoc.Attr('', {}, { ['custom-style'] = 'Contents Entry' })))
    end
  end
  return out
end

function Pandoc(doc)
  local blocks, contents = { pagebreak }, false
  for _, b in ipairs(doc.blocks) do
    if b.t == 'Header' and b.classes:includes('newpage') then table.insert(blocks, pagebreak) end
    if contents and b.t == 'BulletList' then
      for _, e in ipairs(entries(b)) do table.insert(blocks, e) end
    else
      table.insert(blocks, b)
    end
    contents = (b.t == 'Header' and b.classes:includes('contents'))
  end
  doc.blocks = blocks
  return doc
end
