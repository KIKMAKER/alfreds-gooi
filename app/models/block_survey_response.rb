class BlockSurveyResponse < ApplicationRecord
  belongs_to :block

  validates :has_compost_bin,  inclusion: { in: [true, false] }
  validates :wants_to_buy_bin, inclusion: { in: [true, false] }
  validates :wants_phase_one,  inclusion: { in: [true, false] }
end
