class CreateBlockSurveyResponses < ActiveRecord::Migration[7.2]
  def change
    create_table :block_survey_responses do |t|
      t.references :block, null: false, foreign_key: true

      t.boolean :has_compost_bin,  null: false, default: false
      t.boolean :wants_to_buy_bin, null: false, default: false
      t.boolean :wants_phase_one,  null: false, default: false

      t.string :respondent_name
      t.string :unit_number

      t.timestamps
    end
  end
end
