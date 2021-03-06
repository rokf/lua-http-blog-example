
local server = require 'http.server'
local headers = require 'http.headers'
local version = require 'http.version'
local util = require 'http.util'

function drpl(i)
  return string.gsub(util.decodeURI(i),'%+',' ')
end

local cqueues = require 'cqueues'
local signal = require 'cqueues.signal'

local router = require 'router'
local r = router.new()

local etlua = require 'etlua'
local pgsql = require "cqueues_pgsql"

local lfs = require 'lfs'

-- mime type lookup table
-- used by global function gen_ct
lt = dofile('lt.lua')

-- global module imports
uuid = require 'lua_uuid'
serpent = require 'serpent'
require 'globals'
require 'controllers.login'
require 'controllers.register'
require 'controllers.logout'
require 'controllers.dashboard'
require 'controllers.post'
require 'controllers.comment'


-- global variables
config = dofile('config.lua')
sessions = {}
templates = {
  upsert = function (self, name, filename)
    local t_file = assert(io.open(filename))
    self[name] = etlua.compile(t_file:read('*all'))
    t_file:close()
  end
}

-- postgres connection
pg = pgsql.connectdb(config.pg_con_string)
assert(pg:status() == pgsql.CONNECTION_OK)

local cq = cqueues.new()

-- interrupt handling
local sl = signal.listen(signal.SIGINT)
signal.block(signal.SIGINT)

cq:wrap(function ()
  local signo
  while true do
    signo = sl:wait(0.5)
    if signo == signal.SIGINT then
      pg:finish()
      os.exit(true)
    end
  end
end)

template_pairs = {
  ['templates/index.etlua'] = {
    name = 'index'
  },
  ['templates/home.etlua'] = {
    name = 'home'
  },
  ['templates/login.etlua'] = {
    name = 'login'
  },
  ['templates/register.etlua'] = {
    name = 'register'
  },
  ['templates/dashboard.etlua'] = {
    name = 'dashboard'
  },
  ['templates/posts.etlua'] = {
    name = 'posts'
  },
  ['templates/post.etlua'] = {
    name = 'post'
  },
  ['templates/newpost.etlua'] = {
    name = 'newpost'
  },
  ['templates/myposts.etlua'] = {
    name = 'myposts'
  },
  ['templates/editpost.etlua'] = {
    name = 'editpost'
  },
  ['templates/favorites.etlua'] = {
    name = 'favorites'
  },
}

for pth,tidx in pairs(template_pairs) do
  templates:upsert(tidx.name,pth)
end

-- template reloading
if config.dev then
  cq:wrap(function ()
    while true do
      for tf in lfs.dir('templates') do
        if tf ~= "." and tf ~= ".." then
          local tfp = 'templates/' .. tf
          local modified = lfs.attributes(tfp,'modification')
          if template_pairs[tfp].modified == nil or template_pairs[tfp].modified < modified then
            template_pairs[tfp].modified = modified
            templates:upsert(template_pairs[tfp].name,tfp)
            print('updated', tfp)
          end
        end
      end
      cqueues.sleep(0.5)
    end
  end)
end

--> ROUTES
r:match({
  GET = {
    ['/'] = post_all_get,
    ['/login'] = login_get,
    ['/logout'] = logout_get,
    ['/register'] = register_get,
    ['/dashboard'] = dashboard_get,
    ['/posts'] = post_all_get,
    ['/new_post'] = post_new_get,
    ['/posts/:postid'] = post_single_get,
    ['/posts_of/:userid'] = posts_of_user_get,
    ['/myposts'] = post_my_get,
    ['/edit_post'] = post_edit_get,
    ['/favorites'] = post_favorites_get
  },
  POST = {
    ['/login'] = login_post,
    ['/register'] = register_post,
    ['/dashboard/update_profile'] = dashboard_update_profile,
    ['/dashboard/update_email'] = dashboard_update_email,
    ['/dashboard/update_password'] = dashboard_update_password,
    ['/new_post'] = post_new_post,
    ['/comment'] = comment_insert,
    ['/edit_post'] = post_edit_post,
    ['/delete_post'] = post_delete,
    ['/post_favorite'] = post_favorite,
    ['/post_unfavorite'] = post_unfavorite
  }
})

-- timeout in seconds
local TIMEOUT = 1

cq:wrap(function ()
  local s = server.listen({
    host = config.host,
    port = config.port,
    onstream = function(_, st)
      local reqh = st:get_headers(TIMEOUT)
      if reqh == nil then st:shutdown(); return end
      local method = reqh:get(':method')
      local path = reqh:get(':path')

      local resh = headers.new()
      resh:append(":status", nil)
      resh:append("server", string.format("%s/%s",version.name, version.version))
      resh:append("date", util.imf_date())

      local just_path = string.match(path,'([^?]*)')
      local static_path = string.match(just_path,'/(static/.+)')
      local just_query = string.match(path,'%?(.+)')

      if static_path ~= nil or just_path == '/favicon.ico' and method == "GET" then
        local p = static_path and static_path or  'static' .. just_path
        local file = io.open(p,'rb')
        if file ~= nil then
          print('serving static', p)
          resh:upsert(":status", "200")
          resh:append("content-type", gen_ct(p))
          if st:write_headers(resh, false, TIMEOUT) == nil then
            st:shutdown(); return
          end

          if st:write_body_from_file(file, TIMEOUT) == nil then
            st:shutdown(); return
          end
          file:close()
        else
          resh:upsert(":status", "404")
          -- resh:append("content-type", "text/plain; charset=utf-8")
          if st:write_headers(resh, true, TIMEOUT) == nil then
            st:shutdown(); return
          end
        end
      else
        local body = st:get_body_as_string(TIMEOUT)
        if body == nil then st:shutdown(); return end

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

        -- look for a session_id cookie
        for _,cookie in ipairs(cookie_sequence) do
          local k,v = string.match(cookie,'([^=]+)=([^;]+)')
          if k == "session_id" then
            session_id = v
          end
        end


        if session_id == nil or sessions[session_id] == nil then
          session_id = uuid()
          resh:upsert('set-cookie','session_id=' .. session_id, true)
          sessions[session_id] = {
            created_at = os.time()
          }
        end

        -- csrf gets reset on every GET request
        if method == "GET" then
          sessions[session_id].csrf = nil
        end

        local route_data = {
          query = url_query,
          body = body,
          session_id = session_id,
          session = sessions[session_id]
        }

        local route_found, data
        route_found, data = r:execute(method, just_path, route_data)

        if not route_found then
          resh:upsert(':status','404')
          resh:upsert('content-type','text/html')
          if st:write_headers(resh, false, TIMEOUT) == nil then
            st:shutdown(); return
          end
          if st:write_body_from_string('404 not found!', TIMEOUT) == nil then
            st:shutdown(); return
          end
        else
          print('serving dynamic', just_path)
          resh:upsert(':status',tostring(data.status or 200))
          if data.ctype then
            resh:upsert('content-type', data.ctype)
          else
            resh:upsert('content-type','text/html')
          end
          if data.redirect then
            resh:upsert('Location',data.redirect)
          end
          if st:write_headers(resh, false, TIMEOUT) == nil then
            st:shutdown(); return
          end
          if not data.redirect then
            if st:write_body_from_string(data.txt, TIMEOUT) == nil then
              st:shutdown(); return
            end
          end
        end
      end
    end
  })
  s:loop()
end)

cq:loop()
