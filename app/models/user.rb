class User < ActiveRecord::Base

  has_many :votes
  has_many :pins
  has_many :comments

  #Lists all topics the user has voted on
  has_many :voted_pins, :through => :votes, :source => :pin

  #Lists all votes for the users topics
  has_many :pin_votes, :through => :pins, :source => :votes

  TEMP_EMAIL_PREFIX = 'change@me'
  TEMP_EMAIL_REGEX = /\Achange@me/

  # :lockable, :timeoutable
  devise :database_authenticatable, :registerable, :confirmable,
    :recoverable, :rememberable, :trackable, :validatable, :omniauthable

  validates_format_of :email, :without => TEMP_EMAIL_REGEX, on: :update

  def self.find_for_oauth(auth, signed_in_resource = nil)

    # Get the identity and user if they exist
    identity = Identity.find_for_oauth(auth)

    # If a signed_in_resource is provided it always overrides the existing user
    # to prevent the identity being locked with accidentally created accounts.
    # Note that this may leave zombie accounts (with no associated identity) which
    # can be cleaned up at a later date.
    user = signed_in_resource ? signed_in_resource : identity.user

    # Create the user if needed
    if user.nil?

      # Get the existing user by email if the provider gives us a verified email.
      # If no verified email was provided we assign a temporary email and ask the
      # user to verify it on the next step via UsersController.finish_signup
      email = auth.info.email
      user = User.where(:email => email).first if email
binding.pry
      # Create the user if it's a new registration
      if user.nil?
        user = User.new(
          # name: auth.extra.raw_info.name,
          username: auth.info.nickname || auth.uid,
          email: email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
          password: Devise.friendly_token[0,20]
        )
        user.skip_confirmation!
        user.save!
      end
    end

    # Associate the identity with the user if needed
    if identity.user != user
      identity.user = user
      identity.save!
    end
    user
  end

  def likes? pin, user
    pin = Vote.where(pin_id: pin.id).where(user_id: user.id)
    if pin.empty?
      false
    else
      true
    end
  end

  def email_verified?
    self.email && self.email !~ TEMP_EMAIL_REGEX
  end
end
