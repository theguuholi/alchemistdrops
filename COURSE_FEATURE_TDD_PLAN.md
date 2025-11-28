# Course Feature - TDD Plan & Architecture

## Overview
This document outlines the Test-Driven Development (TDD) approach for implementing a comprehensive course management system with payment integration, lessons, and access control.

## Requirements Summary
- **Admin** can create, update, and delete courses
- **Courses** have pricing information and optional Stripe payment links
- **Courses** contain multiple lessons
- **Access Control**: Users and students can access courses/lessons based on enrollment/purchase
- **Payment Integration**: Stripe integration for course purchases

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Application Layer                            │
└─────────────────────────────────────────────────────────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                           │
        ▼                          ▼                           ▼
┌───────────────┐         ┌────────────────┐         ┌────────────────┐
│  Admin Panel  │         │  Student Area  │         │  Public Area   │
│               │         │                │         │                │
│ - Course CRUD │         │ - My Courses   │         │ - Course List  │
│ - Lesson CRUD │         │ - View Lessons │         │ - Course Detail│
│ - Enrollments │         │ - Track Prog.  │         │ - Purchase     │
└───────┬───────┘         └────────┬───────┘         └────────┬───────┘
        │                          │                           │
        └──────────────────────────┼───────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          Context Layer                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │
│  │   Courses        │  │   Enrollments    │  │   Payments       │ │
│  │                  │  │                  │  │                  │ │
│  │ - list_courses   │  │ - enroll_user    │  │ - create_payment │ │
│  │ - get_course     │  │ - user_enrolled? │  │ - process_stripe │ │
│  │ - create_course  │  │ - list_user_     │  │ - verify_payment │ │
│  │ - update_course  │  │   courses        │  │                  │ │
│  │ - delete_course  │  │ - can_access?    │  │                  │ │
│  │ - create_lesson  │  │                  │  │                  │ │
│  │ - update_lesson  │  │                  │  │                  │ │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          Database Schema                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────┐     ┌──────────────┐     ┌────────────┐            │
│  │   users    │     │  enrollments │     │  courses   │            │
│  ├────────────┤     ├──────────────┤     ├────────────┤            │
│  │ id         │◄────┤ user_id      │────►│ id         │            │
│  │ email      │     │ course_id    │     │ title      │            │
│  │ role       │     │ enrolled_at  │     │ description│            │
│  │ ...        │     │ status       │     │ price      │            │
│  └────────────┘     │ completed_at │     │ currency   │            │
│                     └──────────────┘     │ stripe_link│            │
│                                          │ published  │            │
│  ┌────────────┐                         │ ...        │            │
│  │  lessons   │                         └─────┬──────┘            │
│  ├────────────┤                               │                    │
│  │ id         │                               │                    │
│  │ course_id  ├───────────────────────────────┘                    │
│  │ title      │                                                    │
│  │ content    │     ┌──────────────┐                              │
│  │ order      │     │  payments    │                              │
│  │ duration   │     ├──────────────┤                              │
│  │ ...        │     │ id           │                              │
│  └────────────┘     │ user_id      │                              │
│                     │ course_id    │                              │
│                     │ amount       │                              │
│                     │ stripe_id    │                              │
│                     │ status       │                              │
│                     │ ...          │                              │
│                     └──────────────┘                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Database Schema Design

### Tables & Relationships

