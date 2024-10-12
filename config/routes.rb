Rails.application.routes.draw do

  # admin
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  post 'snapscan/webhook', to: 'payments#snapscan_webhook'

  # payments
  resources :webhooks, only: :create
  get 'snapscan/payments', to: 'payments#fetch_snapscan_payments'

  # users
  devise_for :users, controllers: { registrations: 'users/registrations', sessions: 'users/sessions' }

  # sidekiq
  require "sidekiq/web"
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end


  patch 'optimise_route', to: 'collections#optimise_route'
  post "perform_create_collections", to: "collections#perform_create_collections"
  # Defines getting the csv - the form then sends the data to the import_csv route
  resources :collections, only: [:edit, :update, :destroy] do
    collection do
      patch :skip_today
      get :export_csv
      get :load_csv
      post :import_csv
    end
  end

  # resources create all the CRUD routes for a model - here I am nesting new and create collection methods under subscriptions
  resources :subscriptions do

    resources :invoices, only: %i[new create show]
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
      get :todays_collections
    end
  end

    # static pages
    root "pages#home"
    get "manage", to: "pages#manage"
    get "vamos", to: "pages#vamos"
    get "kiki", to: "pages#kiki"
    get "welcome", to: "pages#welcome"

end
