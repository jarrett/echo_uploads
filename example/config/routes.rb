Example::Application.routes.draw do
  root   to: 'widgets#index', as: 'root'
  get    'widgets/new', to: 'widgets#new', as: 'new_widget'
  post   'widgets', to: 'widgets#create', as: 'widgets'
  get    'widgets/:id/thumbnail', to: 'widgets#thumbnail', as: 'widget_thumbnail'
  get    'widgets/:id/manual', to: 'widgets#manual', as: 'widget_manual'
  delete 'widgets/:id', to: 'widgets#destroy', as: 'widget'
  get    'widgets/:id/edit', to: 'widgets#edit', as: 'edit_widget'
  patch  'widgets/:id', to: 'widgets#update'
end
