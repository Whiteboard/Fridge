helpers do
	def logged_in?
		if session[:username].nil?
			return false
		else
			return true
		end
	end
	def admin?
		return logged_in? && (current_user.email.include?("whiteboard.is") || current_user.email.include?("whiteboardnetwork.com"))
	end
	def authenticate!
		if !logged_in?
			flash[:warning] = "You must be logged in to do that!"
			redirect '/'
		end
	end
	def current_user
		if logged_in?
			User.first(:username => session[:username].downcase)
		else
			"Guest"
		end
	end
	def current_user_name
		if logged_in?
			@username = current_user.username
		else
			@username = current_user
		end
	end
	def commit_message
		`git show`
	end
end