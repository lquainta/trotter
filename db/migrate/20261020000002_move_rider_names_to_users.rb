# Checkpoint 1 stored each ride's rider as a plain rider_name. Now that riders
# have accounts, give every existing rider name an account (with the sample
# password, like the seeds) and point its rides at it.
class MoveRiderNamesToUsers < ActiveRecord::Migration[8.1]
  def up
    add_reference :activities, :user, foreign_key: true

    password_digest = BCrypt::Password.create("password123")
    select_values("SELECT DISTINCT rider_name FROM activities").each do |rider_name|
      username = rider_name.strip.downcase
      execute <<~SQL
        INSERT OR IGNORE INTO users (username, password_digest, created_at, updated_at)
        VALUES (#{quote(username)}, #{quote(password_digest)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      execute <<~SQL
        UPDATE activities SET user_id = (SELECT id FROM users WHERE username = #{quote(username)})
        WHERE rider_name = #{quote(rider_name)}
      SQL
    end

    change_column_null :activities, :user_id, false
    remove_column :activities, :rider_name
  end

  def down
    add_column :activities, :rider_name, :string
    execute "UPDATE activities SET rider_name = (SELECT username FROM users WHERE users.id = activities.user_id)"
    change_column_null :activities, :rider_name, false
    remove_reference :activities, :user, foreign_key: true
  end
end
