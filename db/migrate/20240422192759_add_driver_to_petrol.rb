class AddDriverToPetrol < ActiveRecord::Migration[7.0]
  def change
    add_reference :petrols, :user, null: false, foreign_key: true
  end
end
