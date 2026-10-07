# Product Requirements Document (PRD)
## VenueVault — Event Equipment Booking, Inventory & Dispatch Management

### 1. Product Overview

**Product Name:** VenueVault

**Product Type:** Web-based operations platform for equipment rental and event logistics

**Target Users:** Event rental businesses, warehouse teams, dispatch coordinators, and operations managers serving weddings, corporate events, conferences, and venue-based productions.

**Primary Goal:** Replace fragmented coordination with a centralized system that provides reliable inventory visibility, booking control, dispatch planning, and return tracking across the full rental lifecycle.

VenueVault helps teams answer a critical operational question in seconds: “Is this equipment available, reserved, or already assigned to another event during the required time window?”

---

## 2. Problem Statement

A regional event equipment rental company handles large, time-sensitive event setups that depend on sound systems, lighting, furniture, staging, and accessories. Today, bookings are coordinated through phone calls, WhatsApp messages, spreadsheets, and memory-heavy manual scheduling.

This operational model creates recurring issues:

- The same equipment can be promised to multiple events.
- Warehouse teams do not have a single source of truth for upcoming dispatches.
- Availability is checked too late, often after a customer has already been verbally committed.
- Dispatch lists are manually built and easy to miss items from.
- Returns and damage tracking are inconsistent.
- Managers cannot easily measure utilization, stock risk, or overdue equipment.
- Peak season demand increases the chance of cross-team confusion and revenue loss.

### Core Business Problem

> The business needs a system that can track equipment availability in real time across bookings, dispatches, and returns so that commitments remain accurate and operational conflicts are caught before they reach the warehouse floor.

---

## 3. Product Vision

VenueVault will be the operational control center for all event equipment movement across a rental business.

The product will support the full workflow:

> Check inventory → create booking → validate availability → reserve equipment → schedule dispatch → deliver to venue → track return → make stock available again

The system must stop bad commitments before they become expensive operational failures.

---

## 4. Goals and Objectives

### Primary Goals

1. Prevent double-booking of equipment.
2. Provide accurate, up-to-date availability across all inventory.
3. Centralize customer bookings and rental coordination.
4. Reduce manual phone-based coordination across teams.
5. Give warehouse and dispatch teams a clear view of what must be loaded and delivered.
6. Track equipment status from booking to return and maintenance.
7. Improve operational visibility for management and finance teams.
8. Support scale during seasonal peaks without adding chaos.

### Success Metrics

- 0 double-booked equipment instances across overlapping periods
- 100% of booking attempts checked against inventory and time overlap rules
- 50% reduction in manual coordination calls between staff
- Less than 5% dispatch preparation errors
- Average booking creation time under 3 minutes
- Inventory accuracy above 99%
- 90% of staff using the same live operational view for active bookings

---

## 5. Target Users and Personas

### 5.1 Booking Coordinator

Responsible for receiving customer requests, capturing event details, and creating bookings.

Needs:
- Quick availability validation
- Ability to create, revise, and cancel bookings
- Clear visibility into conflicting reservations
- Fast access to event equipment history

### 5.2 Warehouse Manager

Responsible for preparing equipment for dispatch and checking inventory readiness.

Needs:
- Daily dispatch overview
- Packing checklist for each event
- Ability to mark items as ready, packed, or missing
- Clear return and damage status at the end of a booking

### 5.3 Dispatch Team

Responsible for loading, delivering, and collecting equipment.

Needs:
- Delivery timeline and venue address
- Equipment list per job
- Pickup and return schedule
- Status updates for each assigned dispatch

### 5.4 Operations Manager

Responsible for day-to-day execution and cross-team coordination.

Needs:
- Unified dashboard view of events, stock, conflicts, and returns
- Reporting on utilization and overdue equipment
- Ability to resolve blocking issues quickly

### 5.5 Customer / Event Planner

The person requesting equipment for an event.

Needs:
- Confirmation of booking details
- Visibility into equipment quantities and timing
- Confidence that the company has reserved the correct items
- Communication on delivery and pickup

---

## 6. Core User Journey

