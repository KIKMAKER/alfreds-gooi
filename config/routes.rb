Rails.application.routes.draw do

  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "pages#home"

  get 'get_csv', to: 'collections#get_csv'
  post 'import_csv', to: 'collections#import_csv'

  resources :subscriptions do
    resources :collections, only: %i[new create]
    collection do
      get :today
    end
  end

  get 'drivers_logs/start', to: 'drivers_logs#start'
  post 'drivers_logs/start', to: 'drivers_logs#start'
  get 'drivers_logs/end', to: 'drivers_logs#end'
  patch 'drivers_logs/end', to: 'drivers_logs#end'

  resources :collections, only: %i[edit update]
end
