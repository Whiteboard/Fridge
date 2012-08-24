require './preconfig'
require 'sinatra'
require 'json'
require 'hpricot'
require 'open-uri'
require 'data_mapper'
require 'bcrypt'
require 'date'
require 'sinatra/flash'
enable :sessions
set :protection, :except => :frame_options
require './helpers.rb'
DataMapper::Logger.new(STDOUT, :debug)
require './models.rb'
require './users_controller.rb'


get "/" do
	if logged_in?
		authenticate!
		@bodyclass = "fridge"
		@clients = Client.all
		erb :fridge, :layout => :layout
	else
		@bodyclass = "external"
		erb :'users/new', :layout => :layout
	end
end
get "/home.json"  do
	authenticate!
	@users = User.all
	@scratches = Scratch.all(:limit => 20, :order => [:created_at.desc ], :id.gt => params[:later_than] ) || {}
	@notifications = current_user.notifieds(:read => false) || {}
	headers["Content-Type"] = "application/json"
	"[" + @users.to_json(:exclude => [:phash, :salt], :methods => [:scratches]) + "," + @scratches.to_json(:methods => [:thoughts]) + ","+ @notifications.to_json(:methods => [:creator, :scratch] ) + "," + current_user.to_json + "]"
end
get "/scratch/:id" do
	@bodyclass = "single_scratch"
	@scratch = Scratch.get(params[:id])
	erb :scratch
