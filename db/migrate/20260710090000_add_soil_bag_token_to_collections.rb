class AddSoilBagTokenToCollections < ActiveRecord::Migration[7.1]
  def change
    # Short, shareable claim code for the promotional soil bag link. Minted
    # lazily — only collections we actually send a link for get a token — so the
    # index is partial and stays small.
    add_column :collections, :soil_bag_token, :string

    add_index :collections, :soil_bag_token,
              unique: true,
              where: "soil_bag_token IS NOT NULL",
              name: "index_collections_on_soil_bag_token"
  end
end
