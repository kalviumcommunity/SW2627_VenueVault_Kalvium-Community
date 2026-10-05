# Product Requirements Document (PRD)
## Event Equipment Rental & Dispatch Management System

### 1. Product Overview

**Product Name:** EventGear Manager

**Product Type:** Web-based equipment rental and scheduling management system

**Target Users:** Regional event equipment rental companies

**Primary Goal:** Prevent equipment overbooking and dispatch conflicts by replacing phone-based coordination with a centralized system that provides real-time equipment availability, booking management, and warehouse dispatch scheduling.

---

## 2. Problem Statement

A regional event equipment rental company supplies **sound systems, lighting equipment, furniture, and other event equipment** for weddings and corporate events.

Currently, bookings and dispatch schedules are coordinated primarily through **individual phone calls and informal communication**. This creates several problems:

- The same equipment can accidentally be promised to multiple events.
- Staff do not have a centralized view of upcoming bookings.
- Conflicts are often discovered only when warehouse staff start preparing equipment.
- Last-minute changes are difficult to communicate.
- Employees spend significant time calling each other to verify availability.
- Management has limited visibility into equipment utilization.
- Manual coordination becomes especially difficult during peak wedding/event seasons.

### Core Problem

> **The company needs a centralized system that knows which equipment is available, booked, dispatched, or returned at any given time and prevents overlapping commitments.**

---

# 3. Product Vision

Build a centralized rental management platform where employees can:

> **Check availability → Create booking → Reserve equipment → Schedule dispatch → Track return**

The system should detect conflicts **before a booking is confirmed**, rather than discovering them at the warehouse.

---

# 4. Goals & Objectives

### Primary Goals

1. Prevent double-booking of equipment.
2. Provide real-time equipment availability.
3. Centralize all event bookings.
4. Provide a clear dispatch schedule for warehouse staff.
5. Reduce dependency on phone calls and manual coordination.
6. Detect scheduling conflicts automatically.
7. Track equipment from booking through return.
8. Provide management with equipment utilization insights.

### Success Metrics

| Metric | Target |
|---|---:|
| Equipment double-bookings | 0 |
| Booking conflict detection | 100% |
| Reduction in coordination calls | 50%+ |
| Dispatch preparation errors | <5% |
| Booking creation time | <3 minutes |
| Equipment availability accuracy | >99% |

---

# 5. User Personas

### 5.1 Booking Staff

Responsible for receiving customer requests and creating bookings.

**Needs:**
- Quickly check availability.
- Create and modify bookings.
- See conflicting bookings.
- Know what equipment is available.

### 5.2 Warehouse Manager

Responsible for preparing equipment for events.

**Needs:**
- Daily dispatch schedule.
- Equipment picking list.
- Return schedule.
- Know exactly what equipment needs to leave the warehouse.

### 5.3 Delivery/Dispatch Staff

Responsible for delivering and collecting equipment.

**Needs:**
- Delivery schedule.
- Event location.
- Equipment checklist.
- Dispatch status.

### 5.4 Manager/Admin

Responsible for overall operations.

**Needs:**
- View all bookings.
- Manage inventory.
- Monitor equipment utilization.
- Resolve conflicts.
- View reports.

### 5.5 Customer

The customer organizing the event.

**Needs:**
- Provide event details.
- Request required equipment.
- Receive booking confirmation.
- Know delivery and pickup details.

---

# 6. Core User Journey

```text
Customer Request
       ↓
Booking Staff Creates Event
       ↓
Select Required Equipment
       ↓
System Checks Availability
       ↓
 ┌───────────────┐
 │ Available?    │
 └───────┬───────┘
     Yes │ No
         │
         ↓
    Show Conflict
         │
         ↓
Suggest Alternatives
```

If available:

```text
Confirm Booking
      ↓
Reserve Equipment
      ↓
Generate Dispatch Schedule
      ↓
Warehouse Picks Equipment
      ↓
Equipment Dispatched
      ↓
Event Completed
      ↓
Equipment Returned
      ↓
Equipment Available Again
```

---

# 7. Functional Requirements

## 7.1 User Authentication

The system should support role-based authentication.

### Roles

- Admin
- Booking Staff
- Warehouse Staff
- Dispatch Staff
- Manager

Each role should have appropriate permissions.

