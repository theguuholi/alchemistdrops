# Project Organization Guide

## 📂 Complete File Structure

```
alchemistdrops/
│
├── 📚 Documentation Layer
│   ├── docs/                           # All project documentation
│   │   ├── README.md                   # Documentation index
│   │   └── course-feature/             # Course feature docs
│   │       ├── README.md               # Feature overview
│   │       ├── 01-TDD-PLAN.md         # Implementation plan
│   │       ├── 02-ARCHITECTURE.md     # System design
│   │       ├── 03-PHASE-1-COMPLETE.md # Status report
│   │       └── 04-TEST-COVERAGE.md    # Test documentation
│   │
│   ├── README.md                       # Project overview
│   ├── AGENTS.md                       # AI agent guidelines
│   ├── CI_PIPELINE.md                  # CI/CD configuration
│   ├── PIPELINE_MIGRATION.md           # Migration docs
│   └── SUMMARY.md                      # Project summary
│
├── 🎯 Application Layer
│   ├── lib/alchemistdrops/            # Business Logic (Contexts)
│   │   ├── accounts/                   # ✅ User management
│   │   │   ├── scope.ex
│   │   │   ├── user.ex
│   │   │   ├── user_token.ex
│   │   │   └── user_notifier.ex
│   │   ├── accounts.ex
│   │   │
│   │   ├── courses/                    # ✅ Course management (Phase 1)
│   │   │   ├── course.ex              # Course schema
│   │   │   └── lesson.ex              # Lesson schema
│   │   ├── courses.ex                  # Context (Phase 2)
│   │   │
│   │   ├── enrollments/                # ✅ Enrollment tracking (Phase 1)
│   │   │   └── enrollment.ex          # Enrollment schema
│   │   ├── enrollments.ex              # Context (Phase 2)
│   │   │
│   │   ├── payments/                   # ✅ Payment processing (Phase 1)
│   │   │   └── payment.ex             # Payment schema
│   │   ├── payments.ex                 # Context (Phase 2)
│   │   │
│   │   ├── posts/                      # ✅ Blog system
│   │   │   └── post.ex
│   │   ├── posts.ex
│   │   │
│   │   ├── application.ex              # OTP Application
│   │   ├── mailer.ex                   # Email delivery
│   │   └── repo.ex                     # Database connection
│   │
│   ├── lib/alchemistdrops_web/         # Web Interface Layer
│   │   ├── components/                 # UI Components
│   │   │   ├── core_components.ex     # Reusable components
│   │   │   ├── layouts.ex             # Layout components
│   │   │   └── layouts/
│   │   │       └── root.html.heex     # Root layout
│   │   │
│   │   ├── live/                       # LiveView modules
│   │   │   ├── admin/                  # Admin panel
│   │   │   │   └── post_live/
│   │   │   │       ├── index.ex
│   │   │   │       ├── form.ex
│   │   │   │       └── show.ex
│   │   │   │
│   │   │   ├── home_live/              # Homepage
│   │   │   │   ├── index.ex
│   │   │   │   └── index.html.heex
│   │   │   │
│   │   │   ├── post_live/              # Blog posts
│   │   │   │   ├── index.ex
│   │   │   │   ├── show.ex
│   │   │   │   └── *.html.heex
│   │   │   │
│   │   │   └── user_live/              # Authentication
│   │   │       ├── confirmation.ex
│   │   │       ├── login.ex
│   │   │       ├── registration.ex
│   │   │       └── settings.ex
│   │   │
│   │   ├── controllers/                # Controllers
│   │   │   ├── error_html.ex
│   │   │   ├── error_json.ex
│   │   │   └── user_session_controller.ex
│   │   │
│   │   ├── endpoint.ex                 # HTTP endpoint
│   │   ├── router.ex                   # Route definitions
│   │   ├── user_auth.ex                # Auth plugs
│   │   ├── gettext.ex                  # Internationalization
│   │   └── telemetry.ex                # Metrics
│   │
│   ├── lib/alchemistdrops.ex          # Context boundary
│   ├── lib/alchemistdrops_web.ex      # Web boundary
│   │
│   └── lib/mix/tasks/                  # Custom Mix tasks
│       └── coverage.index.ex
│
├── 🧪 Test Layer
│   ├── test/alchemistdrops/           # Context tests
│   │   ├── accounts_test.exs           # ✅ User tests
│   │   │
│   │   ├── courses/                    # ✅ Course tests (19 scenarios)
│   │   │   ├── course_test.exs        # Gherkin-style
│   │   │   └── lesson_test.exs        # Gherkin-style
│   │   │
│   │   ├── enrollments/                # ✅ Enrollment tests (17 scenarios)
│   │   │   └── enrollment_test.exs    # Gherkin-style
│   │   │
│   │   ├── payments/                   # ✅ Payment tests (30 scenarios)
│   │   │   └── payment_test.exs       # Gherkin-style
│   │   │
│   │   └── posts_test.exs              # ✅ Post tests
│   │
│   ├── test/alchemistdrops_web/       # Web tests
│   │   ├── controllers/
│   │   │   ├── error_html_test.exs
│   │   │   ├── error_json_test.exs
│   │   │   └── user_session_controller_test.exs
│   │   │
│   │   ├── live/                       # LiveView tests
│   │   │   ├── admin/
│   │   │   │   └── post_live_test.exs
│   │   │   ├── home_live_test.exs
│   │   │   ├── post_live_test.exs
│   │   │   └── user_live/
│   │   │       ├── confirmation_test.exs
│   │   │       ├── login_test.exs
│   │   │       ├── registration_test.exs
│   │   │       └── settings_test.exs
│   │   │
│   │   └── user_auth_test.exs
│   │
│   ├── test/support/                   # Test utilities
│   │   ├── conn_case.ex               # Controller test helpers
│   │   ├── data_case.ex               # Context test helpers
│   │   │
│   │   └── fixtures/                   # Test data factories
│   │       ├── accounts_fixtures.ex    # User fixtures
│   │       ├── courses_fixtures.ex     # ✅ Course fixtures
│   │       ├── enrollments_fixtures.ex # ✅ Enrollment fixtures
│   │       ├── payments_fixtures.ex    # ✅ Payment fixtures
│   │       └── posts_fixtures.ex       # Post fixtures
│   │
│   └── test_helper.exs                 # Test configuration
│
├── 💾 Database Layer
│   ├── priv/repo/migrations/          # Database migrations
│   │   ├── 20251119112542_create_users_auth_tables.exs
│   │   ├── 20251120183412_add_roles.exs
│   │   ├── 20251125113851_create_posts.exs
│   │   ├── 20251128154634_create_courses.exs          # ✅
│   │   ├── 20251128154640_create_lessons.exs          # ✅
│   │   ├── 20251128154641_create_enrollments.exs      # ✅
│   │   └── 20251128154643_create_payments.exs         # ✅
│   │
│   ├── priv/repo/seeds.exs            # ✅ Sample data
│   │
│   ├── priv/gettext/                  # Translations
│   │   ├── en/LC_MESSAGES/errors.po
│   │   └── errors.pot
│   │
│   └── priv/static/                   # Static assets
│       ├── assets/
│       ├── favicon.ico
│       ├── images/
│       └── robots.txt
│
├── 🎨 Frontend Layer
│   ├── assets/                        # Source assets
│   │   ├── css/
│   │   │   └── app.css               # TailwindCSS v4
│   │   ├── js/
│   │   │   └── app.js                # JavaScript entry
│   │   ├── tsconfig.json
│   │   └── vendor/                    # Third-party libraries
│   │
│   └── (compiled to priv/static/)
│
├── ⚙️ Configuration Layer
│   ├── config/
│   │   ├── config.exs                 # Shared config
│   │   ├── dev.exs                    # Development
│   │   ├── test.exs                   # Testing
│   │   ├── prod.exs                   # Production
│   │   └── runtime.exs                # Runtime config
│   │
│   ├── mix.exs                        # Project definition
│   ├── mix.lock                       # Dependency lock
│   │
│   └── .test_coverage_ignore.exs      # Coverage exclusions
│
├── 🔨 Build Artifacts (ignored)
│   ├── _build/                        # Compiled code
│   ├── deps/                          # Dependencies
│   └── cover/                         # Coverage reports
│
└── 🔒 Version Control
    └── .gitignore
```

