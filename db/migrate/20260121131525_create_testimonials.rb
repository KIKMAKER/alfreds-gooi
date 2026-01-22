class CreateTestimonials < ActiveRecord::Migration[7.2]
  def change
    create_table :testimonials do |t|
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.boolean :public, default: false, null: false

      t.timestamps
    end
  end
end
