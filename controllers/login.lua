
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
end
