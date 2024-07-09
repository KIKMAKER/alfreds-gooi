Rails.application.routes.draw do
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  post 'snapscan/webhook', to: 'payments#snapscan_webhook'

  resources :webhooks, only: :create
  get 'snapscan/payments', to: 'payments#fetch_snapscan_payments'

  devise_for :users, controllers: { registrations: 'users/registrations', sessions: 'users/sessions' }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  require "sidekiq/web"
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end
  # Defines the root path route ("/")
  root "pages#home"
  get "collection", to: "pages#collection"
  get "vamos", to: "pages#vamos"
  get "kiki", to: "pages#kiki"
  get "welcome", to: "pages#welcome"

  # Defines getting the csv - the form then sends the data to the import_csv route
  resources :collections, only: %i[ edit update] do
    collection do
      get :export_csv, to: 'collections#export_csv'
      get :load_csv, to: 'collections#load_csv'
      post :import_csv, to: 'collections#import_csv'
    end
  end

  # resources create all the CRUD routes for a model - here I am nesting new and create collection methods under subscriptions
  resources :subscriptions do

    resources :invoices, only: %i[show]
    resources :collections, only: %i[index new create]
    # - here I am creating /subscriptions/today
    collection do
      get :today
      get :tomorrow
      get :yesterday
    end
  end

  get '/today/notes', to: 'subscriptions#today_notes', as: :today_notes

  # I want get and patch requests on these custom drivers_day routes
  # member routes are created with /drivers_day/:id/custom_route
  # these routes (the get and the patch) allow for form input to the instance of drivers day at each url
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
  resources :collections, only: %i[edit update destroy]
end
