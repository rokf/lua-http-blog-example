
local server = require 'http.server'
local headers = require 'http.headers'
local version = require 'http.version'
local util = require 'http.util'

local cqueues = require 'cqueues'
local signal = require 'cqueues.signal'

local router = require 'router'
local r = router.new()

local etlua = require 'etlua'
local pgmoon = require 'pgmoon'
local uuid = require 'lua_uuid'


local hex = function (str)
  return string.gsub(str,".",function (c)
    return string.format("%02x", string.byte(c))
  end)
end

local hash_pass = function (pass)
  local digest = require 'openssl.digest'
  local sha256 = digest.new('sha256')
  return hex(sha256:final(pass))
end

-- TODO move into external file
local config = {
  host = "127.0.0.1",
  port = 8000,
  title = "Blog",
  pgport = 5432,
  dbname = "blog",
  dbuser = "postgres",
  socket_type = "cqueues"
}

local sessions = {}

local pg = pgmoon.new({
  host = config.host,
  port = tostring(config.pgport),
  database = config.dbname,
  user = config.dbuser
})

assert(pg:connect())

local cq = cqueues.new()

local sl = signal.listen(signal.SIGINT)
signal.block(signal.SIGINT)

cq:wrap(function ()
  local signo
  while true do
    signo = sl:wait(0.5)
    if signo == signal.SIGINT then
      print('\nINTERRUPTED!')
      os.exit(true)
    end
  end
end)

-- TEMPLATES
local templates = {}

local function append_template(name,filename)
  local t_file = assert(io.open(filename))
  templates[name] = etlua.compile(t_file:read('*all'))
  t_file:close()
end

append_template('index', 'templates/index.etlua') -- wrapper template
append_template('home', 'templates/home.etlua')
append_template('login', 'templates/login.etlua')
append_template('register', 'templates/register.etlua')

-- UTILS
local function view(name,p)
  local txt = templates.index({
    title = config.title,
    session = p.session,
    content = templates[name](p)
  })
  sessions[p.session_id].errors = nil
  return {
    txt = txt
  }
end

local function redirect(path,s)
  return {
    status = s or 302,
    redirect = path
  }
end

-- ROUTES
r:match({
  GET = {
    ['/'] = function (params)
      return view('home', params)
    end,
    ['/login'] = function (params)
      if sessions[params.session_id].user then
        return redirect('/')
      else
        return view('login', params)
      end
    end,
    ['/logout'] = function (params)
      sessions[params.session_id].user = nil
      return redirect('/')
    end,
    ['/register'] = function (params)
      return view('register', params)
    end
  },
  POST = {
    ['/login'] = function (params)
      local res, err = pg:query(
        string.format('select name,email,password from users where email = %s',
          pg:escape_literal(params.query.email)
        )
      )

      local pwhash = hash_pass(params.query.password)
      if res then
        if res[1].password == pwhash then
          sessions[params.session_id].user = {
            email = res[1].email,
            username = res[1].name
          }
        else
          sessions[params.session_id].errors = {
            'Incorrect email and password combination'
          }
          return redirect('/login')
        end
      end
      return redirect('/')
    end,
    ['/register'] = function (params)
      local res, err = pg:query(
        string.format('insert into users (name, email, password, created_at) values (%s,%s,%s,localtimestamp)',
          pg:escape_literal(params.query.username),
          pg:escape_literal(params.query.email),
          pg:escape_literal(hash_pass(params.query.password))
        )
      )

      if res then
        sessions[params.session_id].user = {
          email = params.query.email,
          username = params.query.username,
        }
      end

      print(res, err)
      return redirect('/')
    end
  }
})

-- MAIN LOOP
cq:wrap(function ()
  local s = server.listen({
    host = config.host,
    port = config.port,
    onstream = function(_, st)
      local reqh = st:get_headers()
      local method = reqh:get(':method')
      local path = reqh:get(':path')

      local resh = headers.new()
      resh:append(":status", nil)
      resh:append("server", string.format("%s/%s",version.name, version.version))
      resh:append("date", util.imf_date())

      local just_path = string.match(path,'([^?]*)')
      local just_query = string.match(path,'%?(.+)')

      local body = assert(st:get_body_as_string())

      if method == "POST" then
        just_query = body
      end

      local url_query = {}
      if just_query ~= nil and just_query ~= '' then
        for name,value in util.query_args(just_query) do
          url_query[name] = value
        end
      end

      local cookie_sequence = reqh:get_as_sequence('cookie') or {}
      local session_id = nil -- session_id of this request

      for _,cookie in ipairs(cookie_sequence) do
        local k,v = string.match(cookie,'([^=]+)=([^;]+)')
        if k == "session_id" then session_id = v end
      end

      if session_id == nil or sessions[session_id] == nil then
        session_id = uuid()
        resh:upsert('set-cookie','session_id=' .. session_id, true)
        sessions[session_id] = {
          created_at = os.time()
        }
      end

      print('session_id', session_id, sessions[session_id].created_at)

      local route_data = {
        query = url_query,
        body = body,
        session_id = session_id,
        session = sessions[session_id]
      }

      local route_found, data = r:execute(method, just_path, route_data)

      if not route_found then
        resh:upsert(':status','404')
        resh:upsert('content-type','text/html')
        st:write_headers(resh, false)
        st:write_body_from_string('404 not found!')
      else
        resh:upsert(':status',tostring(data.status or 200))
        resh:upsert('content-type','text/html')
        if data.redirect then
          resh:upsert('Location',data.redirect)
        end
        st:write_headers(resh, false)
        if not data.redirect then
          st:write_body_from_string(data.txt)
        end
      end
    end
  })
  s:loop()
end)

cq:loop()
