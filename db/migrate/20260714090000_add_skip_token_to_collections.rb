class AddSkipTokenToCollections < ActiveRecord::Migration[7.1]
  def change
    # Short, shareable code for the tokenised "skip my next collection" link.
    # Minted lazily — only collections we send a skip link for get a token — so
    # the index is partial and stays small. Mirrors soil_bag_token.
    add_column :collections, :skip_token, :string

    add_index :collections, :skip_token,
              unique: true,
              where: "skip_token IS NOT NULL",
              name: "index_collections_on_skip_token"
  end
end
