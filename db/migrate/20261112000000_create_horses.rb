class CreateHorses < ActiveRecord::Migration[8.1]
  def change
    create_table :horses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :breed
      t.string :color
      t.integer :birth_year
      t.text :notes
      t.timestamps
    end

    # Deleting a horse keeps its rides; they just no longer list a horse.
    add_reference :activities, :horse, foreign_key: { on_delete: :nullify }
  end
end
