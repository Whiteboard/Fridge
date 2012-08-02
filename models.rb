DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/fridge')

class User
	include DataMapper::Resource

	property :id,         	Serial    # An auto-increment integer key
	property :username, 	String
	property :email, 		String
	property :nickname,		String
	property :phash,		String, :length => 120 # password hash
	property :salt,			String, :length => 120 # pass salt
	property :avatar_url,	String, :length => 120 # password hash
	property :focus,		Text
	property :location,		Text
	property :logged_in,	Boolean
	property :created_at, 	DateTime #signup date

	has n, :scratches
	has n, :notifications, :child_key => [ :creator_id ]
	has n, :notifiers
  	has n, :notifieds, 'Notification', :through => :notifiers, :via => :notification
  	has n, :thoughts

	validates_presence_of :username
	validates_presence_of :email
	validates_presence_of :avatar_url

end

class Scratch
	include DataMapper::Resource

	property :id,			Serial
	property :mtext, 		String, :length => 350
	property :created_at, 	DateTime
	property :clly,			String, :length => 350
	property :jsfiddle,		String, :length => 350

	has n, :thoughts
	belongs_to :user
end

class Thought
	include DataMapper::Resource

	property :id,			Serial
	property :mtext,		String, :length => 350
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
end

class Notifier
  include DataMapper::Resource

  belongs_to :user, :key => true
  belongs_to :notification, :key => true
end


DataMapper.auto_upgrade!