end
post "/scratch" do
	authenticate!
	headers["Content-Type"] = "application/json" #return json from this method
	s = Scratch.new
	s.user_id = current_user.id
	if s.save
		puts "success"
	end
	notifications = [] #holding the notifications to attach to the scratch at the end
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
			n.scratch_id = s.id
			n.mtext = params[:message]
			n.read = false
			puts n.inspect
			if n.save
				puts n.inspect
				notifications.push(n)
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
		t = current_user.timecards.first(:order => [:starttime.desc])
		unless t.nil?
			t.endtime = DateTime.now
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
		if params[:client_id].nil? || params[:client_id].empty?
			keywords.each do |keys|
				keya = keys[1].split ","
				keya.collect! { |k| k.strip.downcase }
				if keya.any? { |w| params[:message].downcase =~ /#{w}/ }
					selectedclient = Client.first(:id => keys[0])
				end
			end
		else
			selectedclient = Client.first(:id => params[:client_id])
		end
		if !selectedclient.nil?
			tc = Timecard.new
			tc.starttime = DateTime.now
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
	s.jsfiddle = jsfiddle || nil
	s.clly = clly || nil
	s.notifications = notifications
	s.mtext = params[:message]
	s.created_at = DateTime.now
	if s.save
		({ :status => "success", :entry => s }).to_json
	else
		({ :status => "failure", :entry => s }).to_json
	end
end

post "/search" do
	headers["Content-Type"] = "application/json"
	status 200
	q = params[:query]
	s = Scratch.all(:conditions => [ "mtext ILIKE ?", "%#{q}%" ], :order => [:created_at.desc ]) + User.all(:conditions => [ "username ILIKE ?", "%#{q}%"]).scratches(:order => [:created_at.desc ])
	u = User.all
	{:scratches => s, :users => u}.to_json
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
	s = Scratch.first(:id => params[:id])
	notifications = s.notifications
	n = Notification.new(:mtext => "<strong>Comment from: #{current_user.username} </strong>- " + params[:mtext],
						:creator_id => current_user.id,
						:scratch_id => s.id,
						:read => false,
						)
	notifications.push(n)
	if n.save
		nfr = Notifier.new(:user_id => s.user.id, :notification_id => n.id)
		if !nfr.save
			({ :status => "failure", :entry => n }).to_json
		end
	end
	if t.mtext.match(/@[a-zA-Z1-9]+/i)
		users = t.mtext.scan(/@[a-zA-Z1-9]+/i)
		users.each do |u|
			u.slice! "@"
			user = User.first(:username => u)
			next if user.nil?
			n = Notification.new
			n.creator_id = current_user.id
			n.scratch_id = s.id
			n.mtext = params[:mtext]
			n.read = false
			notifications.push(n)
			puts n.inspect
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
	s.notifications = notifications
	s.save
	t.scratch_id = params[:id]
	t.user_id = current_user.id
	t.created_at = DateTime.now
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
get "/lazy" do
	headers["Content-Type"] = "application/json"
	lt = params[:lt]
	news = Scratch.all(:id.lt => lt, :limit => 20, :order => [:created_at.desc ])
	users = User.all
	{:news => news, :users => users}.to_json
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
	if s.boomlist.nil? || s.boomlist.empty?
		s.boomlist = "#{current_user.username}"
	else
		unless s.boomlist.include? current_user.username s.boomlist = s.boomlist+ ", #{current_user.username}"
	end
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
	s.created_at = DateTime.now
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
get "/clients/:id" do
	authenticate!
	@client = Client.first(:id => params[:id])
	@bodyclass = "external"
	erb :editclient
end
post "/clients/create" do
	authenticate!
	c = Client.new
	c.clientname = params[:clientname]
	c.slug = slugify(c.clientname)
	c.email = params[:email]
	c.keywords = params[:keywords]
	if c.save
		flash[:notice] = "New client \"#{c.clientname}\" created successfully."
		redirect "/clients"
	else
		flash[:error] = "There was an issue saving the client. Try again."
		redirect ="/clients"
	end
end
post "/clients/edit" do
	authenticate!
	c = Client.first(:id => params[:client_id])
	c.clientname = params[:clientname]
	c.slug = slugify(c.clientname)
	c.email = params[:email]
	c.keywords = params[:keywords]
	if c.save
		flash[:notice] = "Client \"#{c.clientname}\" updated successfully."
		redirect "/clients"
	else
		flash[:error] = "There was an issue saving the client. Try again."
		redirect ="/clients"
	end
end

get "/timecards" do
	@bodyclass = "external"
	@timecards = Timecard.all(:endtime.not => nil)
	@currenttimecards = Timecard.all(:endtime => nil)
	@now = DateTime.now
	@totalhours = 0.0
	@timecards.each do |t|
		@totalhours += timediff(t.starttime,t.endtime)
	end
	erb :timecards
end
get "/timecards/u/:username" do
	@bodyclass = "external"
	u = User.first(:username => params[:username])
	@timecards = Timecard.all(:endtime.not => nil, :user_id => u.id)
	@currenttimecards = Timecard.all(:endtime => nil, :user_id => u.id)
	@now = DateTime.now
	@totalhours = 0.0
	@timecards.each do |t|
		@totalhours += timediff(t.starttime,t.endtime)
	end
	erb :timecards
end
get "/timecards/c/:clientname" do
	@bodyclass = "external"
	c = Client.first(:slug => params[:clientslug])
	@timecards = Timecard.all(:endtime.not => nil, :client_id => c.id)
	@currenttimecards = Timecard.all(:endtime => nil, :client_id => c.id)
	@now = DateTime.now
	@totalhours = 0.0
	@timecards.each do |t|
		@totalhours += timediff(t.starttime,t.endtime)
	end
	erb :timecards
end

get "/clients" do
	@bodyclass = "external"
	@clients = Client.all
	erb :clients
end

get "/users/:username/resetpassword" do
	authenticate!
	if current_user.email.include? "whiteboard"
		@user = User.first(:username => params[:username])
		if @user.nil?
			flash[:warning] = "The user \"#{params[:username]}\" doesn't exist."
			redirect "/"
		else
			@bodyclass = "external"
			erb :resetpassword
		end
	else
		redirect "/"
	end
end
post "/users/:id/resetpassword" do
	user = User.get(params[:id])
	user.salt = BCrypt::Engine.generate_salt
	user.phash = BCrypt::Engine.hash_secret(params[:password], user.salt)
	if user.save
		flash[:notification] = "User's password successfully reset"
		redirect "/"
	else
		flash[:warning] = "Failed to reset the password. Try again?"
		redirect "/"
	end
end