| Feature | Admin | Booking | Warehouse | Dispatch |
|---|---|---|---|---|
| Create Booking | ✅ | ✅ | ❌ | ❌ |
| Modify Booking | ✅ | ✅ | ❌ | ❌ |
| Manage Equipment | ✅ | ❌ | ✅ | ❌ |
| View Schedule | ✅ | ✅ | ✅ | ✅ |
| Dispatch Equipment | ✅ | ❌ | ✅ | ✅ |
| Reports | ✅ | ❌ | ❌ | ❌ |

---

# 8. Equipment Management

Admins should be able to manage all rental equipment.

### Equipment Fields

```text
Equipment ID
Name
Category
Quantity
Available Quantity
Condition
Location
Status
Rental Price
Description
```

### Equipment Categories

- Sound Systems
- Speakers
- Microphones
- Amplifiers
- LED Lights
- Stage Lights
- Tables
- Chairs
- Sofas
- Projectors
- Generators

### Equipment Status

```text
Available
Reserved
Dispatched
Under Maintenance
Damaged
Retired
```

---

# 9. Inventory Availability

The system should calculate equipment availability based on existing bookings.

For example:

### Inventory

```text
Wireless Microphones: 10
```

### Booking A

```text
June 10
Required: 4
```

### Booking B

```text
June 10
Required: 5
```

Remaining:

```text
10 - 4 - 5 = 1
```

The system should allow another booking requiring **1 microphone**, but reject a booking requiring **2 microphones**.

---

# 10. Booking Management

Staff should be able to create an event booking.

### Booking Information

```text
Booking ID
Customer Name
Customer Contact
Event Name
Event Type
Event Date
Event Start Time
Event End Time
Venue
Required Equipment
Delivery Time
Pickup Time
Assigned Staff
Booking Status
Notes
```

### Event Types

- Wedding
- Corporate Event
- Birthday
- Concert
- Conference
- Exhibition
- Other

---

# 11. Conflict Detection

This is the **most important feature** of the system.

Before confirming a booking, the system should check:

> Does another booking require the same equipment during an overlapping period?

### Example

Existing booking:

```text
Wedding A
10 Oct
4 PM – 11 PM

10 Speakers
```

New booking:

```text
Corporate Event B
10 Oct
6 PM – 9 PM

8 Speakers
```

If only 12 speakers exist:

```text
10 + 8 = 18

Available = 12
Required = 18
```

The system should prevent confirmation.

### Conflict Message

```text
⚠ Equipment Conflict

8 Speakers are requested for this booking.

Only 2 speakers are available during:
10 Oct, 6:00 PM – 9:00 PM

Existing booking:
Wedding A
4:00 PM – 11:00 PM
```

---

# 12. Alternative Suggestions

Instead of simply rejecting the booking, the system should suggest alternatives.

For example:

```text
⚠ Speakers unavailable

Possible alternatives:

• 2 PM – 5 PM
• 11 PM – 2 AM
• Use 6 available speakers
• Replace with Sound System B
• Check another equipment branch
```

---

# 13. Dispatch Management

Once a booking is confirmed, the system should automatically create a dispatch task.

### Dispatch Details

```text
Dispatch ID
Booking ID
Event
Venue
Dispatch Date
Dispatch Time
Equipment List
Assigned Staff
Vehicle
Status
```

### Dispatch Status

```text
Pending
Preparing
Ready
Dispatched
Delivered
Returned
Completed
```

---

# 14. Warehouse Dashboard

The warehouse should have a dedicated dashboard.

### Today's Dispatches

```text
------------------------------------------------
Today's Dispatches

09:00 AM
Wedding - Sharma
Jaipur
12 Speakers
40 Chairs
Status: Preparing

11:30 AM
Corporate Event - ABC Pvt Ltd
Jaipur
2 Projectors
10 Microphones
Status: Ready

04:00 PM
Wedding - Singh
Jaipur
20 Chairs
6 Lights
Status: Pending
------------------------------------------------
```

---

# 15. Equipment Picking List

For every dispatch, warehouse staff should receive a checklist.

Example:

```text
Wedding - Sharma

☐ Speaker × 12
☐ Microphone × 4
☐ Amplifier × 2
☐ LED Light × 8
☐ Power Cable × 10

[Mark Ready]
```

This reduces the possibility of equipment being forgotten during loading.

---

# 16. Return Management

When equipment returns to the warehouse, staff should record:

```text
Returned Equipment
Quantity
Condition
Damage
Missing Items
Return Time
Notes
```

Example:

```text
12 Speakers dispatched

Returned: 12
Damaged: 1
Missing: 0

Status → Maintenance
```

