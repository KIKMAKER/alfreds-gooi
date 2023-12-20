Rails.application.routes.draw do

  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "pages#home"

  # Defines getting the csv - the form then sends the data to the import_csv route
  resources :collections, only: %i[ edit update] do
    collection do
      get :export, to: 'collections#export'
      get :get_csv, to: 'collections#get_csv'
      post :import_csv, to: 'collections#import_csv'
    end
  end

  # resources create all the CRUD routes for a model - here I am nesting new and create collection methods under subscriptions
  resources :subscriptions do
    resources :collections, only: %i[new create]
    # - here I am creating /subscriptions/today
    collection do
      get :today
    end
  end

  resources :drivers_days do
    resources :collections, only: %i[index]
    member do
      get :start
      patch :start
      get :drop_off
      patch :drop_off
      get :end
      patch :end
    end
  end
end
