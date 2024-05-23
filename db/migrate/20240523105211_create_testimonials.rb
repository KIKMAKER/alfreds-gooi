class CreateTestimonials < ActiveRecord::Migration[7.0]
  def change
    create_table :testimonials do |t|
      t.string :content
      t.integer :ranking
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
