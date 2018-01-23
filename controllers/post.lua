
function post_all_get(params)
  return view('posts', params)
end

function post_single_get(params)
  return view('post', params)
end

function post_new_get(params)
  return view('newpost', params)
end

function post_new_post(params)
  return redirect('/')
end
