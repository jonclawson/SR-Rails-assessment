module AuthenticationHelper
  # Helper for system tests - logs in a user through the UI
  def sign_in_as(user, password: "password123")
    visit root_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button "Sign in"
  end

  # Helper for request/controller tests - sets up session
  def sign_in(user)
    post sessions_path, params: { email_address: user.email_address, password: user.password }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :system
  config.include AuthenticationHelper, type: :request
end
