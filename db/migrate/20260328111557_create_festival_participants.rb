class CreateFestivalParticipants < ActiveRecord::Migration[7.1]
  def change
    create_table :festival_participants do |t|
      t.references :festival_event, null: false, foreign_key: true
      t.string :name, null: false
      t.string :pin, null: false

      t.timestamps
    end
  end
end
