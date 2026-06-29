module RailsEnvHelper
  def with_rails_env(name)
    Rails.stubs(:env).returns(ActiveSupport::EnvironmentInquirer.new(name))
    yield
  ensure
    Rails.unstub(:env)
  end
end
