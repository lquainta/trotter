class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :password_digest, null: false
      t.string :theme, null: false, default: "system"
      t.string :distance_unit, null: false, default: "mi"

      t.timestamps
    end
    add_index :users, :username, unique: true
  end
end