The damaged equipment should automatically become unavailable for future bookings.

---

# 17. Calendar View

The application should provide a calendar displaying:

- Events
- Equipment reservations
- Dispatches
- Returns

Example:

```text
        MON     TUE     WED     THU

Morning   E1      E2      -       E4

Afternoon E1      E3      E5      E4

Evening   E1      E3      E5      -
```

Users should be able to click an event to see its complete booking information.

---

# 18. Notifications

The system should notify relevant employees about important events.

### Notifications

- New booking created
- Booking modified
- Booking cancelled
- Equipment conflict
- Dispatch approaching
- Equipment not returned
- Equipment damaged
- Booking requires attention

Example:

> 🔔 **Dispatch Reminder:** Wedding Sharma's equipment must be ready for dispatch at 9:00 AM tomorrow.

---

# 19. Booking Modification

Staff should be able to modify:

- Event date
- Event time
- Equipment quantity
- Venue
- Customer details

Whenever a booking is modified, the system should **run the availability check again**.

---

# 20. Booking Cancellation

When a booking is cancelled:

```text
Booking → Cancelled
        ↓
Equipment reservation released
        ↓
Inventory becomes available
```

The system should maintain cancellation history.

---

# 21. Dashboard

The main dashboard should provide an operational overview.

### KPIs

```text
Today's Events           12

Equipment Reserved       78%

Pending Dispatches        5

Equipment in Maintenance 7

Overdue Returns           2
```

### Dashboard Sections

- Today's events
- Upcoming events
- Pending dispatches
- Equipment conflicts
- Overdue returns
- Equipment utilization
- Recent bookings

---

# 22. Search & Filtering

Users should be able to search by:

### Booking

- Customer name
- Booking ID
- Event type
- Date

### Equipment

- Equipment name
- Category
- Equipment ID
- Status

### Filters

```text
Date
Status
Event Type
Equipment Category
Assigned Staff
```

---

# 23. Reporting

Managers should be able to view:

### Equipment Utilization

```text
Equipment          Utilization

Speakers              87%
Microphones           72%
LED Lights             91%
Chairs                 65%
Projectors             54%
```

### Reports

- Most rented equipment
- Equipment utilization
- Revenue by event
- Revenue by equipment
- Cancelled bookings
- Damaged equipment
- Overdue returns
- Peak booking periods

---

# 24. Non-Functional Requirements

### Performance

- Dashboard should load within 2–3 seconds.
- Availability checks should return within 1 second under normal load.
- System should support multiple employees simultaneously.

### Reliability

The system must maintain accurate equipment availability even when multiple employees create bookings simultaneously.

### Security

- Secure authentication.
- Role-based authorization.
- Password hashing.
- Input validation.
- Audit logs for booking changes.

### Availability

Target:

> **99.5% system availability**

during business operations.

### Scalability

The system should initially support:

```text
50+ employees
10,000+ equipment records
100,000+ bookings
```

and be designed so capacity can grow later.

---

# 25. Audit Log

The system should record major actions.

Example:

```text
10:32 AM
Rahul created Booking #BK1024

10:35 AM
Rahul added 10 speakers

10:40 AM
Priya modified event time

10:41 AM
System detected equipment conflict
```

This helps management determine **who changed what and when**.

---

# 26. MVP Scope

For the first version, focus on the features directly solving the problem.

### MVP Features

1. **Authentication**
   - Login
   - Role-based access

2. **Equipment Management**
   - Add equipment
   - Update equipment
   - View availability

3. **Booking Management**
   - Create booking
   - Edit booking
   - Cancel booking

4. **Conflict Detection**
   - Date/time overlap detection
   - Quantity-based availability

5. **Calendar**
   - Booking calendar
   - Equipment reservations

6. **Dispatch**
   - Dispatch schedule
   - Equipment checklist
   - Dispatch status

7. **Returns**
   - Return equipment
   - Record damage/missing items

8. **Dashboard**
   - Upcoming events
   - Dispatches
   - Equipment availability

---

# 27. Future Features

### Customer Portal

Customers can browse equipment, request quotes, confirm bookings, and track deliveries.

### Online Payments

Integrate UPI, cards, and payment gateways.

### Automated WhatsApp Notifications

Send customers and staff delivery and booking updates.

### Route Optimization

Optimize delivery routes when multiple events occur on the same day.

### Multiple Warehouse Support

Track equipment across different warehouse locations.

### QR/Barcode Tracking

