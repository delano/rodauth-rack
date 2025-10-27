# Hanami Demo Application - File Manifest

This document lists all files created for the Hanami + Rodauth demo application.

## Created: 2025-10-26

## Application Files

### Configuration Files (5 files)

1. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/Gemfile`
   - Dependencies for Hanami 2.x, rodauth-rack, Sequel, SQLite, bcrypt

2. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/config.ru`
   - Rack configuration file

3. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/config/app.rb`
   - Hanami application configuration with database setup

4. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/config/routes.rb`
   - Application routes (root and dashboard)

5. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/Rakefile`
   - Rake tasks

### Rodauth Integration Files (3 files)

6. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/config/providers/rodauth.rb`
   - Hanami provider that registers Rodauth middleware

7. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/lib/rodauth_app.rb`
   - Rodauth Roda application

8. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/lib/rodauth_main.rb`
   - Rodauth main configuration with enabled features

### Application Actions (2 files)

9. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/app/actions/home/show.rb`
   - Public home page action

10. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/slices/main/actions/dashboard/show.rb`
    - Protected dashboard action (requires authentication)

### Application Views (2 files)

11. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/app/views/home/show.rb`
    - Home page view

12. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/slices/main/views/dashboard/show.rb`
    - Dashboard view

### Templates (3 files)

13. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/app/templates/layouts/app.html.erb`
    - Application layout with navigation and styling

14. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/app/templates/home/show.html.erb`
    - Home page template

15. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/slices/main/templates/dashboard/show.html.erb`
    - Protected dashboard template

### Documentation (3 files)

16. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/README.md`
    - Main documentation with overview, setup, and usage

17. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/SETUP.md`
    - Quick setup guide with troubleshooting

18. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/MANIFEST.md`
    - This file

### Supporting Files (2 files)

19. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/.env`
    - Environment variables

20. `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/.gitignore`
    - Git ignore patterns

## Total: 21 files

## Directory Structure

```
examples/hanami-demo/
├── app/
│   ├── actions/home/show.rb
│   ├── templates/
│   │   ├── layouts/app.html.erb
│   │   └── home/show.html.erb
│   └── views/home/show.rb
├── config/
│   ├── app.rb
│   ├── routes.rb
│   └── providers/rodauth.rb
├── lib/
│   ├── rodauth_app.rb
│   └── rodauth_main.rb
├── slices/main/
│   ├── actions/dashboard/show.rb
│   ├── templates/dashboard/show.html.erb
│   └── views/dashboard/show.rb
├── .env
├── .gitignore
├── config.ru
├── Gemfile
├── MANIFEST.md
├── Rakefile
├── README.md
└── SETUP.md
```

## Features Demonstrated

### Rodauth Integration

- Provider registration in Hanami
- Middleware configuration
- Dependency injection
- Protected routes

### Hanami 2.x Features

- Application configuration
- Routing (root + slice routes)
- Actions with dependency injection
- Views and templates
- Layout rendering

### Authentication Flow

- Account creation
- Email verification
- Login/logout
- Remember me
- Password reset
- Protected routes

## Next Steps

See README.md for:

- Installation instructions
- Database setup
- Running the application
- Testing authentication flow
- Customization options
