
function register_get(params)
  return view('register', params)
end

function register_post(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then
    return redirect('/')
  end

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

  return redirect('/')
end
