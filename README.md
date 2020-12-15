Inspired by the [Le Wagon Rails templates](https://github.com/lewagon/rails-templates)

## Create a new repo

### Rails 6 | Tailwind 2.0 🏳️‍🌈 | Devise 🔐
- styled navbar
- styled devise/views from [thomasvanholder/devise](https://github.com/thomasvanholder/devise)
- javascript/components from [thomasvanholder/tailwind-components](https://github.com/thomasvanholder/tailwind-components)
- assets and icons from [thomasvanholder/assets](https://github.com/thomasvanholder/assets)
- first and last name added to user model

```bash
rails new \
  --database postgresql \
  --webpack \
  -m https://raw.githubusercontent.com/Tioneb12/tailwind_template/master/template.rb \
  PROJECT-NAME
```

__To Do__
- [ ] application controller, sanitize extra paramaters
- [ ] add more button colors as tailwind components
