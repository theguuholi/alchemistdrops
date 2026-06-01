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

## 🚀 Deployment

Ready to run in production? Check out the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## 📝 License

This project is proprietary and confidential.

---

**Last Updated**: November 28, 2025  
**Version**: 1.0.0  
**Status**: Active Development




---
# AlchemistDrops

Full-stack web platform built with Elixir and Phoenix. Focused on real-time systems, high availability, and domain-driven architecture.

## About

AlchemistDrops is a platform that demonstrates best practices in Elixir/Phoenix development, including automated tests, separation of concerns, and domain-driven design.

## Tech Stack

- **Language:** Elixir
- **Framework:** Phoenix
- **Database:** PostgreSQL
- **Tests:** ExUnit

## Installation

```bash
# Clone the repository
git clone https://github.com/theguuholi/alchemistdrops.git
cd alchemistdrops

# Install dependencies
mix deps.get

# Set up the database
mix ecto.setup

# Start the server
mix phx.server
```

## Usage

Visit `http://localhost:4000` after starting the server.

## Tests

```bash
mix test
```

## Contact

- Portfolio: [alchemistdrops.com](http://alchemistdrops.com)
- Email: g.92oliveira@gmail.com

