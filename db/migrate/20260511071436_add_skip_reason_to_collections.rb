class AddSkipReasonToCollections < ActiveRecord::Migration[7.2]
  def change
    add_column :collections, :skip_reason, :string
  end
end
