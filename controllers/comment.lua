function comment_insert(params)
  if sessions[params.session_id].user == nil then return redirect('/') end
  if params.query.csrf_token ~= sessions[params.session_id].csrf then return redirect('/') end

  local res = pg:execParams([[
    insert into comments
    (post_id, user_id, txt, created_at)
    values ($1, $2, $3, localtimestamp)
  ]], tonumber(params.query.postid),
  tonumber(sessions[params.session_id].user.id),
  drpl(params.query.txt))

  if res ~= nil and res:status() == 1 then
    sessions[params.session_id].messages = {
      'Your comment has been added'
    }
  else
    sessions[params.session_id].errors = {
      'The comment could not be added'
    }
  end

  return redirect('/posts/' .. params.query.postid)
end
