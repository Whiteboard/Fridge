post "/users/create" do
	# new user
	user = User.new
	user.salt = BCrypt::Engine.generate_salt
	user.phash = BCrypt::Engine.hash_secret(params[:password], user.salt)
	# email_hash = Digest::MD5.hexdigest(params[:email].downcase)
	# user.gravatar = "http://www.gravatar.com/avatar/#{email_hash}"
	user.username = params["username"].downcase
	user.nickname = params["nickname"].downcase
	user.email = params["email"].downcase
	user.created_at = Time.now
	user.avatar_url = params[:avatar_url]
 	params.delete :password
 	puts user.inspect
 	if user.save
 		session[:username] = user.username
 		user.logged_in = true
 		user.save
 		flash[:notice] = "Thanks for joining, #{session[:username]}!"
 		redirect '/'
 	else
 		flash[:error] = "Something happened, and we couldn't create your account. Try again?"
 		session[:username] = nil
 		redirect "/users/new"
 	end
end


get '/login' do
	erb :login, :layout => :layout
end

post '/login' do
  u = params[:username].downcase
  acct = User.first(:username => u)
  if acct.nil?
  	flash[:error] = "Your username and/or password was incorrect."
	redirect '/login'
  else
  	if acct.phash == BCrypt::Engine.hash_secret(params[:password], acct.salt)
	  	session[:username] = params[:username].downcase
	  	flash[:notice] = "Welcome back, #{acct.nickname}!"
	  	acct.logged_in = true
	  	acct.save
	  	redirect '/'
	  else
	  	flash[:error] = "Your username and/or password was incorrect."
	  	redirect '/login'
	  end
  end
end

get '/logout' do
	if current_user.nil?
		session.clear
		redirect '/'
	end
	authenticate!
	u = current_user
	u.logged_in = false
	u.save
	session.clear
	redirect '/'
end


get "/users/new" do
	if logged_in?
		flash[:warning] = "You can't create another user when you're still logged in."
		redirect '/' # can't create a new user while you're still logged in.
	else
		erb :'users/new', :layout => :layout
	end
end