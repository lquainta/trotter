class SettingsController < ApplicationController
  def show
  end

  def update
    if Current.user.update(params.expect(user: [ :theme, :distance_unit ]))
      redirect_to settings_path, notice: "Settings saved."
    else
      redirect_to settings_path, alert: Current.user.errors.full_messages.to_sentence
    end
  end
end