```sql
-- Courses Table
CREATE TABLE courses (
  id UUID PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  body TEXT, -- Full course details (markdown)
  price DECIMAL(10,2) DEFAULT 0.00,
  currency VARCHAR(3) DEFAULT 'USD',
  stripe_product_id VARCHAR(255),
  stripe_price_id VARCHAR(255),
  published BOOLEAN DEFAULT false,
  thumbnail_url TEXT,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Lessons Table
CREATE TABLE lessons (
  id UUID PRIMARY KEY,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  content TEXT, -- Lesson content (markdown)
  order INTEGER NOT NULL DEFAULT 0,
  duration INTEGER, -- in minutes
  video_url TEXT,
  published BOOLEAN DEFAULT false,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Enrollments Table
CREATE TABLE enrollments (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  status VARCHAR(20) DEFAULT 'active', -- active, completed, cancelled
  enrolled_at TIMESTAMP NOT NULL,
  completed_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(user_id, course_id)
);

-- Payments Table
CREATE TABLE payments (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'USD',
  stripe_payment_intent_id VARCHAR(255),
  stripe_checkout_session_id VARCHAR(255),
  status VARCHAR(20) DEFAULT 'pending', -- pending, completed, failed, refunded
  metadata JSONB,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Lesson Progress Table (Optional - for tracking user progress)
CREATE TABLE lesson_progress (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  completed BOOLEAN DEFAULT false,
  completed_at TIMESTAMP,
  notes TEXT,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(user_id, lesson_id)
);
```

---

## TDD Test Plan

### Phase 1: Core Schema & Context Tests

#### 1.1 Course Schema Tests (`test/alchemistdrops/courses/course_test.exs`)

```elixir
describe "course changeset" do
  test "valid changeset with required fields"
  test "requires title"
  test "requires description"
  test "validates price is non-negative"
  test "validates currency format"
  test "sets default values"
  test "trims and validates title length"
end
```

#### 1.2 Lesson Schema Tests (`test/alchemistdrops/courses/lesson_test.exs`)

```elixir
describe "lesson changeset" do
  test "valid changeset with required fields"
  test "requires title and course_id"
  test "validates order is non-negative"
  test "validates duration is positive"
  test "sets default order value"
end
```

#### 1.3 Enrollment Schema Tests (`test/alchemistdrops/enrollments/enrollment_test.exs`)

```elixir
describe "enrollment changeset" do
  test "valid changeset with required fields"
  test "requires user_id and course_id"
  test "sets enrolled_at timestamp"
  test "validates status is valid enum value"
  test "unique constraint on user_id + course_id"
end
```

#### 1.4 Payment Schema Tests (`test/alchemistdrops/payments/payment_test.exs`)

```elixir
describe "payment changeset" do
  test "valid changeset with required fields"
  test "requires user_id, course_id, and amount"
  test "validates amount is positive"
  test "validates status enum"
  test "stores metadata as JSONB"
end
```

### Phase 2: Context Function Tests

#### 2.1 Courses Context Tests (`test/alchemistdrops/courses_test.exs`)

```elixir
describe "list_courses/0" do
  test "returns all published courses ordered by title"
  test "excludes unpublished courses"
  test "returns empty list when no courses exist"
end

describe "list_all_courses/0" do
  test "returns all courses including unpublished (admin only)"
end

describe "get_course!/1" do
  test "returns course with given id"
  test "preloads lessons by default"
  test "raises when course doesn't exist"
end

describe "get_course_with_lessons!/1" do
  test "returns course with lessons ordered by order field"
  test "includes unpublished lessons for admin"
end

describe "create_course/1" do
  test "creates course with valid attributes"
  test "returns error changeset with invalid attributes"
  test "sets default currency and price"
end

describe "update_course/2" do
  test "updates course with valid attributes"
  test "returns error changeset with invalid attributes"
  test "can publish/unpublish course"
end

describe "delete_course/1" do
  test "deletes the course"
  test "cascades delete to lessons"
end

describe "create_lesson/2" do
  test "creates lesson for a course with valid attributes"
  test "returns error changeset with invalid attributes"
  test "auto-increments order if not provided"
end

describe "update_lesson/2" do
  test "updates lesson with valid attributes"
  test "returns error changeset with invalid attributes"
end

describe "delete_lesson/1" do
  test "deletes the lesson"
end

describe "reorder_lessons/2" do
  test "updates order for multiple lessons"
  test "validates all lessons belong to same course"
end
```

#### 2.2 Enrollments Context Tests (`test/alchemistdrops/enrollments_test.exs`)

