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
	headers["Content-Type"] = "application/json"
	"[" + @users.to_json(:exclude => [:phash, :salt], :methods => [:scratches]) + "," + @scratches.to_json + "]"
end

post "/scratch" do
	authenticate!
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
	s = Scratch.new
	s.jsfiddle = jsfiddle || nil
	s.clly = clly || nil
	s.mtext = params[:message]
	s.created_at = Time.now
	s.user_id = current_user.id
	puts s.inspect
	headers["Content-Type"] = "application/json"
	puts s.inspect
	if s.save
		puts s.inspect
		({ :status => "success", :entry => s }).to_json
	else
		puts s.inspect
		({ :status => "failure", :entry => s }).to_json
	end
end

post "/status" do
	authenticate!
	u = current_user
	u.status = params[:status_text]
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
		{:status => "failuare"}.to_json
	end
end