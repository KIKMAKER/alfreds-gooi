class AddLaunchDateToSuburbs < ActiveRecord::Migration[7.2]
  def change
    add_column :suburbs, :launch_date, :date
  end
end