```text
Customer request
    ↓
Booking coordinator captures event details
    ↓
Coordinator selects equipment and quantity
    ↓
System checks inventory and time overlap
    ↓
If available:
    - reserve stock
    - create dispatch task
    - notify warehouse
    ↓
Warehouse prepares equipment
    ↓
Dispatch team delivers to venue
    ↓
Event completes
    ↓
Equipment returned and inspected
    ↓
Inventory restored for future bookings
```

If unavailable:

```text
System identifies conflict
    ↓
Shows shortage quantity and overlapping bookings
    ↓
Suggests alternative time slots or substitute equipment
    ↓
Coordinator can adjust or escalate for approval
```

---

## 7. Functional Requirements

### 7.1 Authentication and Authorization

The system must support role-based login for the following roles:

- Admin
- Booking Staff
- Warehouse Staff
- Dispatch Staff
- Operations Manager

Required permission model:

- Admin: full access to all modules and settings
- Booking Staff: create and edit bookings, view inventory, limited reporting
- Warehouse Staff: manage dispatch checklist, stock status, returns, maintenance
- Dispatch Staff: view assigned deliveries and pickups, update status
- Operations Manager: dashboard, reports, approvals, conflict resolution

### 7.2 Equipment Management

The system should support management of every rental item in the catalog.

Required fields:

- Equipment ID
- Name
- Category
- Total quantity
- Available quantity
- Condition
- Status
- Warehouse location
- Rental price
- Description
- Maintenance notes

Supported categories may include:

- Audio systems
- Speakers
- Microphones
- Amplifiers
- LED lights
- Stage lighting
- Tables
- Chairs
- Sofas
- Projectors
- Generators
- Accessories and cables

Supported status values:

- Available
- Reserved
- Dispatched
- In use
- Under maintenance
- Damaged
- Retired

### 7.3 Booking Management

Staff must be able to create, modify, and cancel bookings.

Required booking details:

- Booking ID
- Customer name
- Customer contact
- Event name
- Event type
- Event date
- Start time
- End time
- Venue
- Equipment list with quantity by item
- Delivery time
- Pickup time
- Assigned staff
- Booking status
- Internal notes
- Special instructions

Supported event types:

- Wedding
- Corporate event
- Birthday
- Concert
- Conference
- Exhibition
- Other

### 7.4 Inventory Availability Logic

The system must calculate available inventory by item and time period.

A booking should only be confirmed if the following condition is met:

```text
Reserved quantity for overlapping bookings + requested quantity <= total inventory
```

Example:

```text
Inventory: 10 wireless microphones
Booking A: 4 microphones, 10 Jun, 2 PM–8 PM
Booking B: 5 microphones, 10 Jun, 4 PM–9 PM
Remaining inventory: 1 microphone
```

The system should allow a new booking requiring 1 microphone, but reject a booking requiring 2 or more.

### 7.5 Conflict Detection

This is the core product feature.

Before confirming a booking, the system must compare the proposed booking against all overlapping bookings for the same equipment category or item.

If the requested inventory exceeds available stock during the overlapping period, the system must:

- block booking confirmation
- show the conflicting item quantity
- show the overlapping bookings
- display the exact unavailable time window
- recommend alternative time slots or substitute equipment where relevant

Example conflict message:

```text
Equipment conflict: 8 speakers requested for this booking.
Only 2 speakers are available between 6:00 PM and 9:00 PM on 10 Oct.
Conflicting active booking: Wedding A, 4:00 PM–11:00 PM
Suggested alternatives:
- shift start time to 2:00 PM
- reduce quantity to 6
- consider sound system B as a substitute
```

### 7.6 Dispatch Management

Once a booking is confirmed, the system must create a dispatch task automatically.

Required dispatch fields:

- Dispatch ID
- Booking ID
- Event name
- Venue
- Dispatch date
- Dispatch time
- Equipment checklist
- Assigned staff
- Vehicle or transport reference
- Status

Dispatch statuses:

- Pending
- Preparing
- Ready
- Dispatched
- Delivered
- Returned
- Completed

### 7.7 Equipment Picking List

Every dispatch should generate a packing checklist that warehouse staff can mark as complete.

Example:

