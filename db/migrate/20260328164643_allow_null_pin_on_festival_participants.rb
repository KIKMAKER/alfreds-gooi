class AllowNullPinOnFestivalParticipants < ActiveRecord::Migration[7.1]
  def change
    change_column_null :festival_participants, :pin, true
  end
end
