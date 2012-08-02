require 'sinatra'
require 'json'
require 'hpricot'
require 'open-uri'
require 'data_mapper'
require 'bcrypt'
require 'sinatra/flash'
enable :sessions
require './helpers.rb'
DataMapper::Logger.new(STDOUT, :debug)
require './models.rb'
require './users_controller.rb'

get "/" do
	if logged_in?
		erb :fridge, :layout => :layout
	else
		erb :'users/new', :layout => :layout
	end
end

get "/home.json"  do
	@users = User.all
	@scratches = Scratch.all(:limit => 20, :order => [:created_at.desc ] ) || {}
	@notifications = current_user.notifications
	headers["Content-Type"] = "application/json"
	"[" + @users.to_json(:exclude => [:phash, :salt], :methods => [:scratches]) + "," + @scratches.to_json + ","+ @notifications.to_json(:methods => [:creator] ) + "," + current_user.to_json + "]"
end

post "/scratch" do
	authenticate!
	headers["Content-Type"] = "application/json" #return json from this method
	if params[:message].include? "cl.ly"
		m = params[:message]
		url = m.match(/https?:\/\/[\S]+\.[a-zA-Z]{2,4}\.?[a-zA-Z]?{2,4}[\/\?#]?([\S]+)?/i)[0]
		doc = Hpricot(open(url))
		puts url
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
			u.delete! "@"
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
				if nfr.save
					puts "saved a notification!"
					return ({ :status => "success", :entry => n }).to_json
				else
					return ({ :status => "failure", :entry => n }).to_json
				end
			else
				return ({ :status => "failure", :entry => n }).to_json
			end
		end
	end
	if params[:message].match(/#location:\s/i)
		location = params[:message].delete "#location: "
		u = current_user
		u.location = location
		if !u.save
			({ :status => "failure", :entry => location }).to_json
		end
	end
	s = Scratch.new
	s.jsfiddle = jsfiddle || nil
	s.clly = clly || nil
	s.mtext = params[:message]
	s.created_at = Time.now
	s.user_id = current_user.id
	puts s.inspect
	puts s.inspect
	if s.save
		puts s.inspect
		({ :status => "success", :entry => s }).to_json
	else
		puts s.inspect
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
		puts u.inspect
		{:status => "success"}.to_json
	else
		{:status => "failure"}.to_json
	end
end

post "/notifications/:id/read" do
	authenticate!
	headers["Content-Type"] = "application/json"
	n = Notification.first(:id => params[:id])
	if current_user.notifications.include? n
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