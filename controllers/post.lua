
function post_all_get(params)
  local res, err = pg:query('select p.title, u.name as author, p.article from users as u, posts as p where u.id = p.user_id')
  local newparams = shallow_clone(params)
  newparams.posts = res
  return view('posts',newparams)
end

function post_single_get(params)
  return view('post', params)
end

function post_new_get(params)
  if sessions[params.session_id].user == nil then return redirect('/') end
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
      pg:escape_literal(drpl(params.query.title)),
      sessions[params.session_id].user.id,
      pg:escape_literal(drpl(params.query.article))))
  if res ~= nil then
    sessions[params.session_id].messages = {
      ("You've just published an article entitled '%s'!"):format(drpl(params.query.title))
    }
  end
  return redirect('/')
end
