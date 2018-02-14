function register_get(params)
  return view('register', params)
end

function register_post(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then
    return redirect('/')
  end

  local res = pg:execParams([[
    insert into users
    (name, email, password, created_at)
    values ($1, $2, $3, localtimestamp)
  ]],
  drpl(params.query.name),
  params.query.email,
  hash_pass(params.query.password))

  local res2 = pg:execParams([[
    select id, email
    from users
    where email = $1
  ]],
  params.query.email)

  if res and res2 and res:status() == 1 and res2:status() == 2 then
    sessions[params.session_id].user = {
      email = params.query.email,
      name = drpl(params.query.name),
      id = res_to_table(res2)[1].id,
    }
    sessions[params.session_id].messages = {
      'Welcome to the platform!'
    }
  end

  return redirect('/')
end
