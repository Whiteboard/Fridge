DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/fridge')

class User
	include DataMapper::Resource

	property :id,         	Serial    # An auto-increment integer key
	property :username, 	String, :format => /\S/
	property :email, 		String, :format => /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i
	property :nickname,		String
	property :phash,		String, :length => 120 # password hash
	property :salt,			String, :length => 120 # pass salt
	property :avatar_url,	String, :length => 120, :format => /(?:http|https):\/\/[a-z0-9]+(?:[\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(?:(?::[0-9]{1,5})?\/[^\s]*)?/ix, :required => true
	property :focus,		Text
	property :location,		Text
	property :logged_in,	Boolean
	property :created_at, 	DateTime #signup date

	has n, :scratches
	has n, :notifications, :child_key => [ :creator_id ]
	has n, :notifiers
  	has n, :notifieds, 'Notification', :through => :notifiers, :via => :notification
  	has n, :thoughts
  	has n, :timecards

	validates_presence_of :username
	validates_presence_of :email
	validates_presence_of :avatar_url

end

class Scratch
	include DataMapper::Resource

	property :id,			Serial
	property :mtext, 		String, :length => 1000
	property :created_at, 	DateTime
	property :clly,			String, :length => 350
	property :jsfiddle,		String, :length => 350
	property :boomcount,	Integer, :default => 0

	has n, :thoughts
	has n, :notifications
	belongs_to :user
end

class Thought
	include DataMapper::Resource

	property :id,			Serial
	property :mtext,		String, :length => 350
	property :created_at,	DateTime
	belongs_to :scratch
	belongs_to :user
end

class Notification
	include DataMapper::Resource
	property :read,			Boolean
	property :mtext,		String, :length => 350
	property :id,			Serial

	has n, :notifiers
	has n, :users, 'User', :through => :notifiers, :via => :user
	belongs_to :creator, 'User'
	belongs_to :scratch
end

class Notifier
  include DataMapper::Resource

  belongs_to :user, :key => true
  belongs_to :notification, :key => true
end

class Client
	include DataMapper::Resource
	property :id,			Serial
	property :clientname,	String, :length => 100
	property :email,		String, :length => 100
	property :keywords,		String, :length => 100
	property :created_at, 	DateTime
	property :slug,			String, :length => 100

	has n, :timecards
end

class Timecard
	include DataMapper::Resource
	property :id,			Serial
	property :starttime,		DateTime
	property :endtime,			DateTime
	property :description,	String, :length => 1000
	belongs_to :user
	belongs_to :client
end



DataMapper.auto_upgrade!