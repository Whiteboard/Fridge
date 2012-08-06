require 'sinatra'
require 'json'
require 'hpricot'
require 'open-uri'
require 'data_mapper'
require 'bcrypt'
require 'sinatra/flash'
enable :sessions
require './helpers.rb'
# DataMapper::Logger.new(STDOUT, :debug)
require './models.rb'
require './users_controller.rb'


get "/" do
	if logged_in?
		authenticate!
		@bodyclass = "fridge"
		erb :fridge, :layout => :layout
	else
		@bodyclass = "external"
		erb :'users/new', :layout => :layout
	end
end
get "/home.json"  do
	authenticate!
	@users = User.all
	@scratches = Scratch.all(:limit => 20, :order => [:created_at.desc ] ) || {}
	@notifications = current_user.notifieds(:read => false) || {}
	headers["Content-Type"] = "application/json"
	"[" + @users.to_json(:exclude => [:phash, :salt], :methods => [:scratches]) + "," + @scratches.to_json(:methods => [:thoughts]) + ","+ @notifications.to_json(:methods => [:creator] ) + "," + current_user.to_json + "]"
end

post "/scratch" do
	authenticate!
	headers["Content-Type"] = "application/json" #return json from this method
	if params[:message].include? "cl.ly"
		m = params[:message]
		url = m.match(/https?:\/\/[\S]+\.[a-zA-Z]{2,4}\.?[a-zA-Z]?{2,4}[\/\?#]?([\S]+)?/i)[0]
		doc = Hpricot(open(url))
		clly = doc.search("//section[@id='content']").inner_html.strip
	end
	if params[:message].include? "jsfiddle.net"
		m = params[:message]
		url = m.match(/https?:\/\/[\S]+\.[a-zA-Z]{2,4}\.?[a-zA-Z]?{2,4}[\/\?#]?([\S]+)?/i)[0]
		# <iframe style="width: 100%; height: 300px" src="http://jsfiddle.net/jcutrell/8jPZH/embedded/" allowfullscreen="allowfullscreen" frameborder="0"></iframe>
		jsfiddle = "<iframe style='width: 100%; height: 300px' src='#{url}embedded/' allowfullscreen='allowfullscreen' frameborder='0'></iframe>"
	end
	if params[:message].match(/@[a-zA-Z1-9]+/i)
		users = params[:message].scan(/@[a-zA-Z1-9]+/i)
		users.each do |u|
			u.slice! "@"
			user = User.first(:username => u)
			next if user.nil?
			n = Notification.new
			n.creator_id = current_user.id
			n.mtext = params[:message]
			n.read = false
			if n.save
				nfr = Notifier.new
				nfr.user_id = user.id
				nfr.notification_id = n.id
				if !nfr.save
					({ :status => "failure", :entry => n }).to_json
				end
			else
				({ :status => "failure", :entry => n }).to_json
			end
		end
	end
	if params[:message].match(/#location/i)
		location = params[:message].gsub "#location", ""
		u = current_user
		u.location = location.strip
		if !u.save
			({ :status => "failure", :entry => location }).to_json
		end
	end
	if params[:message].match(/#focus/i)
		focus = params[:message].gsub "#focus", ""
		u = current_user
		u.focus = focus.strip
		t = Timecard.first(:order => [:starttime.desc])
		unless t.nil?
			t.endtime = Time.now
			if !t.save
				({ :status => "failure", :entry => focus }).to_json
			end
		end
		clients = Client.all
		selectedclient = nil
		keywords = []
		clients.each do |c|
			keywords.push [c.id, c.keywords]
		end
		if params[:client_name].nil?
			keywords.each do |keys|
				keya = keys[1].split ","
				keya.collect! { |k| k.strip.downcase }
				if keya.any? { |w| params[:message].downcase =~ /#{w}/ }
					selectedclient = Client.first(:id => keys[0])
				end
			end
		else
			selectedclient = Client.first(:clientname => :client_name)
		end
		if !selectedclient.nil?
			tc = Timecard.new
			tc.starttime = Time.now
			tc.description = u.focus
			tc.user_id = current_user.id
			tc.client_id = selectedclient.id
			if !tc.save
				({ :status => "failure", :entry => [tc, focus] }).to_json
			end
		end
		if !u.save
			({ :status => "failure", :entry => focus }).to_json
		end
	end
	s = Scratch.new
	s.jsfiddle = jsfiddle || nil
	s.clly = clly || nil
	s.mtext = params[:message]
	s.created_at = Time.now
	s.user_id = current_user.id
	if s.save
		({ :status => "success", :entry => s }).to_json
	else
		({ :status => "failure", :entry => s }).to_json
	end
end

post "/focus" do
	authenticate!
	u = current_user
	u.focus = params[:focus_text]
	headers["Content-Type"] = "application/json"
	if u.save
		{:status => "success"}.to_json
	else
		{:status => "failure"}.to_json
	end
end

post "/location" do
	authenticate!
	u = current_user
	u.location = params[:location_text]
	headers["Content-Type"] = "application/json"
	if u.save
		{:status => "success"}.to_json
	else
		{:status => "failure"}.to_json
	end
end

post "/notifications/:id/read" do
	authenticate!
	headers["Content-Type"] = "application/json"
	n = Notification.first(:id => params[:id])
	if current_user.notifieds.include? n
		n.read = true
		if n.save
			{:status => "success"}.to_json
		else
			{:status => "failure", :message => "Something unexpected happened. Try again." }.to_json
		end
	else
		{:status => "failure", :message => "Not authorized to modify someone else's notifications."}.to_json
	end
end


post "/scratches/:id/thoughts" do
	authenticate!
	headers["Content-Type"] = "application/json"
	t = Thought.new
	t.mtext = params[:mtext]
	t.scratch_id = params[:id]
	t.user_id = current_user.id
	t.created_at = Time.now
	if t.save
		{:status => "success", :entry => t}.to_json
	else
		{:status => "failure", :entry => t}.to_json
	end
end

get "/thoughts/:ids" do
	authenticate!
	headers["Content-Type"] = "application/json"
	ids = params[:ids].split(",")
	thoughts = Thought.all(:scratch_id => ids)
	thoughts.to_json(:methods => [:user])
end
get "/booms/:ids" do
	authenticate!
	headers["Content-Type"] = "application/json"
	ids = params[:ids].split(",")
	update_scratches = Scratch.all(:id => ids, :boomcount.gt => 0)
	update_scratches.to_json(:methods => [:user])
end


get "/usernames.json" do
	authenticate!
	headers["Content-Type"] = "application/json"
	@users = User.all(:username.like => "%" + params[:val] + "%")
	@users.to_json(:only => [:username])
end
post "/scratch/:id/boom" do
	headers["Content-Type"] = "application/json"
	s = Scratch.get(params[:id])
	s.boomcount = s.boomcount + 1
	if s.save
		{:status => "success", :entry => s}.to_json
	else
		{:status => "success", :entry => s}.to_json
	end
end
post "/git/deploy" do
	u = User.first(:username => "picard")
	s = Scratch.new(:user_id => u.id)
	s.mtext = "New commit, comrades. From: <a href='mailto:#{params[:user]}'>" + params[:user] + "</a> - <a class=\"tldr\">Details</a><p class=\"tldr\">#{params[:git_log]}</p>"
	s.created_at = Time.now
	s.save
end

get "/users/edit" do
	authenticate!
	@bodyclass = "external"
	erb :'users/edit'
end

post "/users/edit" do
	authenticate!
	u = current_user
	u.nickname = params[:nickname]
	u.email = params[:email]
	u.avatar_url = params[:avatar_url]
	if u.save
		flash[:notice] = "Successful profile update!"
		redirect "/"
	else
		flash[:error] = "Try again - your profile couldn't be updated."
		redirect "/users/edit"
	end
end

get "/clients/new" do
	authenticate!
	@bodyclass = "external"
	erb :newclient
end
post "/clients/create" do
	authenticate!
	c = Client.new
	c.clientname = params[:clientname]
	c.email = params[:email]
	c.keywords = params[:keywords]
	if c.save
		flash[:notice] = "New client \"#{c.clientname}\" created successfully."
		redirect "/"
	else
		flash[:error] = "There was an issue saving the client. Try again."
		redirect ="/clients/new"
	end
end