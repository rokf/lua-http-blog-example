function dashboard_get(params)
  if sessions[params.session_id].user == nil then
    return redirect('/')
  end
  return view('dashboard', params)
end

function dashboard_update_profile(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then
    return redirect('/')
  end

  if sessions[params.session_id].user ~= nil then
    local res = pg:execParams([[
      update users
      set name = $1
      where id = $2
    ]],
    drpl(params.query.name),
    tonumber(sessions[params.session_id].user.id))
    if res ~= nil and res:status() == 1 then
      sessions[params.session_id].user.name = drpl(params.query.name)
    end
  end
  return redirect('/dashboard')
end

function dashboard_update_email(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then
    return redirect('/')
  end

  if sessions[params.session_id].user ~= nil and
    params.query.email == params.query.email_copy then
    local res = pg:execParams([[
      update users
      set email = $1
      where id = $2
    ]],
    params.query.email,
    tonumber(sessions[params.session_id].user.id))

    if res ~= nil and res:status() == 1 then
      sessions[params.session_id].user.email = params.query.email
    end
  end
  return redirect('/dashboard')
end

function dashboard_update_password(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then
    return redirect('/')
  end

  if sessions[params.session_id].user ~= nil and
    params.query.password == params.query.password_copy then
    -- check old password
    local res = pg:execParams([[
      select id, password
      from users
      where id = $1
    ]],
    tonumber(sessions[params.session_id].user.id))

    if res == nil or res:status() ~= 2 then
      return redirect('/')
    end

    if res_to_table(res)[1].password == hash_pass(params.query.old_password) then
      -- update password
      pg:execParams([[
        update users
        set password = $1
        where id = $2
      ]],
      hash_pass(params.query.password),
      tonumber(sessions[params.session_id].user.id))
    end
  end
  return redirect('/logout')
end
