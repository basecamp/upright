module CurrentUserHelper
  def acting_as(name, email: "user@example.com")
    Upright::Current.user = Upright::User.new(name: name, email: email)
  end
end
