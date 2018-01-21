function logout_get(params)
  sessions[params.session_id].user = nil
  return redirect('/')
end