```elixir
describe "enroll_user/2" do
  test "enrolls user in a course"
  test "sets enrolled_at timestamp"
  test "returns error if already enrolled"
  test "returns error if course doesn't exist"
end

describe "user_enrolled?/2" do
  test "returns true when user is enrolled"
  test "returns false when user is not enrolled"
  test "returns false for cancelled enrollments"
end

describe "can_access_course?/2" do
  test "returns true for admin users"
  test "returns true for enrolled users"
  test "returns true if course is free"
  test "returns false if not enrolled and course has price"
end

describe "can_access_lesson?/2" do
  test "returns true if can access parent course"
  test "returns false if cannot access parent course"
end

describe "list_user_enrollments/1" do
  test "returns all active enrollments for user"
  test "preloads course information"
  test "orders by enrolled_at desc"
end

describe "list_course_enrollments/1" do
  test "returns all enrollments for a course"
  test "preloads user information"
  test "includes enrollment statistics"
end

describe "complete_enrollment/1" do
  test "marks enrollment as completed"
  test "sets completed_at timestamp"
end

describe "cancel_enrollment/1" do
  test "marks enrollment as cancelled"
  test "does not delete enrollment record"
end
```

#### 2.3 Payments Context Tests (`test/alchemistdrops/payments_test.exs`)

```elixir
describe "create_payment/1" do
  test "creates payment record with valid attributes"
  test "returns error with invalid attributes"
  test "sets status to pending by default"
end

describe "get_payment!/1" do
  test "returns payment with given id"
  test "preloads user and course"
end

describe "list_user_payments/1" do
  test "returns all payments for user"
  test "orders by inserted_at desc"
end

describe "list_course_payments/1" do
  test "returns all payments for course"
  test "includes payment statistics"
end

describe "mark_payment_completed/1" do
  test "updates payment status to completed"
  test "creates enrollment if payment successful"
end

describe "mark_payment_failed/1" do
  test "updates payment status to failed"
  test "does not create enrollment"
end

describe "create_stripe_checkout_session/2" do
  test "creates Stripe checkout session"
  test "stores session_id in payment record"
  test "includes course and user metadata"
end

describe "handle_stripe_webhook/1" do
  test "processes checkout.session.completed event"
  test "marks payment as completed"
  test "enrolls user in course"
  test "ignores unknown events"
end
```

### Phase 3: LiveView Tests

#### 3.1 Admin Course Management Tests (`test/alchemistdrops_web/live/admin/course_live_test.exs`)

```elixir
describe "Index as admin" do
  test "lists all courses", %{conn: conn}
  test "saves new course", %{conn: conn}
  test "displays course in listing", %{conn: conn}
  test "updates course in listing", %{conn: conn}
  test "deletes course in listing", %{conn: conn}
  test "redirects when not admin", %{conn: conn}
end

describe "Form" do
  test "displays form for new course", %{conn: conn}
  test "saves new course with valid data", %{conn: conn}
  test "displays error with invalid data", %{conn: conn}
  test "updates existing course", %{conn: conn}
  test "validates required fields", %{conn: conn}
end

describe "Show" do
  test "displays course details", %{conn: conn}
  test "displays associated lessons", %{conn: conn}
  test "can add new lesson", %{conn: conn}
  test "can edit lesson", %{conn: conn}
  test "can delete lesson", %{conn: conn}
  test "can reorder lessons", %{conn: conn}
end
```

#### 3.2 Public Course Listing Tests (`test/alchemistdrops_web/live/course_live_test.exs`)

```elixir
describe "Index" do
  test "lists all published courses", %{conn: conn}
  test "does not list unpublished courses", %{conn: conn}
  test "displays course price", %{conn: conn}
  test "shows enrollment status for logged-in users", %{conn: conn}
  test "shows purchase button for unenrolled courses", %{conn: conn}
end

describe "Show" do
  test "displays course details", %{conn: conn}
  test "shows lessons for enrolled users", %{conn: conn}
  test "hides lessons for non-enrolled users", %{conn: conn}
  test "displays purchase button if not enrolled", %{conn: conn}
  test "redirects to Stripe checkout when purchasing", %{conn: conn}
end
```

