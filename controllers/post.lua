
function post_all_get(params)
  local res, err = pg:query('select p.id, p.title, u.name as author, p.article from users as u, posts as p where u.id = p.user_id')
  local newparams = shallow_clone(params)
  newparams.posts = res
  return view('posts',newparams)
end

function post_single_get(params)
  local res, err = pg:query(
    string.format(
      'select p.id, p.title, u.name as author, p.article from users as u, posts as p where u.id = p.user_id and p.id = %s',
      params.postid
    )
  )

  local res2, err2 = pg:query(
    string.format(
      'select c.txt, u.name as author, c.created_at from users as u, comments as c where u.id = c.user_id and c.post_id = %s',
      params.postid
    )
  )

  if res == nil or #res == 0 then return redirect('/') end
  if res2 == nil then return redirect('/') end

  local newparams = shallow_clone(params)
  newparams.post = res[1]
  newparams.comments = res2
  return view('post', newparams)
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


function post_my_get(params)
  if sessions[params.session_id].user == nil then return redirect('/') end
  local res, err = pg:query(
    string.format(
      'select id, title, user_id, updated_at from posts where user_id = %d',
      sessions[params.session_id].user.id
    )
  )

  local newparams = shallow_clone(params)
  newparams.posts = res
  return view('myposts', newparams)
end

-- delete post
function post_delete(params)
  if sessions[params.session_id].user == nil then return redirect('/') end
  if tostring(sessions[params.session_id].user.id) ~= params.query.userid then return redirect('/') end
  local res,err = pg:query(
    string.format(
      'delete from posts where id = %s',
      pg:escape_literal(params.query.postid)
    )
  )

  if res ~= nil then
    -- delete comments related to post
    local res,err = pg:query(
      string.format(
        'delete from comments where post_id = %s',
        pg:escape_literal(params.query.postid)
      )
    )
  end

  return redirect('/myposts')
end

-- GET the edit view
function post_edit_get(params)
  return view('editpost',params)
end

-- POST the edit
function post_edit_post(params)
  return redirect('/myposts')
end
