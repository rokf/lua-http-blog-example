
function register_get(params)
  return view('register', params)
end

function register_post(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then
    return redirect('/')
  end

  local res = pg:exec(
    string.format([[insert into users (name, email, password, created_at) values (%s,%s,%s,localtimestamp)]],
      escape(drpl(params.query.name)),
      escape(params.query.email),
      escape(hash_pass(params.query.password))
    )
  )

  local res2 = pg:exec(
    string.format([[select id, email from users where email = %s]],
      escape(params.query.email)
    )
  )

  if res and res2 then
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
