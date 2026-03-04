Rails.application.routes.draw do
  # Shop and Orders
  get "shop", to: "shop#index", as: :shop_index
  post "orders/add_item", to: "orders#add_item", as: :add_to_order
  delete "orders/remove_item/:id", to: "orders#remove_item", as: :remove_from_order
  get "orders/:id/checkout", to: "orders#checkout", as: :checkout_order
  post "orders/:id/attach_to_collection", to: "orders#attach_to_collection", as: :attach_to_collection_order
  post "orders/:id/mark_delivered", to: "orders#mark_delivered", as: :mark_delivered_order
  namespace :admin do
    resources :bulk_messages, only: [:index]
    resources :logistics, only: :index do
      collection do
        get :customer_map_data
      end
    end
    resources :collections, only: [:index, :edit, :update, :destroy] do
      collection do
        get :customer_map_data
      end
    end
    resources :discount_codes, only: [:index, :new, :create, :show]
    resources :products, only: [:index, :new, :create, :edit, :update]
    resources :drop_off_sites do
      member do
        post :create_event
      end
      collection do
        post :create_next_week_events
      end
    end
    resources :users, only: [:index, :new, :create, :edit, :update, :show] do
      post :renew_last_subscription, on: :member
      post :fix_subscription_boundaries, on: :member
      get :collections, on: :member
    end
    resources :whatsapp_messages, only: [:index] do
      collection do
        post :trigger_reminders
      end
    end

    # Financial Dashboard
    get 'financials', to: 'financials#dashboard', as: :financials
    get 'financials/chart_data', to: 'financials#chart_data', as: :chart_data_financials

    # Analytics Dashboard (Blazer)
    authenticate :user, ->(user) { user.admin? } do
      mount Blazer::Engine, at: "analytics"
    end

    resources :expenses do
      member do
        post :verify
      end
      collection do
        get :import
        post :parse_csv
        post :confirm_import
      end
    end
  end

  post 'snapscan/webhook', to: 'payments#snapscan_webhook'

  # Twilio WhatsApp webhook
  post 'twilio/whatsapp', to: 'twilio_webhooks#whatsapp_reply'

  # payments
  # resources :webhooks, only: :create
  get 'snapscan/payments', to: 'payments#fetch_snapscan_payments'
  resources :payments, only: :index

  # users
  # Multi-step signup flow
  get 'signup/account', to: 'signups#new_account', as: :new_account_signup
  post 'signup/account', to: 'signups#create_account', as: :create_account_signup
  get 'signup/subscription', to: 'signups#new_subscription_details', as: :new_subscription_details
  post 'signup/subscription', to: 'signups#create_subscription', as: :create_subscription

  # Commercial inquiry flow
  get 'commercial/account', to: 'commercial_inquiries#new_account', as: :new_commercial_inquiry_account
  post 'commercial/account', to: 'commercial_inquiries#create_account', as: :create_commercial_inquiry_account
  get 'commercial/details', to: 'commercial_inquiries#new_details', as: :new_commercial_inquiry_details
  post 'commercial/inquiries', to: 'commercial_inquiries#create', as: :create_commercial_inquiries
  get 'commercial/confirmation', to: 'commercial_inquiries#confirmation', as: :commercial_inquiry_confirmation

  devise_for :users, controllers: { registrations: 'users/registrations', sessions: 'users/sessions' }

  # drop-off site managers
  resources :drop_off_site_managers, only: [:index, :show, :edit, :update]

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
      patch :issued_bags, to: "invoices#issued_bags"
      get :send_email, to: "invoices#send_email"
      post :apply_discount_code
      get :pdf
    end
    collection do
      get "bags/:bags", to: "invoices#bags", as: :bag

    end
  end

  resources :statements, only: [:show] do
    member do
      post :send_email
    end
  end

  resources :quotations do
    member do
      get :send_email
      get :pdf
    end
  end

  # resources create all the CRUD routes for a model - here I am nesting new and create collection methods under subscriptions
  resources :subscriptions do
    resource :business_profile, only: [:new, :create, :edit, :update]
    resources :collections, only: %i[new create]
    resources :contacts do
      member do
        post :toggle_whatsapp
      end
    end
    # - here I am creating /subscriptions/today
    collection do
      get :add_locations
      post :create_locations
      get :today
      get :recently_lapsed
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
      post :reassign_collections
      post :collect_courtesy
    end
  end
  get '/today/notes', to: 'subscriptions#today_notes', as: :today_notes

  # I want get and patch requests on these custom drivers_day routes
  # member routes are created with /drivers_day/:id/custom_route
  # these routes (the get and the patch) allow for form input to the instance of drivers day at each url
  resources :drivers_days do
    collection do
      get :route
      get :yearly_snapshot
    end
    member do
      get :vamos
      get :complete
      get :start
      patch :start
      get :end
      patch :end
      get :collections
      get :snapshot
    end
    resources :collections, only: [:index] do
      collection do
        post :reset_order
      end
    end
    resources :buckets, only: [:index, :create, :destroy]
    resources :drop_off_events, only: [:index, :show, :edit, :update] do
      member do
        post :complete
        post :record_arrival
        post :record_departure
      end
      resources :buckets, only: [:create, :destroy], controller: 'drop_off_events/buckets'
    end
    post 'set_current_drop_off/:id', to: 'drop_off_events#set_current_drop_off', as: :set_current_drop_off
  end

  resources :collections do
    member do
      get :issue_bags
    end
  end

  resources :interests, only: :create

  # testimonials
  resources :testimonials, only: [:new, :create, :index, :destroy, :update]

  # customers
  get "my_subscriptions", to: "customers#subscriptions"
  get "manage", to: "customers#manage"
  get "account", to: "customers#account"
  get "collections_history", to: "customers#collections_history"
  get "skipme", to: "customers#skipme"
  get "welcome", to: "customers#welcome"
  get "referrals", to: "customers#referrals"
  get "my_stats", to: "customers#my_stats"

  # static pages
  root "pages#home"
  get "about", to: "pages#about"
  get "story", to: "pages#story"

  # farms (public-facing drop-off sites)
  resources :farms, only: [:index, :show], param: :slug



  # Block WordPress scanning bots
  match "/wp-includes/*path", to: ->(_) { [404, {}, ["Not Found"]] }, via: :all
  match "/blog/wp-includes/*path", to: ->(_) { [404, {}, ["Not Found"]] }, via: :all
  match "/web/wp-includes/*path", to: ->(_) { [404, {}, ["Not Found"]] }, via: :all

  # Render dynamic PWA files from app/views/pwa/*
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

end
