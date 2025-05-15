Rails.application.routes.draw do
  namespace :admin do
    resources :discount_codes, only: [:index, :new, :create, :show]
    resources :users, only: [:index, :edit, :update]
  end

  post 'snapscan/webhook', to: 'payments#snapscan_webhook'

  # payments
  # resources :webhooks, only: :create
  get 'snapscan/payments', to: 'payments#fetch_snapscan_payments'
  resources :payments, only: :index

  # users
  devise_for :users, controllers: { registrations: 'users/registrations', sessions: 'users/sessions' }

  patch 'optimise_route', to: 'collections#optimise_route'
  post "perform_create_today_collections", to: "collections#perform_create_today_collections"
  post "perform_create_next_week_collections", to: "collections#perform_create_next_week_collections"
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

  resources :invoices do
    member do
      get :paid
    end
    collection do
      get "bags/:bags", to: "invoices#bags", as: :bag
    end
  end
  # resources create all the CRUD routes for a model - here I am nesting new and create collection methods under subscriptions
  resources :subscriptions do
    resources :collections, only: %i[new create]
    # - here I am creating /subscriptions/today
    collection do
      get :today
      get :export
      get :update_end_date
      post :import_csv
      get :pending
      get :all
      get :paused
      get :completed
      get :legacy
    end
    member do
      get :want_bags
      get :collections
      get :welcome
      get :welcome_invoice
      post :pause
      # route to unpause subscription
      post :unpause
      # route to clear holiday
      post :clear_holiday
      patch :holiday_dates
      get :complete
      get :reassign_collections
    end
  end
  get '/today/notes', to: 'subscriptions#today_notes', as: :today_notes

  # I want get and patch requests on these custom drivers_day routes
  # member routes are created with /drivers_day/:id/custom_route
  # these routes (the get and the patch) allow for form input to the instance of drivers day at each url
  resources :drivers_days do
    collection do
      get :route
    end
    resources :collections, only: [:index] do
      collection do
        post :reset_order
      end
    end
    member do
      get :vamos
      get :start
      patch :start
      get :drop_off
      patch :drop_off
      get :end
      patch :end
      get :collections
    end

  end

  resources :products, only: [:index, :new, :create]

  # static pages
  root "pages#home"
  get "manage", to: "pages#manage"

  get "welcome", to: "pages#welcome"
  get "referrals", to: "pages#referrals"
  get "story", to: "pages#story"



  # Block WordPress scanning bots
  match "/wp-includes/*path", to: ->(_) { [404, {}, ["Not Found"]] }, via: :all
  match "/blog/wp-includes/*path", to: ->(_) { [404, {}, ["Not Found"]] }, via: :all
  match "/web/wp-includes/*path", to: ->(_) { [404, {}, ["Not Found"]] }, via: :all

  # Render dynamic PWA files from app/views/pwa/*
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

end