## 📊 Component Status

### ✅ Complete
- User management (accounts context)
- Blog system (posts context)
- Course schemas (Phase 1)
- Lesson schemas (Phase 1)
- Enrollment schemas (Phase 1)
- Payment schemas (Phase 1)
- All test fixtures
- Database seeds
- 243 passing tests

### 🚧 In Progress
- Course context functions (Phase 2)
- Enrollment context functions (Phase 2)
- Payment context functions (Phase 2)

### 📅 Planned
- Admin course LiveViews (Phase 3)
- Public course catalog (Phase 3)
- Student dashboard (Phase 3)
- Stripe integration (Phase 4)

## 🎯 Layer Responsibilities

### Documentation Layer
**Purpose**: Knowledge base and planning
- Feature planning and architecture
- Implementation guides
- Test coverage reports
- Status updates

### Application Layer
**Purpose**: Business logic and domain models
- Context modules (business logic)
- Schema modules (data structures)
- Validation and business rules
- Database queries

### Web Layer
**Purpose**: User interface and HTTP handling
- LiveView modules (real-time UI)
- Controllers (request handling)
- Components (reusable UI)
- Layouts and templates

### Test Layer
**Purpose**: Quality assurance
- Context tests (business logic)
- LiveView tests (integration)
- Fixtures (test data)
- Test utilities

