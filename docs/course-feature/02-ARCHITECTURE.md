# Course Feature - Visual Architecture Summary

## System Flow Diagram

```
                                    ┌─────────────────┐
                                    │   Guest User    │
                                    └────────┬────────┘
                                             │
                                             │ Browse courses
                                             ▼
                    ┌────────────────────────────────────────────┐
                    │         Public Course Catalog              │
                    │  /courses (List) | /courses/:id (Detail)   │
                    └────────────────────────────────────────────┘
                                             │
                     ┌───────────────────────┼───────────────────────┐
                     │                       │                       │
            Login Required            Free Course            Paid Course
                     │                       │                       │
                     ▼                       ▼                       ▼
            ┌────────────────┐      ┌───────────────┐      ┌───────────────┐
            │ Authentication │      │ Auto-Enroll   │      │ Stripe        │
            │                │      │               │      │ Checkout      │
            └───────┬────────┘      └───────┬───────┘      └───────┬───────┘
                    │                       │                       │
                    └───────────────────────┴───────────────────────┘
                                             │
                                             ▼
                                    ┌────────────────┐
                                    │  Enrollment    │
                                    │   Created      │
                                    └────────┬───────┘
                                             │
                                             ▼
                    ┌────────────────────────────────────────────┐
                    │         Student Course Area                │
                    │  /my-courses (List) | Lessons (View)       │
                    └────────────────────────────────────────────┘
                                             │
                                             │ Track Progress
                                             ▼
                                    ┌────────────────┐
                                    │ Complete       │
                                    │ Certificate    │
                                    └────────────────┘


                                    ┌─────────────────┐
                                    │   Admin User    │
                                    └────────┬────────┘
                                             │
                                             ▼
                    ┌────────────────────────────────────────────┐
                    │         Admin Dashboard                    │
                    │  /admin/courses (CRUD)                     │
                    └────────┬───────────────────┬───────────────┘
                             │                   │
                    ┌────────▼────────┐  ┌───────▼────────┐
                    │  Manage Courses │  │  Manage        │
                    │  + Lessons      │  │  Enrollments   │
                    └─────────────────┘  └────────────────┘
```

## Data Flow - Payment Process

```
   User                Frontend               Backend              Stripe
     │                     │                      │                  │
     │  Click "Purchase"   │                      │                  │
     ├────────────────────►│                      │                  │
     │                     │ POST /checkout       │                  │
     │                     ├─────────────────────►│                  │
     │                     │                      │ Create Session   │
     │                     │                      ├─────────────────►│
     │                     │                      │ Session ID       │
     │                     │                      │◄─────────────────┤
     │                     │ Redirect URL         │                  │
     │                     │◄─────────────────────┤                  │
     │  Redirect to Stripe │                      │                  │
     ├────────────────────────────────────────────┼─────────────────►│
     │                     │                      │                  │
     │  Enter Payment Info │                      │                  │
     ├────────────────────────────────────────────┼─────────────────►│
     │                     │                      │                  │
     │  Confirm            │                      │                  │
     ├────────────────────────────────────────────┼─────────────────►│
     │                     │                      │                  │
     │                     │                      │   Webhook        │
     │                     │                      │◄─────────────────┤
     │                     │                      │                  │
     │                     │                      │  Verify          │
     │                     │                      │  Create Payment  │
     │                     │                      │  Create Enroll   │
     │                     │                      │                  │
     │  Redirect to Success│                      │                  │
     │◄────────────────────┴──────────────────────┤                  │
     │                     │                      │                  │
     │  View Course        │                      │                  │
     ├────────────────────►│                      │                  │
     │                     │  Verify Access       │                  │
     │                     ├─────────────────────►│                  │
     │                     │  ✓ Enrolled          │                  │
     │                     │◄─────────────────────┤                  │
     │  Course Content     │                      │                  │
     │◄────────────────────┤                      │                  │
```

## Entity Relationship Diagram

```
┌──────────────────┐              ┌──────────────────┐
│     users        │              │     courses      │
├──────────────────┤              ├──────────────────┤
│ PK id            │              │ PK id            │
│    email         │              │    title         │
│    role          │◄────────┐    │    description   │
│    ...           │         │    │    body          │
└──────────────────┘         │    │    price         │
                             │    │    currency      │
                             │    │    stripe_*      │
                             │    │    published     │
                             │    └────────┬─────────┘
                             │             │
                             │             │ 1:N
                             │             │
                  N:1        │             ▼
        ┌──────────────────┐ │    ┌──────────────────┐
        │  enrollments     │ │    │    lessons       │
        ├──────────────────┤ │    ├──────────────────┤
        │ PK id            │ │    │ PK id            │
        │ FK user_id       ├─┘    │ FK course_id     │
        │ FK course_id     ├──────┤    title         │
        │    status        │ 1:N  │    content       │
        │    enrolled_at   │      │    order         │
        │    completed_at  │      │    duration      │
        └──────────────────┘      │    published     │
                  │               └────────┬─────────┘
                  │                        │
                  │                        │ 1:N
                  │                        │
                  │               ┌────────▼─────────┐
                  │               │ lesson_progress  │
                  │               ├──────────────────┤
                  │               │ PK id            │
                  │               │ FK user_id       │
                  └───────────────┤ FK lesson_id     │
                            N:1   │    completed     │
                                  │    completed_at  │
        ┌──────────────────┐      │    notes         │
        │    payments      │      └──────────────────┘
        ├──────────────────┤
        │ PK id            │
        │ FK user_id       │
        │ FK course_id     │
        │    amount        │
        │    currency      │
        │    stripe_*      │
        │    status        │
        │    metadata      │
        └──────────────────┘
```

