class FillUp < ApplicationRecord
  belongs_to :user
  belongs_to :car

  # Custom methods
  # a method that calculates the distance travelled since last fillup

  def distance_since_last_fill
    last_fillup = FillUp.all[-2]
    return 0 unless last_fillup

    odometer - last_fillup.odometer
  end

  def fuel_efficiency
    distance_since_last_fill / volume
  end

  def cost_per_unit
    cost / volume

  end
end
