
function post_all_get(params)
  return view('posts', params)
end

function post_single_get(params)
  return view('post', params)
end

function post_new_get(params)
  if sessions[params.session_id].user == nil then
    return redirect('/')
  end

  return view('newpost', params)
end

function post_new_post(params)
  if sessions[params.session_id].user == nil then return redirect('/') end
  if #params.query.title < 5 or #params.query.article < 100 then
    sessions[params.session_id].errors = {
      'The article name and/or content was too short.'
    }
    return redirect('/')
  end
  local res,err = pg:query(
    string.format("insert into posts (title, user_id, article, created_at, updated_at) values (%s,%d,%s,localtimestamp,localtimestamp)",
      pg:escape_literal(params.query.title),
      sessions[params.session_id].user.id,
      pg:escape_literal(params.query.article)))
  if res ~= nil then
    sessions[params.session_id].messages = {
      ("You've just published an article entitled '%s'!"):format(params.query.title)
    }
  end
  return redirect('/')
end