### Database Layer
**Purpose**: Data persistence
- Migrations (schema changes)
- Seeds (sample data)
- Static assets

### Configuration Layer
**Purpose**: Application setup
- Environment config
- Dependencies
- Build settings

## 🔄 Development Workflow

```
1. Plan (docs/)
   ├── Write feature docs
   ├── Design architecture
   └── Create TDD plan
   
2. Test (test/)
   ├── Write Gherkin tests
   ├── Create fixtures
   └── Verify failures
   
3. Implement (lib/)
   ├── Build schemas
   ├── Write contexts
   └── Create LiveViews
   
4. Verify
   ├── Run tests
   ├── Check coverage
   └── Update docs
   
5. Deploy
   ├── Review changes
   ├── Run precommit
   └── Merge to main
```

## 📝 File Naming Conventions

### Context Files
```
lib/alchemistdrops/{context}/{entity}.ex
Example: lib/alchemistdrops/courses/course.ex
```

### Test Files
```
test/alchemistdrops/{context}/{entity}_test.exs
Example: test/alchemistdrops/courses/course_test.exs
```

### Fixture Files
```
test/support/fixtures/{context}_fixtures.ex
Example: test/support/fixtures/courses_fixtures.ex
```

### Migration Files
```
priv/repo/migrations/{timestamp}_{action}_{table}.exs
Example: 20251128154634_create_courses.exs
```

### Documentation Files
```
docs/{feature}/{number}-{NAME}.md
Example: docs/course-feature/01-TDD-PLAN.md
```

## 🎨 Code Organization Principles

1. **Contexts are boundaries** - Keep business logic in context modules
2. **Schemas are data** - Keep validations close to data structures
3. **Web is interface** - LiveViews coordinate, don't contain logic
4. **Tests mirror structure** - Test files follow source file organization
5. **Docs explain why** - Code shows how, docs explain why

## 🔍 Finding Things

### By Feature
- **Accounts**: `lib/alchemistdrops/accounts/`
- **Courses**: `lib/alchemistdrops/courses/`
- **Posts**: `lib/alchemistdrops/posts/`

### By Layer
- **Business Logic**: `lib/alchemistdrops/`
- **Web Interface**: `lib/alchemistdrops_web/`
- **Tests**: `test/`
- **Docs**: `docs/`

### By Type
- **Schemas**: `lib/alchemistdrops/{context}/{entity}.ex`
- **LiveViews**: `lib/alchemistdrops_web/live/`
- **Tests**: `test/alchemistdrops/{context}/`
- **Fixtures**: `test/support/fixtures/`

---

**This structure follows Phoenix best practices and Clean Architecture principles.**


