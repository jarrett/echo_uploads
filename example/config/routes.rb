Example::Application.routes.draw do
  root   to: 'images#index', as: 'root'
  get    'images/new', to: 'images#new', as: 'new_image'
  post   'images', to: 'images#create', as: 'images'
  get    'images/:id', to: 'images#show', as: 'image'
  delete 'images/:id', to: 'images#destroy'
  get    'images/:id/edit', to: 'images#edit', as: 'edit_image'
  patch  'images/:id', to: 'images#update'
end
