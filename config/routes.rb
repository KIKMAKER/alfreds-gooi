Rails.application.routes.draw do
  # mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  # admin
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  post 'snapscan/webhook', to: 'payments#snapscan_webhook'

  # payments
  # resources :webhooks, only: :create
  get 'snapscan/payments', to: 'payments#fetch_snapscan_payments'
  resources :payments, only: :index

  # users
  devise_for :users, controllers: { registrations: 'users/registrations', sessions: 'users/sessions' }

  # sidekiq
  require "sidekiq/web"
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end


  patch 'optimise_route', to: 'collections#optimise_route'
  post "perform_create_today_collections", to: "collections#perform_create_today_collections"
  post "perform_create_tomorrow_collections", to: "collections#perform_create_tomorrow_collections"
  # Defines getting the csv - the form then sends the data to the import_csv route
  resources :collections, only: [:edit, :update, :destroy] do
    member do
      post :add_bags
      post :remove_bags
      post :add_customer_note
      put :update_position
    end
    collection do
      get :this_week
      patch :skip_today
      get :export_csv
      get :load_csv
      post :import_csv
    end
  end

  # get 'subscriptions/update_sub_end_date', to: 'subscriptions#update_sub_end_date'
  # post 'subscriptions/import_csv', to: 'subscriptions#import_csv'

  resources :invoices, only: %i[ index new create show]
  # resources create all the CRUD routes for a model - here I am nesting new and create collection methods under subscriptions
  resources :subscriptions do
    resources :collections, only: %i[index new create]
    # - here I am creating /subscriptions/today
    collection do
      get :today
      get :tomorrow
      get :yesterday
      get :export
      get :update_end_date
      post :import_csv
    end
    member do
      get :welcome_invoice
      post :pause
      # route to unpause subscription
      post :unpause
      # route to clear holiday
      post :clear_holiday
      patch :holiday_dates
    end
  end
  get '/today/notes', to: 'subscriptions#today_notes', as: :today_notes

  # I want get and patch requests on these custom drivers_day routes
  # member routes are created with /drivers_day/:id/custom_route
  # these routes (the get and the patch) allow for form input to the instance of drivers day at each url
  resources :drivers_days do
    resources :collections, only: %i[index] do
      collection do
        post :reset_order
      end
    end
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

  resources :products, only: [:index, :new, :create]

    # static pages
    root "pages#home"
    get "manage", to: "pages#manage"
    get "vamos", to: "pages#vamos"
    get "welcome", to: "pages#welcome"
    get "story", to: "pages#story"
    get "today", to: "pages#today"

end