## Access Control Decision Tree

```
                        User wants to access course/lesson
                                     │
                                     ▼
                            ┌────────────────┐
                            │  Is user admin? │
                            └────────┬────────┘
                                     │
                        ┌────────────┴────────────┐
                        │                         │
                       YES                       NO
                        │                         │
                        ▼                         ▼
                   ┌─────────┐         ┌──────────────────┐
                   │ ALLOW   │         │  Is course free?  │
                   │ ACCESS  │         │  (price = 0)      │
                   └─────────┘         └─────────┬──────────┘
                                                  │
                                     ┌────────────┴────────────┐
                                     │                         │
                                    YES                       NO
                                     │                         │
                                     ▼                         ▼
                        ┌──────────────────────┐   ┌───────────────────┐
                        │ Is user authenticated?│   │ Is user enrolled? │
                        └──────────┬────────────┘   └─────────┬─────────┘
                                   │                          │
                      ┌────────────┴────────────┐ ┌───────────┴──────────┐
                      │                         │ │                      │
                     YES                       NO YES                   NO
                      │                         │  │                      │
                      ▼                         ▼  ▼                      ▼
                 ┌─────────┐             ┌─────────────┐          ┌──────────┐
                 │ ALLOW   │             │ DENY ACCESS │          │  DENY    │
                 │ ACCESS  │             │ (Redirect)  │          │  ACCESS  │
                 └─────────┘             └─────────────┘          │ (Show    │
                                                                  │ Purchase)│
                                                                  └──────────┘
```

## Feature Phases

```
Phase 1: Foundation              Phase 2: Core Features         Phase 3: Advanced
├─ Migrations                    ├─ Admin Course CRUD           ├─ Lesson Progress
├─ Schemas                       ├─ Public Course Listing       ├─ Completion Certs
├─ Basic Context                 ├─ Student Area                ├─ Course Reviews
└─ Unit Tests ✓                  ├─ Access Control              ├─ Course Preview
                                 ├─ Basic Enrollment            ├─ Bulk Enrollments
                                 └─ Integration Tests ✓         └─ Analytics

Phase 4: Payments                Phase 5: Polish                Phase 6: Optimization
├─ Payment Model                 ├─ UI/UX Refinements           ├─ Caching Strategy
├─ Stripe Integration            ├─ Email Notifications         ├─ Database Indexes
├─ Checkout Flow                 ├─ Admin Dashboard             ├─ Query Optimization
├─ Webhook Handler               ├─ Payment History             ├─ Performance Tests
└─ Payment Tests ✓               └─ Error Handling              └─ Load Testing
```

## Key Contexts & Their Responsibilities

```
┌─────────────────────────────────────────────────────────────────┐
│                         Alchemistdrops                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────┐         │
│  │  Courses Context                                   │         │
│  ├───────────────────────────────────────────────────┤         │
│  │  Responsibilities:                                 │         │
│  │  • Course CRUD operations                          │         │
│  │  • Lesson CRUD operations                          │         │
│  │  • Publishing/unpublishing                         │         │
│  │  • Course querying and filtering                   │         │
│  │  • Lesson ordering                                 │         │
│  │                                                     │         │
│  │  Schemas: Course, Lesson                           │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                 │
│  ┌───────────────────────────────────────────────────┐         │
│  │  Enrollments Context                               │         │
│  ├───────────────────────────────────────────────────┤         │
│  │  Responsibilities:                                 │         │
│  │  • User enrollment management                      │         │
│  │  • Access control verification                     │         │
│  │  • Enrollment status tracking                      │         │
│  │  • Progress tracking (optional)                    │         │
│  │  • Completion tracking                             │         │
│  │                                                     │         │
│  │  Schemas: Enrollment, LessonProgress               │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                 │
│  ┌───────────────────────────────────────────────────┐         │
│  │  Payments Context                                  │         │
│  ├───────────────────────────────────────────────────┤         │
│  │  Responsibilities:                                 │         │
│  │  • Payment record management                       │         │
│  │  • Stripe API integration                          │         │
│  │  • Checkout session creation                       │         │
│  │  • Webhook processing                              │         │
│  │  • Payment verification                            │         │
│  │  • Enrollment creation on payment                  │         │
│  │                                                     │         │
│  │  Schemas: Payment                                  │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                 │
│  ┌───────────────────────────────────────────────────┐         │
│  │  Accounts Context (Existing)                       │         │
│  ├───────────────────────────────────────────────────┤         │
│  │  Responsibilities:                                 │         │
│  │  • User management                                 │         │
│  │  • Authentication                                  │         │
│  │  • Role-based access                               │         │
│  │                                                     │         │
│  │  Schemas: User                                     │         │
│  │  Roles: admin, user, student                       │         │
│  └───────────────────────────────────────────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Test Coverage Goals

```
Context Layer Tests:
├─ Courses Context      ▓▓▓▓▓▓▓▓▓▓ 100%
├─ Enrollments Context  ▓▓▓▓▓▓▓▓▓▓ 100%
├─ Payments Context     ▓▓▓▓▓▓▓▓▓▓ 100%
└─ Integration          ▓▓▓▓▓▓▓░░░  80%

LiveView Tests:
├─ Admin Area          ▓▓▓▓▓▓▓▓▓░  90%
├─ Public Area         ▓▓▓▓▓▓▓▓▓░  90%
├─ Student Area        ▓▓▓▓▓▓▓▓▓░  90%
└─ Payment Flow        ▓▓▓▓▓▓▓▓▓░  90%

Overall Goal:          ▓▓▓▓▓▓▓▓▓░  90%+
```

