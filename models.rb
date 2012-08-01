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
	property :status,		Text
	property :location,		Text
	property :logged_in,	Boolean
	property :created_at, 	DateTime #signup date

	has n, :scratches

	validates_presence_of :username
	validates_presence_of :email

end

class Scratch
	include DataMapper::Resource

	property :id,			Serial
	property :mtext, 		String, :length => 250
	property :created_at, 	DateTime
	property :clly,			String, :length => 250
	property :jsfiddle,		String, :length => 250

	belongs_to :user
end

DataMapper.auto_upgrade!