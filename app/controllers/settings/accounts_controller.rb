class Settings::AccountsController < ApplicationController
  def destroy
    user = Current.user

    if user.authenticate(params.expect(user: [ :password_challenge ])[:password_challenge])
      user.destroy! # Also deletes the rider's sessions and rides
      cookies.delete(:session_id)
      redirect_to root_path, status: :see_other, notice: "Your account and rides have been deleted."
    else
      redirect_to settings_path, status: :see_other, alert: "That password isn't right, so your account wasn't deleted."
    end
  end
end