Scan equipment through:

```text
Warehouse → Vehicle → Event → Warehouse
```

### Demand Forecasting

Use historical bookings to predict equipment demand during peak periods.

---

# 28. Key Business Rules

### Rule 1 — No Overbooking

```text
Total Reserved Quantity
≤
Total Available Quantity
```

### Rule 2 — Time Overlap Matters

Two bookings only conflict when their rental periods overlap.

### Rule 3 — Cancelled Bookings Don't Reserve Equipment

### Rule 4 — Dispatched Equipment Is Unavailable

### Rule 5 — Damaged Equipment Is Unavailable

### Rule 6 — Returned Equipment Becomes Available Only After Inspection

### Rule 7 — Booking Changes Trigger Availability Revalidation

### Rule 8 — Concurrent Bookings Must Be Transaction-Safe

Two employees might simultaneously try to reserve the last available equipment. The backend must ensure that both requests cannot successfully reserve the same inventory.

---

# 29. Suggested System Architecture

```text
                    ┌──────────────┐
                    │   Frontend   │
                    │ React / Web  │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │     API      │
                    │ Node/Express │
                    └──────┬───────┘
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
       Booking         Inventory       Dispatch
       Service          Service         Service
            │              │              │
            └──────────────┼──────────────┘
                           ▼
                    ┌──────────────┐
                    │   Database   │
                    │              │
                    │ Users        │
                    │ Equipment    │
                    │ Bookings     │
                    │ Reservations │
                    │ Dispatches   │
                    │ Returns      │
                    └──────────────┘
```

---

# 30. Core Data Models

### User

```text
User
 ├── id
 ├── name
 ├── email
 ├── password
 └── role
```

### Equipment

```text
Equipment
 ├── id
 ├── name
 ├── category
 ├── totalQuantity
 ├── availableQuantity
 ├── status
 └── rentalPrice
```

### Booking

```text
Booking
 ├── id
 ├── customer
 ├── eventType
 ├── startDateTime
 ├── endDateTime
 ├── venue
 └── status
```

### BookingItem

```text
BookingItem
 ├── bookingId
 ├── equipmentId
 └── quantity
```

### Dispatch

```text
Dispatch
 ├── id
 ├── bookingId
 ├── dispatchTime
 ├── assignedStaff
 └── status
```

### Return

```text
Return
 ├── id
 ├── bookingId
 ├── returnTime
 ├── condition
 ├── damagedQuantity
 └── missingQuantity
```

---

# 31. Critical Availability Logic

```text
Requested Equipment
        +
Requested Date/Time
        ↓
Find overlapping bookings
        ↓
Calculate reserved quantity
        ↓
Compare with total inventory
        ↓
 ┌─────────────────────┐
 │ Available Quantity  │
 │ >= Requested Qty?   │
 └──────────┬──────────┘
            │
       ┌────┴────┐
      YES        NO
       │          │
       ▼          ▼
   Allow       Reject
   Booking     Booking
                 │
                 ▼
          Show Conflict
```

This is the **central business logic of the product**.

---

# 32. Out of Scope for MVP

The following should not be included initially:

- Full accounting system
- Payroll
- Advanced CRM
- AI-based demand prediction
- Online payment processing
- Route optimization
- Customer mobile application
- Multi-company marketplace

---

# 33. Acceptance Criteria

### Booking

- Staff can create a booking.
- Staff can select multiple equipment types.
- System checks availability before confirmation.
- System prevents conflicting bookings.

### Inventory

- Equipment quantity is tracked.
- Reserved equipment is not counted as available.
- Returned equipment can become available.
- Damaged equipment is excluded from available inventory.

### Dispatch

- Confirmed bookings appear in the dispatch dashboard.
- Warehouse staff can see the equipment checklist.
- Dispatch status can be updated.

### Conflict Detection

Given:

```text
Inventory = 10 speakers

Booking A = 7 speakers
10 AM – 6 PM

Booking B = 4 speakers
2 PM – 5 PM
```

The system must reject Booking B because:

```text
7 + 4 = 11 > 10
```

---

# 34. Product Success Definition

The product is successful if the company can move from:

> **"Let me call the warehouse and check whether those speakers are free."**

to:

> **"The system already knows whether those speakers are available."**

The most important outcome is therefore **not simply digitizing bookings**. It is creating a **single source of truth for equipment availability and scheduling**, so that an equipment conflict is detected **before it reaches the warehouse loading stage**.
