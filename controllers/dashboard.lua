function dashboard_get(params)
  if sessions[params.session_id].user == nil then
    return redirect('/')
  else
    return view('dashboard', params)
  end
end

function dashboard_update_profile(params)
  if sessions[params.session_id].user ~= nil then
    local res, err = pg:query(
      string.format('update users set name = %s where id = %d',
        pg:escape_literal(params.query.name),
        pg:escape_literal(sessions[params.session_id].user.id)
      )
    )
    if res ~= nil then
      sessions[params.session_id].user.name = params.query.name
    end
  end
  return redirect('/dashboard')
end

function dashboard_update_email(params)
  if sessions[params.session_id].user ~= nil and
    params.query.email == params.query.email_copy then
    local res, err = pg:query(
      string.format('update users set email = %s where id = %d',
        pg:escape_literal(params.query.email),
        pg:escape_literal(sessions[params.session_id].user.id)
      )
    )
    if res ~= nil then
      sessions[params.session_id].user.email = params.query.email
    end
  end
  return redirect('/dashboard')
end

function dashboard_update_password(params)
  if sessions[params.session_id].user ~= nil and
    params.query.password == params.query.password_copy then
    -- check old password
    local res, err = pg:query(
      string.format('select id, password from users where id = %d',
        pg:escape_literal(sessions[params.session_id].user.id)
      )
    )

    if res == nil then return redirect('/') end

    if res[1].password == hash_pass(params.query.old_password) then
      -- update password
      local res2, err2 = pg:query(
        string.format('update users set password = %s where id = %d',
          pg:escape_literal(hash_pass(params.query.password)),
          pg:escape_literal(sessions[params.session_id].user.id)
        )
      )
    end
  end
  return redirect('/logout')
end