```text
Wedding - Sharma
[ ] 12 Speakers
[ ] 4 Microphones
[ ] 2 Amplifiers
[ ] 8 LED Lights
[ ] 10 Power Cables
[ ] Mark ready for dispatch
```

### 7.8 Return and Damage Tracking

When equipment is returned, staff should record:

- Returned quantity
- Condition on return
- Damaged quantities
- Missing quantities
- Return time
- Notes

If any item is damaged or missing, the system should:

- flag inventory as unavailable until resolved
- update equipment status to maintenance or damaged
- log the issue for operations review

### 7.9 Calendar View

The application must provide a calendar showing:

- bookings
- equipment reservations
- dispatch tasks
- return schedules

Users should be able to click a booking to view complete details.

### 7.10 Notifications

Relevant users should receive notifications for:

- new booking created
- booking changed
- booking cancelled
- equipment conflict detected
- dispatch approaching
- overdue equipment return
- equipment marked damaged
- booking requiring review

### 7.11 Search and Filtering

Users should be able to search and filter by:

- customer name
- booking ID
- event type
- event date
- equipment name
- category
- status
- assigned staff
- venue

### 7.12 Reporting and Analytics

Managers should be able to view operational reports such as:

- equipment utilization
- most rented items
- revenue by event
- revenue by equipment category
- cancelled bookings
- damaged equipment
- overdue returns
- peak booking period analysis

---

## 8. Business Rules

### Rule 1 — No Overbooking

The sum of equipment reserved for overlapping bookings must never exceed total inventory.

### Rule 2 — Time Overlap Matters

Two bookings conflict only when they overlap in time and request the same item or category.

### Rule 3 — Cancelled Bookings Release Inventory

Cancelled bookings must release the previously reserved stock and remove it from active conflict checks.

### Rule 4 — Dispatched Equipment Is Unavailable

Items assigned to an active dispatch cannot be reserved for another booking unless returned and revalidated.

### Rule 5 — Damaged Items Are Not Available

Any item marked damaged or under maintenance is excluded from availability calculations until inspected and restored.

### Rule 6 — Equipment Returns Must Be Inspected

A returned item becomes available only after it is checked and marked ready.

### Rule 7 — Booking Changes Trigger Revalidation

Any update to dates, times, quantities, or venue should re-run the availability check.

### Rule 8 — Concurrent Booking Requests Must Be Safe

Two staff members may attempt to reserve the same last item at nearly the same time. The backend must enforce transactional locking or equivalent logic so both cannot successfully reserve the same stock.

### Rule 9 — Audit Trail Required

Every essential system action, including create, edit, cancel, conflict detection, and dispatch updates, must be recorded with user and timestamp.

---

## 9. Core Data Model

### User

```text
User
- id
- name
- email
- passwordHash
- role
- createdAt
```

### Equipment

```text
Equipment
- id
- name
- category
- totalQuantity
- availableQuantity
- condition
- status
- warehouseLocation
- rentalPrice
- description
- updatedAt
```

### Booking

```text
Booking
- id
- customerName
- customerContact
- eventName
- eventType
- startDateTime
- endDateTime
- venue
- status
- createdBy
- createdAt
- updatedAt
```

### BookingItem

```text
BookingItem
- id
- bookingId
- equipmentId
- quantity
- notes
```

### Dispatch

```text
Dispatch
- id
- bookingId
- dispatchDate
- dispatchTime
- assignedStaff
- status
- equipmentChecklist
- venue
```

### ReturnRecord

```text
ReturnRecord
- id
- bookingId
- returnedAt
- condition
- damagedQuantity
- missingQuantity
- notes
```

---

## 10. Critical Availability Logic

```text
Requested equipment + requested time window
        ↓
Find all overlapping bookings
        ↓
Calculate reserved quantity for matching inventory items
        ↓
Compare reserved quantity against total quantity
        ↓
If available quantity >= requested quantity
    → confirm booking
Else
    → reject and show conflicts + alternatives
```

This is the primary business decision engine of the product.

---

## 11. Non-Functional Requirements

### Performance

- Dashboard loads within 2–3 seconds under normal use.
- Availability validation returns in under 1 second for standard booking checks.
- The system supports multiple simultaneous employees without data inconsistency.

