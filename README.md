# Alchemistdrops

A modern Phoenix LiveView application featuring a comprehensive course management system with payment integration, user authentication, and role-based access control.

## 🚀 Quick Start

### Development Setup

```bash
# Install dependencies
mix deps.get

# Setup database (create, migrate, seed)
mix ecto.setup

# Start Phoenix server
mix phx.server
```

Now visit [`localhost:4000`](http://localhost:4000) from your browser.

### Test Accounts (from seeds)

After running `mix ecto.setup`, you can log in with:

- **Admin**: `admin@alchemistdrops.com` / `AdminPassword123!`
- **Student**: `student@alchemistdrops.com` / `StudentPassword123!`
- **User**: `user@alchemistdrops.com` / `UserPassword123!`

## 🧪 Testing

```bash
# Run all tests
mix test

# Run with coverage
mix coverage

# Run precommit checks (tests + linters)
mix precommit
```

**Test Status**: ✅ 243 tests passing

## 📚 Documentation

Comprehensive documentation is available in the [`docs/`](./docs) directory:

- **[Documentation Index](./docs/README.md)** - Complete documentation overview
- **[Course Feature Docs](./docs/course-feature/README.md)** - Course management system
  - [TDD Plan](./docs/course-feature/01-TDD-PLAN.md) - Test-driven development approach
  - [Architecture](./docs/course-feature/02-ARCHITECTURE.md) - System design diagrams
  - [Phase 1 Complete](./docs/course-feature/03-PHASE-1-COMPLETE.md) - Implementation status
  - [Test Coverage](./docs/course-feature/04-TEST-COVERAGE.md) - Gherkin-style tests

## 🏗️ Project Structure

```
alchemistdrops/
├── docs/                    # 📚 All documentation
│   └── course-feature/      # Course system docs
├── lib/
│   ├── alchemistdrops/      # Business logic contexts
│   │   ├── accounts/        # User management
│   │   ├── courses/         # Courses & lessons
│   │   ├── enrollments/     # User enrollments
│   │   ├── payments/        # Payment processing
│   │   └── posts/           # Blog posts
│   └── alchemistdrops_web/  # Web interface
│       ├── live/            # LiveView modules
│       ├── controllers/     # Controllers
│       └── components/      # UI components
├── test/                    # Test suite (243 tests)
│   ├── alchemistdrops/      # Context tests
│   └── support/fixtures/    # Test fixtures
└── priv/
    └── repo/
        ├── migrations/      # Database migrations
        └── seeds.exs        # Sample data
```

## ✨ Features

### Course Management System
- ✅ **Phase 1 Complete**: Data modeling & schema tests
  - 4 database tables (courses, lessons, enrollments, payments)
  - 100% test coverage with Gherkin-style tests
  - Comprehensive fixtures and seeds
  
- 🚧 **Phase 2 In Progress**: Context functions & business logic
- 📅 **Planned**: LiveView UI, Stripe integration

### User Management
- ✅ Authentication with `phx.gen.auth`
- ✅ Role-based access control (admin, student, user)
- ✅ Email confirmation and password reset

### Blog System
- ✅ Post creation and management
- ✅ Admin and public views
- ✅ LiveView-powered interface

## 🛠️ Tech Stack

- **Framework**: Phoenix 1.8 with LiveView
- **Database**: PostgreSQL with Ecto
- **Testing**: ExUnit with Gherkin-style BDD
- **Authentication**: phx.gen.auth
- **Styling**: TailwindCSS v4
- **Payment**: Stripe (planned integration)

## 📊 Current Status

```
✅ Phase 1: Data Modeling & Schema Tests - 100% Complete
   - 4 migrations created
   - 4 schemas with full validation
   - 87 Gherkin-style tests
   - Test fixtures and seeds

🚧 Phase 2: Context Functions - In Progress
   - Business logic implementation
   - Access control helpers
   - CRUD operations

📅 Phase 3: LiveView UI - Planned
   - Admin panel
   - Public course catalog
   - Student dashboard
```

## 🧰 Development Commands

### Database

```bash
# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Run migrations
mix ecto.migrate

# Rollback last migration
mix ecto.rollback

# Seed data
mix run priv/repo/seeds.exs
```

### Testing

```bash
# All tests
mix test

# Specific test file
mix test test/alchemistdrops/courses/course_test.exs

# With verbose output
mix test --trace

# Coverage report
mix coverage
```

### Code Quality

```bash
# Run all checks (format, credo, dialyzer, sobelow, tests)
mix precommit

# Format code
mix format

# Linter
mix credo

# Type checking
mix dialyzer

# Security analysis
mix sobelow
```

## 🤝 Contributing

1. Read the [Documentation Index](./docs/README.md)
2. Review the [TDD Plan](./docs/course-feature/01-TDD-PLAN.md)
3. Write tests first (Gherkin-style)
4. Implement features
5. Run `mix precommit` before committing

## 📖 Learning Resources

### Phoenix

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

### Project-Specific

* [Course Feature Documentation](./docs/course-feature/README.md)
* [Test Coverage Report](./docs/course-feature/04-TEST-COVERAGE.md)
* [Architecture Diagrams](./docs/course-feature/02-ARCHITECTURE.md)

## 🚀 Deployment

Ready to run in production? Check out the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## 📝 License

This project is proprietary and confidential.

---

**Last Updated**: November 28, 2025  
**Version**: 1.0.0  
**Status**: Active Development
