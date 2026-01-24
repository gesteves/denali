module AuthenticationHelpers
  def sign_in(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  def sign_in_as(user)
    # For request specs, stub current_user directly
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :controller
end
