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
  local s = string.match(path,"(%.%a+)$")
  if s == nil or lt[s] == nil then return 'text/plain' end
  return lt[s]
end
