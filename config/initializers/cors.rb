Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://www.gooi.me"
    resource "/assets/*",
      headers: :any,
      methods: [:get, :options],
      max_age: 600
  end
end