#### 3.3 Student Course View Tests (`test/alchemistdrops_web/live/student/course_live_test.exs`)

```elixir
describe "My Courses" do
  test "lists enrolled courses", %{conn: conn}
  test "displays course progress", %{conn: conn}
  test "redirects unauthenticated users", %{conn: conn}
end

describe "Lesson View" do
  test "displays lesson content for enrolled user", %{conn: conn}
  test "redirects non-enrolled user", %{conn: conn}
  test "tracks lesson completion", %{conn: conn}
  test "navigates to next lesson", %{conn: conn}
  test "displays lesson navigation", %{conn: conn}
end
```

#### 3.4 Payment/Checkout Tests (`test/alchemistdrops_web/controllers/payment_controller_test.exs`)

```elixir
describe "create_checkout_session" do
  test "creates Stripe checkout session", %{conn: conn}
  test "redirects to Stripe", %{conn: conn}
  test "requires authentication", %{conn: conn}
  test "prevents duplicate purchases", %{conn: conn}
end

describe "webhook" do
  test "handles successful payment", %{conn: conn}
  test "enrolls user after payment", %{conn: conn}
  test "ignores duplicate webhooks", %{conn: conn}
  test "validates webhook signature", %{conn: conn}
end

describe "success" do
  test "displays success message", %{conn: conn}
  test "redirects to course", %{conn: conn}
end

describe "cancel" do
  test "displays cancellation message", %{conn: conn}
  test "allows retry", %{conn: conn}
end
```

---

## Implementation Order (TDD Approach)

### Step 1: Database Migrations
1. Create courses table migration
2. Create lessons table migration
3. Create enrollments table migration
4. Create payments table migration
5. Create lesson_progress table migration (optional)

### Step 2: Schemas & Basic Context
1. **Write failing tests** for Course schema
2. Implement Course schema to pass tests
3. **Write failing tests** for Lesson schema
4. Implement Lesson schema to pass tests
5. **Write failing tests** for Enrollment schema
6. Implement Enrollment schema to pass tests
7. **Write failing tests** for Payment schema
8. Implement Payment schema to pass tests

### Step 3: Courses Context Functions
1. **Write failing tests** for basic CRUD operations
2. Implement list_courses, get_course, create_course, etc.
3. **Write failing tests** for lesson management
4. Implement lesson CRUD functions
5. Run tests and refactor

### Step 4: Enrollments Context
1. **Write failing tests** for enrollment operations
2. Implement enroll_user, user_enrolled?, can_access?, etc.
3. **Write failing tests** for access control logic
4. Implement access control functions
5. Run tests and refactor

### Step 5: Payments Context (Basic)
1. **Write failing tests** for payment creation
2. Implement basic payment functions
3. Prepare for Stripe integration (stub for now)
4. Run tests and refactor

### Step 6: Admin LiveView
1. **Write failing tests** for Admin Course Index
2. Implement Admin Course Index LiveView
3. **Write failing tests** for Course Form
4. Implement Course Form LiveView
5. **Write failing tests** for Course Show with lessons
6. Implement Course Show LiveView
7. Run tests and refactor

### Step 7: Public Course Views
1. **Write failing tests** for public course listing
2. Implement public CourseIndex LiveView
3. **Write failing tests** for course detail view
4. Implement CourseShow LiveView with access control
5. Run tests and refactor

### Step 8: Student Area
1. **Write failing tests** for student course listing
2. Implement student CourseIndex (My Courses)
3. **Write failing tests** for lesson viewing
4. Implement LessonShow LiveView with progress tracking
5. Run tests and refactor

