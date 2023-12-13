class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def home
    @collections = Collection.where(collection_day: Date.today.strftime("%A")).order(:collection_id)
    @skip_collections = Collection.where(collection_day: Date.today.strftime("%A")).where(skip: true).order(:collection_id)

  end
end
