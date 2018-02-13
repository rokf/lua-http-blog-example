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
    local res = pg:exec(
      string.format([[update users set name = %s where id = %d]],
        escape(drpl(params.query.name)),
        escape(sessions[params.session_id].user.id)
      )
    )
    if res ~= nil then
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
    local res = pg:exec(
      string.format([[update users set email = %s where id = %d]],
        escape(params.query.email),
        escape(sessions[params.session_id].user.id)
      )
    )
    if res ~= nil then
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
    local res = pg:exec(
      string.format([[select id, password from users where id = %d]],
        escape(sessions[params.session_id].user.id)
      )
    )

    if res == nil then return redirect('/') end

    if res_to_table(res)[1].password == hash_pass(params.query.old_password) then
      -- update password
      local res2 = pg:exec(
        string.format([[update users set password = %s where id = %d]],
          escape(hash_pass(params.query.password)),
          escape(sessions[params.session_id].user.id)
        )
      )
    end
  end
  return redirect('/logout')
end