### Step 9: Stripe Integration
1. **Write failing tests** for checkout session creation
2. Implement Stripe checkout integration
3. **Write failing tests** for webhook handling
4. Implement webhook controller
5. **Write failing tests** for success/cancel flows
6. Implement success/cancel pages
7. Run tests and refactor

### Step 10: Polish & Edge Cases
1. Add enrollment statistics
2. Add payment history views
3. Implement lesson progress tracking
4. Add course completion certificates (optional)
5. Run full test suite
6. Refactor and optimize

---

## Access Control Matrix

| Role    | Create Course | Edit Course | Delete Course | View All Courses | Enroll | Access Paid Course | Manage Enrollments |
|---------|---------------|-------------|---------------|------------------|--------|--------------------|--------------------|
| Admin   | ✓             | ✓           | ✓             | ✓                | ✓      | ✓                  | ✓                  |
| Student | ✗             | ✗           | ✗             | ✓ (published)    | ✓      | ✓ (if enrolled)    | ✗                  |
| User    | ✗             | ✗           | ✗             | ✓ (published)    | ✓      | ✓ (if enrolled)    | ✗                  |
| Guest   | ✗             | ✗           | ✗             | ✓ (published)    | ✗      | ✗                  | ✗                  |

---

## Router Structure

```elixir
# Public routes
scope "/", AlchemistdropsWeb do
  pipe_through [:browser]

  live_session :current_user,
    on_mount: [{AlchemistdropsWeb.UserAuth, :mount_current_scope}] do
    live "/courses", CourseLive.Index, :index
    live "/courses/:id", CourseLive.Show, :show
  end
end

# Authenticated user routes (students)
scope "/", AlchemistdropsWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_authenticated_user,
    on_mount: [{AlchemistdropsWeb.UserAuth, :require_authenticated}] do
    live "/my-courses", Student.CourseLive.Index, :index
    live "/my-courses/:course_id/lessons/:id", Student.LessonLive.Show, :show
  end

  # Payment routes
  post "/courses/:id/checkout", PaymentController, :create_checkout_session
  get "/courses/payment/success", PaymentController, :success
  get "/courses/payment/cancel", PaymentController, :cancel
end

# Webhook route (no auth required - verified by Stripe signature)
scope "/api", AlchemistdropsWeb do
  pipe_through :api
  
  post "/webhooks/stripe", WebhookController, :stripe
end

# Admin routes
scope "/admin", AlchemistdropsWeb.Admin do
  pipe_through [:browser, :require_authenticated_user]

  live_session :required_admin_user,
    on_mount: [{AlchemistdropsWeb.UserAuth, :require_admin_user}] do
    live "/courses", CourseLive.Index, :index
    live "/courses/new", CourseLive.Form, :new
    live "/courses/:id", CourseLive.Show, :show
    live "/courses/:id/edit", CourseLive.Form, :edit
    live "/courses/:course_id/lessons/new", LessonLive.Form, :new
    live "/courses/:course_id/lessons/:id/edit", LessonLive.Form, :edit
    
    live "/enrollments", EnrollmentLive.Index, :index
    live "/payments", PaymentLive.Index, :index
  end
end
```

---

## Key Technical Decisions

### 1. **Context Separation**
- `Courses` context: Handles courses and lessons
- `Enrollments` context: Handles user enrollments and access control
- `Payments` context: Handles payment processing and Stripe integration

### 2. **Access Control Strategy**
- Use `can_access_course?/2` and `can_access_lesson?/2` functions
- Check access in LiveView mount callbacks
- Admins always have full access
- Free courses (price = 0) are accessible to all authenticated users
- Paid courses require enrollment (via payment)

### 3. **Stripe Integration**
- Use Stripe Checkout for payment processing
- Store minimal payment data (avoid storing sensitive info)
- Use webhooks for reliable payment confirmation
- Store `stripe_product_id` and `stripe_price_id` on courses

### 4. **Data Integrity**
- Use database constraints for uniqueness (user_id + course_id in enrollments)
- Cascade deletes appropriately (lessons delete when course deletes)
- Use transactions for payment + enrollment operations

