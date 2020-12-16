run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"


say "starting template creation: Rails 6, Tailwind 2, Devise", :green

inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'autoprefixer-rails'
    gem 'devise'
    gem 'devise-i18n'
    gem 'font-awesome-sass'
    gem 'friendly_id', '~> 5.4.0'
    gem 'rails-i18n', '~> 6.0.0'
    gem 'route_translator'
  RUBY
end

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'dotenv-rails'
  RUBY
end

gsub_file('Gemfile', /# gem 'redis'/, "gem 'redis'")

def add_tailwind
  run "yarn remove @rails/webpacker"
  run "yarn add @rails/webpacker"

  gsub_file('Gemfile', /gem 'webpacker', '~> 4.0'/, "gem 'webpacker', github: 'rails/webpacker'")

  run "yarn add tailwindcss@latest postcss@latest autoprefixer@latest"
  run 'yarn add @tailwindcss/forms @tailwindcss/typography @tailwindcss/aspect-ratio'

  run "mkdir -p app/javascript/stylesheets"
  run "touch app/javascript/stylesheets/application.scss"
  inject_into_file "app/javascript/stylesheets/application.scss" do <<~EOF
      @import 'tailwindcss/base';
      @import 'tailwindcss/components';
      @import 'tailwindcss/utilities';

      @import "components/base";
      @import "components/buttons";
      @import "components/cards";
      @import "components/forms";
      @import "components/icons";
      @import "components/navigation";
      EOF
    end

  run 'curl -L https://github.com/Tioneb12/tailwind_components/archive/master.zip > components.zip'
  run 'unzip components.zip -d app && rm components.zip && mv app/tailwind_components-master app/javascript/components'

  run "npx tailwindcss init --full"
  gsub_file "tailwind.config.js", /plugins:\s\[],/, "plugins: [require('@tailwindcss/forms'), require('@tailwindcss/typography'), require('@tailwindcss/aspect-ratio'),],"


  run "mv tailwind.config.js app/javascript/stylesheets/tailwind.config.js"

  append_to_file("app/javascript/packs/application.js", 'import "stylesheets/application"')
  inject_into_file("./postcss.config.js",
  "let tailwindcss = require('tailwindcss');\n",  before: "module.exports")
  inject_into_file("./postcss.config.js", "\n    tailwindcss('./app/javascript/stylesheets/tailwind.config.js'),", after: "plugins: [")
end

def add_assets
  run 'rm -rf vendor'
  run 'rm -rf app/assets'
  run 'curl -L https://github.com/Tioneb12/tailwind_assets/archive/master.zip > assets.zip'
  run 'unzip assets.zip -d app && rm assets.zip && mv app/tailwind_assets-master app/assets'

  gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')
end

# Layout
gsub_file('app/views/layouts/application.html.erb', "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>", "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload', defer: true %>")
style = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
      <%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
      <%= stylesheet_pack_tag 'application', 'data-turbolinks-track': 'reload' %>
HTML
gsub_file('app/views/layouts/application.html.erb', "<%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>", style)



def add_navbar
  run "mkdir -p app/views/shared"
  run 'curl -L https://raw.githubusercontent.com/Tioneb12/tailwind_template/master/templates/_navbar.html.erb > app/views/shared/_navbar.html.erb'
  # run 'curl -L https://raw.githubusercontent.com/thomasvanholder/jumpstart/main/templates/_navbar.html.erb > app/views/shared/_navbar.html.erb'
end

def add_flashes
  run 'curl -L https://raw.githubusercontent.com/Tioneb12/tailwind_template/master/templates/_flashes.html.erb > app/views/shared/_flashes.html.erb'
  # run 'curl -L https://raw.githubusercontent.com/thomasvanholder/jumpstart/main/templates/_flashes.html.erb > app/views/shared/_flashes.html.erb'
end

inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
  <<-HTML
    \n
    <%= render 'shared/navbar' %>
    <%= render 'shared/flashes' %>
  HTML
end

# README
########################################
markdown_file_content = <<-MARKDOWN
Rails app inspired by [thomasvanholder/jumpstart](https://github.com/thomasvanholder/jumpstart),.
MARKDOWN
file 'README.md', markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

def set_routes
  route "root to: 'pages#home'"
end

def add_devise
  generate('devise:install')
  generate('devise', 'User')
  run "rails g migration AddFirstNameLastNamePseudoSlugToUsers first_name last_name pseudo"

  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
    #{  "protect_from_forgery with: :exception\n" if Rails.version < "5.2"}  before_action :authenticate_user!
    end
  RUBY

  rails_command 'db:migrate'
  run 'curl -L https://github.com/Tioneb12/tailwind_devise/archive/master.zip > devise.zip'
  # run 'curl -L https://github.com/thomasvanholder/devise/archive/master.zip > devise.zip'
  run 'unzip devise.zip -d app && rm devise.zip && mv app/tailwind_devise-master app/views/devise'

  run 'rm app/controllers/pages_controller.rb'
  file 'app/controllers/pages_controller.rb', <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY
end

def add_friendly_id
  generate('friendly_id')
  run "rails g migration AddSlugToUsers slug:uniq"
  inject_into_file 'app/models/user.rb', after: 'class User < ApplicationRecord' do
    <<-RUBY.indent(2)
    extend FriendlyId
    friendly_id :pseudo, use: :slugged
    RUBY
  end
end

def add_i18n_params
  inject_into_file 'config/application.rb', after: 'config.load_defaults 6.0' do
    <<-RUBY.indent(4)
    config.i18n.enforce_available_locales = true
    config.i18n.available_locales = %i[fr]
    config.i18n.default_locale = :fr
    config.time_zone = 'Paris'
    RUBY
  end
end

def add_git_ignore
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT
end

def add_svg_helper
  inject_into_file 'Gemfile', after: "gem 'font-awesome-sass'" do
    <<~RUBY
      \ngem 'inline_svg'
    RUBY
  end

  run 'rm -rf app/helpers/application_helper.rb'

  run 'curl -L https://raw.githubusercontent.com/Tioneb12/tailwind_template/master/application_helper.rb > app/helpers/application_helper.rb'
  # run 'curl -L https://raw.githubusercontent.com/thomasvanholder/jumpstart/main/application_helper.rb > app/helpers/application_helper.rb'
end

environment generators

########################################
# AFTER BUNDLE
########################################
after_bundle do
  rails_command 'db:drop db:create db:migrate'
  generate(:controller, 'pages', 'home', '--skip-routes')

  set_routes
  add_assets
  add_devise
  add_friendly_id
  add_i18n_params
  add_git_ignore

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

  # Webpacker / Yarn
  ########################################
  append_file 'app/javascript/packs/application.js', <<~JS

    // ----------------------------------------------------
    // ABOVE IS RAILS DEFAULT CONFIGURATION
    // WRITE YOUR OWN JS STARTING FROM HERE 👇
    // ----------------------------------------------------

    // External imports
    import "../stylesheets/application.scss";


    // Internal imports, e.g:
    // import { initSelect2 } from '../components/init_select2';

    document.addEventListener('turbolinks:load', () => {
      // Call your functions here, e.g:
      // initSelect2();
    });
  JS

  inject_into_file 'config/webpack/environment.js', before: 'module.exports' do
    <<~JS
      const webpack = require('webpack');
      // Preventing Babel from transpiling NodeModules packages
      environment.loaders.delete('nodeModules');

      environment.plugins.prepend('Provide',
        new webpack.ProvidePlugin({
        })
      );
    JS
  end

  # Dotenv
  ########################################
  run 'touch .env'

  # Rubocop
  ########################################
  run 'curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml'

  # Git
  ########################################
  git add: '.'
  git commit: "-m 'Initial commit with template from https://github.com/Tioneb12/tailwind_template'"

  # Fix puma config
  gsub_file('config/puma.rb', 'pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }', '# pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }')

  add_tailwind
  add_navbar
  add_flashes
  add_svg_helper

  run "bundle install"
  say "--------------------------------"
  say
  say "Kickoff app successfully created! 👍", :green
  say
  say "Switch to your app by running:", :green
  say "  cd #{app_name}"
  say
end
