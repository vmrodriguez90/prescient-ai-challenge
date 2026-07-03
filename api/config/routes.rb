Rails.application.routes.draw do
  get '/health', to: proc { [200, { 'Content-Type' => 'application/json' }, ['{"status":"ok"}']] }

  namespace :api do
    namespace :v1 do
      get 'campaigns/brands',          to: 'campaigns#brands'
      get 'campaigns/platforms',       to: 'campaigns#platforms'
      get 'campaigns/exclusion_brands', to: 'campaigns#exclusion_brands'
      get 'campaigns',           to: 'campaigns#index'

    end

    namespace :v2 do
      resources :brands, param: :brand_id, only: [:index, :show, :create, :update, :destroy]
    end
  end
end