### Reliability

- Inventory availability must remain accurate even when multiple users create bookings concurrently.
- Failed or partial operations must be recoverable with audit logs.

### Security

- Secure login and session management
- Role-based authorization
- Password hashing
- Input validation on all forms
- Audit logs for booking changes and operational actions

### Availability

- Target 99.5% uptime during normal business operations
- System should remain usable during high-season booking spikes

### Scalability

The product should support:

- 50+ employees
- 10,000+ equipment records
- 100,000+ bookings
- growth in additional warehouse locations and event categories in later releases

---

## 12. MVP Scope

The first release should focus on the core operational problem: preventing overbooking and improving dispatch planning.

### In Scope for MVP

1. Authentication and role-based access
2. Equipment catalog management
3. Booking creation and editing
4. Booking cancellation
5. Time-based inventory validation
6. Conflict detection and explanation
7. Booking calendar
8. Dispatch generation and status tracking
9. Equipment return and damage recording
10. Dashboard with key operational KPIs

### Out of Scope for MVP

- full accounting or billing system
- payroll and employee management
- mobile app for customers
- AI forecasting
- route optimization
- payment processing
- multi-company marketplace
- advanced CRM integration

---

## 13. Release Plan

### Phase 1 — Core Operations

- user login and permissions
- equipment master data
- booking creation and validation
- conflict detection
- calendar and dashboard

### Phase 2 — Dispatch Execution

- dispatch checklist generation
- warehouse status management
- return management
- damage tracking
- audit trail improvements

### Phase 3 — Insights and Scale

- reporting and analytics
- exports and filtered views
- better inventory forecasting
- automation of alerts and notifications

---

## 14. Acceptance Criteria

### Booking workflow

- A staff member can create a booking with equipment, event time, venue, and customer details.
- Availability is checked before the booking is confirmed.
- A booking cannot be confirmed if it exceeds available inventory for an overlapping period.
- A booking can be updated and revalidated after edits.
- A cancelled booking releases equipment for future reservations.

### Inventory control

- Equipment quantities are tracked accurately.
- Reserved stock is deducted from availability calculations.
- Dispatched and damaged equipment is excluded from available stock until restored.
- Returned equipment becomes available only after inspection.

### Dispatch flows

- Confirmed bookings create a dispatch record automatically.
- Warehouse staff can view a checklist for each dispatch.
- Dispatch status can be updated from pending to completed.
- Returns create a traceable record tied to the original booking.

### Conflict handling

Given:

```text
Inventory = 10 speakers
Booking A = 7 speakers, 10 AM–6 PM
Booking B = 4 speakers, 2 PM–5 PM
```

The system must reject Booking B because:

```text
7 + 4 = 11 > 10
```

The system should show the conflicting booking and the exact shortage.

---

## 15. Product Success Definition

VenueVault is successful when the operational team can move from:

> “Let me call the warehouse and check whether those speakers are free.”

to:

> “The system already knows whether those speakers are available for the date and time requested.”

The most valuable outcome is not simply digital record-keeping. The real value is a single source of truth for equipment availability, dispatch readiness, and return status—so conflicts are prevented before the warehouse is forced to absorb them.

---

## 16. Key Risks and Assumptions

### Risks

- Staff may resist switching from informal coordination to a centralized system
- Data quality issues may cause inventory inaccuracies at launch
- Incomplete return tracking can create hidden stock losses
- Seasonal demand spikes may expose performance bottlenecks

### Assumptions

- The business already has a defined inventory catalog and categories
- Events are booked in advance with a known venue and schedule
- Staff can be trained on a single operational workflow
- The first version will prioritize reliability and accuracy over advanced AI or customer-facing features

---

## 17. Summary

VenueVault addresses a concrete and costly operational problem: equipment is being coordinated manually, availability is not always visible, and double-booking leads to preventable disruption. The product focuses on one primary outcome—accurate, real-time availability and assignment control across bookings, dispatch, and returns—while remaining practical enough for an MVP launch.

## 18.setup work(checklit)
1.flutter(check)
2.firebase(check)
3.android studio(in progress)