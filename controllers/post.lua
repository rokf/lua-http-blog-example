
function post_all_get(params)
  local res = pg:exec([[
  select p.id, p.title, u.name as author, p.article
  from users as u, posts as p
  where u.id = p.user_id
  ]])
  local newparams = shallow_clone(params)
  newparams.posts = res_to_table(res)


  return view('posts',newparams)
end

function post_single_get(params)
  local res = pg:execParams([[
    select p.id, p.title, u.name as author, p.article
    from users as u, posts as p
    where u.id = p.user_id and p.id = $1
    ]],
  tonumber(params.postid))

  local res2 = pg:execParams([[
    select c.txt, u.name as author, c.created_at
    from users as u, comments as c
    where u.id = c.user_id and c.post_id = $1
    ]],
  tonumber(params.postid))

  local favorite_count = 0

  local res3 = pg:execParams([[
    select user_id, post_id
    from favorites
    where post_id = $1
    ]],
  tonumber(params.postid))

  if res3 == nil or res3:status() ~= 2 then return redirect('/') end

  favorite_count = res3:ntuples() or 0

  local is_favorite = false

  if sessions[params.session_id].user ~= nil then
    local res4 = pg:execParams([[
      select user_id, post_id
      from favorites
      where user_id = $1 and post_id = $2
      ]],
    tonumber(sessions[params.session_id].user.id),
    tonumber(params.postid))

    if res4 == nil or res:status() ~= 2 then return redirect('/') end

    if res4:ntuples() > 0 then
      is_favorite = true
    end
  end


  if res == nil or res:status() ~= 2 or res:ntuples() == 0 then return redirect('/') end
  if res2 == nil or res2:status() ~= 2 then return redirect('/') end

  local newparams = shallow_clone(params)
  newparams.post = res_to_table(res)[1]
  newparams.is_favorite = is_favorite
  newparams.favorite_count = favorite_count
  newparams.comments = res_to_table(res2)
  return view('post', newparams)
end

function post_new_get(params)
  if sessions[params.session_id].user == nil then return redirect('/') end
  return view('newpost', params)
end

function post_new_post(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then return redirect('/') end
  if sessions[params.session_id].user == nil then return redirect('/') end
  if #params.query.title < 5 or #params.query.article < 100 then
    sessions[params.session_id].errors = {
      'The article name and/or content was too short.'
    }
    return redirect('/')
  end
  local res = pg:execParams([[
    insert into posts
    (title, user_id, article, created_at, updated_at)
    values ($1, $2, $3, localtimestamp, localtimestamp)
  ]],
  drpl(params.query.title),
  tonumber(sessions[params.session_id].user.id),
  drpl(params.query.article))
  if res ~= nil and res:status() == 1 then
    sessions[params.session_id].messages = {
      ("You've just published an article entitled '%s'!"):format(drpl(params.query.title))
    }
  end
  return redirect('/')
end


function post_my_get(params)
  if sessions[params.session_id].user == nil then return redirect('/') end

  local res = pg:execParams([[
    select id, title, user_id, updated_at
    from posts
    where user_id = $1
  ]],
  tonumber(sessions[params.session_id].user.id))

  if res == nil or res:status() ~= 2 then
    return redirect('/')
  end

  local newparams = shallow_clone(params)
  newparams.posts = res_to_table(res)
  return view('myposts', newparams)
end

-- delete post
function post_delete(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then return redirect('/') end
  if sessions[params.session_id].user == nil then return redirect('/') end
  if tostring(sessions[params.session_id].user.id) ~= params.query.userid then return redirect('/') end

  local res = pg:execParams([[
    delete from posts where id = $1
  ]],
  tonumber(params.query.postid))

  if res ~= nil and res:status() == 1 then
    -- delete comments related to post
    pg:execParams([[
      delete from comments where post_id = $1
    ]],
    tonumber(params.query.postid))

    -- delete favorites related to post
    pg:execParams([[
      delete from favorites where post_id = $1
    ]],
    tonumber(params.query.postid))
  end

  return redirect('/myposts')
end

-- GET the edit view
function post_edit_get(params)
  -- NOTICE ME SENPAI can not check for csrf here because it is a GET request
  if sessions[params.session_id].user == nil then return redirect('/') end
  if tostring(sessions[params.session_id].user.id) ~= params.query.userid then return redirect('/') end
  local pid = params.query.postid
  local uid = params.query.userid

  local res  = pg:execParams([[
    select id, title, user_id, article
    from posts
    where id = $1
  ]],
  tonumber(params.query.postid))

  local newparams = shallow_clone(params)
  newparams.post = res_to_table(res)[1]

  return view('editpost',newparams)
end

-- POST the edit
function post_edit_post(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then return redirect('/') end
  if sessions[params.session_id].user == nil then return redirect('/') end
  if tostring(sessions[params.session_id].user.id) ~= params.query.userid then return redirect('/') end

  local res = pg:execParams([[
    update posts
    set updated_at = localtimestamp, title = $1, article = $2
    where id = $3
  ]],
  drpl(params.query.title),
  drpl(params.query.article),
  tonumber(params.query.postid))

  if res ~= nil and res:status() == 1 then
    sessions[params.session_id].messages = {
      'Your post has been updated with the new title and content'
    }
  else
    sessions[params.session_id].errors = {
      'There was an error, the post could not be updated'
    }
  end

  return redirect('/myposts')
end

function post_favorite(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then return redirect('/') end
  if sessions[params.session_id].user == nil then return redirect('/') end

  local res = pg:execParams([[
    insert into favorites
    (user_id, post_id)
    values ($1, $2)
  ]],
  tonumber(sessions[params.session_id].user.id),
  tonumber(params.query.postid))

  if res ~= nil and res:status() == 1 then
    sessions[params.session_id].messages = {
      'The post has been added to your favorites'
    }
  else
    sessions[params.session_id].errors = {
      'An error occured, the post could not be added to your favorites'
    }
  end

  return redirect('/posts/' .. params.query.postid)
end

function post_unfavorite(params)
  if params.query.csrf_token ~= sessions[params.session_id].csrf then return redirect('/') end
  if sessions[params.session_id].user == nil then return redirect('/') end

  local res = pg:execParams([[
    delete from favorites
    where user_id = $1 and post_id = $2
  ]],
  tonumber(sessions[params.session_id].user.id),
  tonumber(params.query.postid))

  if res ~= nil and res:status() == 1 then
    sessions[params.session_id].messages = {
      'The post has been removed from your favorites'
    }
  else
    sessions[params.session_id].errors = {
      'An error occured, the post could not be removed from your favorites'
    }
  end

  return redirect('/posts/' .. params.query.postid)
end

function post_favorites_get(params)
  if sessions[params.session_id].user == nil then return redirect('/') end

  local res = pg:execParams([[
    select p.title, u.name as author, p.id as pid
    from posts as p, users as u, favorites as f
    where u.id = p.user_id and p.id = f.post_id and f.user_id = $1
  ]],
  tonumber(sessions[params.session_id].user.id))

  if res == nil or res:status() ~= 2 then return redirect('/') end

  local newparams = shallow_clone(params)
  newparams.posts = res_to_table(res)
  return view('favorites', newparams)
end
