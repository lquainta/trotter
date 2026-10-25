class Settings::PasswordsController < ApplicationController
  def update
    user = Current.user
    # password_challenge (the current password) is checked by has_secure_password.
    # Default it to "" so a request that leaves it out fails instead of skipping the check.
    user.assign_attributes(params.expect(user: [ :password_challenge, :password, :password_confirmation ]).with_defaults(password_challenge: ""))

    if user.save(context: :password_change)
      user.sessions.excluding(Current.session).destroy_all # Log out other devices
      redirect_to settings_path, notice: "Password changed."
    else
      render "settings/show", status: :unprocessable_content
    end
  end
end
