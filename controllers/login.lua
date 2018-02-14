function login_get(params)
  if sessions[params.session_id].user then
    return redirect('/')
  else
    return view('login', params)
  end
end

function login_post(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then
    return redirect('/')
  end

  local res = pg:execParams([[
    select id,name,email,password
    from users
    where email = $1
    ]],
  params.query.email)

  local pwhash = hash_pass(params.query.password)
  if res ~= nil and res:status() == 2 and res:ntuples() > 0 then
    local res_t = res_to_table(res)
    if res_t[1].password == pwhash then
      sessions[params.session_id].user = {
        email = res_t[1].email,
        name = res_t[1].name,
        id = res_t[1].id
      }
      sessions[params.session_id].messages = {
        'Welcome back ' .. res_t[1].name .. '!'
      }
    else
      sessions[params.session_id].errors = {
        'Incorrect email and password combination'
      }
      return redirect('/login')
    end
  else
    sessions[params.session_id].errors = {
      'There is no registered user with this email'
    }
  end
  return redirect('/')
end