### 5. **Performance Considerations**
- Preload associations in queries to avoid N+1
- Use LiveView streams for course/lesson listings
- Index foreign keys and frequently queried fields

---

## Testing Strategy

### Unit Tests (Context Layer)
- Test all context functions in isolation
- Use fixtures for test data
- Test edge cases and error conditions
- Aim for 100% coverage of business logic

### Integration Tests (LiveView)
- Test user interactions and workflows
- Test access control at the LiveView level
- Test form submissions and validations
- Test navigation and redirects

### External Service Tests
- Mock Stripe API calls in tests
- Test webhook handling with fixture data
- Test error handling for API failures

---

## Next Steps

1. Review and approve this plan
2. Set up test fixtures and factories
3. Begin implementation following TDD approach
4. Start with Phase 1 (Schema tests)
5. Progress through each phase systematically
6. Regular test runs to ensure nothing breaks

---

## Stripe Setup Checklist (When Ready)

- [ ] Create Stripe account
- [ ] Get API keys (test and production)
- [ ] Configure webhook endpoints
- [ ] Create products and prices in Stripe
- [ ] Set up Stripe CLI for local webhook testing
- [ ] Document Stripe webhook signature verification
- [ ] Set up environment variables for Stripe keys

---

**This document should be treated as a living document. Update it as requirements change or new insights emerge during development.**


### TDD Implementation Task List

#### Phase 1: Data Modeling & Schema Tests
- [ ] Define Course, Lesson, Enrollment, and Payment Ecto schemas
- [ ] Write unit tests for schema validations and constraints (Course, Lesson, Enrollment, Payment)
- [ ] Write tests for role-based access fields and associations
- [ ] Create sample seeds for admin, student, user roles

#### Phase 2: Contexts & Business Logic
- [ ] Implement and test course context functions (`list_courses`, `get_course!`, `create_course`, `update_course`, `delete_course`)
- [ ] Implement and test lesson context functions
- [ ] Implement and test enrollments context: enrolling users, enrolling via Stripe, verifying access
- [ ] Test business rules: only admin can create/update/delete, only enrolled users can access lessons, free vs paid flow

#### Phase 3: Public & Student UI LiveViews
- [ ] Write LiveView integration tests for Public Area: courses listing, course detail, purchase/enroll button
- [ ] Implement and test enrollment flows (free/paid, guest-redirect-to-login)
- [ ] Write LiveView tests for Student Area: /my-courses, view lessons, access control
- [ ] Write tests for progress tracking UI

#### Phase 4: Admin Panel LiveViews
- [ ] Write LiveView integration tests for Course CRUD and Lesson CRUD
- [ ] Write LiveView tests for managing enrollments
- [ ] Test admin-only access to admin routes
- [ ] Test validation and error flows for admin forms

#### Phase 5: Payment & Webhook Integration
- [ ] Write tests for payment creation and Stripe session initiation
- [ ] Mock and test Stripe API requests and error scenarios
- [ ] Write tests for webhook endpoint: verification, handling relevant events, updating enrollment/payment status

#### Phase 6: Access Control & Security
- [ ] Test all routes and LiveViews for correct access guards (admin, student, public)
- [ ] Test data leaks (students cannot access other students’ courses or lessons)
- [ ] Test role transitions, edge cases, and session resets

#### Phase 7: End-to-End & Regression
- [ ] Implement “happy path” tests for: student enrollment (free & paid), course completion, admin management
- [ ] Add tests for common regressions (i.e., payment failures, deleted courses, lesson reordering)

#### Phase 8: Documentation & Coverage
- [ ] Document test setup, factories, and major flows in README or docs
- [ ] Achieve and verify near 100% test coverage for business logic, context, and UI
- [ ] Establish CI job running `mix precommit` and all tests

---

_Treat this checklist as an evolving reference. Refine tasks as architecture and requirements develop._
