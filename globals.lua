hex = function (str)
  return string.gsub(str,".",function (c)
    return string.format("%02x", string.byte(c))
  end)
end

hash_pass = function (pass)
  local digest = require 'openssl.digest'
  local sha256 = digest.new('sha256')
  return hex(sha256:final(pass))
end

shallow_clone = function (t)
  local nt = {}
  for k,v in pairs(t) do
    nt[k] = v
  end
  return nt
end

view = function (name,p)
  local txt = templates.index({
    title = config.title,
    session = p.session,
    content = templates[name](p)
  })
  sessions[p.session_id].errors = nil
  sessions[p.session_id].messages = nil
  return {
    txt = txt
  }
end

redirect = function (path,s)
  return {
    status = s or 302,
    redirect = path
  }
end

dd = function (data)
  return {
    ctype = 'text/plain',
    txt = serpent.block(data,{comment=false})
  }
end

csrf_token = function (sid)
  if sessions[sid].csrf == nil then sessions[sid].csrf = uuid() end
  return string.format('<input type="hidden" name="csrf_token" value="%s">', sessions[sid].csrf)
end

gen_ct = function (path)
  if string.match(path, "%.png$") then
    return "image/png"
  elseif string.match(path, "%.jpeg$") then
    return "image/jpeg"
  elseif string.match(path, "%.gif$") then
    return "image/gif"
  elseif string.match(path, "%.svg$") then
    return "image/svg+xml"
  elseif string.match(path, "%.css$") then
    return "text/css"
  elseif string.match(path, "%.[x]?htm[l]?$") then
    return "text/html; charset=utf-8"
  elseif string.match(path, "%.wav$") then
    return "audio/wave"
  elseif string.match(path, "%.webm$") then
    return "video/webm"
  elseif string.match(path, "%.ogg$") then
    return "audio/ogg"
  else
    return "text/plain"
  end
end
