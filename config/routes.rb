Rails.application.routes.draw do

  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "pages#home"

  # Defines getting the csv - the form then sends the data to the import_csv route
  get 'get_csv', to: 'collections#get_csv'
  post 'import_csv', to: 'collections#import_csv'

  # resources create all the CRUD routes for a model - here I am nesting new and create collection methods under subscriptions
  resources :subscriptions do
    resources :collections, only: %i[new create]
    # - here I am creating /subscriptions/today
    collection do
      get :today
    end
  end

  # since I'm not doing usual CRUD for drivers day, I have 'custom' routes to create a screen for alfred to start and end his day
  get 'drivers_days/start', to: 'drivers_days#start'
  post 'drivers_days/start', to: 'drivers_days#start'
  get 'drivers_days/end', to: 'drivers_days#end'
  patch 'drivers_days/end', to: 'drivers_days#end'

  resources :collections, only: %i[edit update]
end
