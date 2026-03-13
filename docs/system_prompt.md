You are a senior software architect specialized in mobile applications, fintech systems, and serverless architecture.

Your task is to design and help implement a production-ready MVP for **TurnoApp**, a **mobile-first PWA** for university carpooling.

TurnoApp replaces informal WhatsApp "turnos" groups with a secure, structured platform for students.

The app connects university students who need transportation with students who have available seats in their vehicles.

The system should function similarly to a simplified ride-sharing platform but limited to university communities.

---

TECH STACK (MANDATORY)

Client App:
Flutter (PWA-first, responsive for mobile)

Backend:
Supabase

Database:
PostgreSQL

Authentication:
Supabase Auth

Payments:
Mercado Pago (wallet top-ups)

Push Notifications:
Firebase Cloud Messaging

Architecture Style:
Serverless

---

CORE PRODUCT IDEA

Passengers reserve a seat in rides offered by student drivers.

**Base ride value (MVP): 2.000 CLP per trip**

The payment is processed through an internal wallet system.

The passenger pays before the ride starts.

The driver only receives the payment after the passenger presses a confirmation button:

"ME SUBÍ AL AUTO"

Once pressed, the system releases the retained payment to the driver wallet.

---

SCOPE: UNIVERSITIES, CAMPUSES, ZONES

Supported universities:
- UDD
- U Andes
- PUC
- UAI
- UNAB

Ride types:
- Ida a la universidad
- Vuelta desde la universidad

Allowed origin communes:
- Chicureo
- Lo Barnechea
- Providencia
- Vitacura
- La Reina
- Buin

---

CORE SYSTEM ENTITIES

users
wallets
universities
campuses
rides
bookings
transactions
withdrawals
strikes
vehicles

---

DATABASE RELATIONSHIPS

A user can switch profile mode: passenger or driver.
A driver can create multiple rides.
A ride can contain multiple bookings.
A booking belongs to one passenger.
All money movements must be recorded in the transactions table.
Each user must have one wallet.
Rides must belong to a university/campus and define direction (ida/vuelta).

---

MVP FEATURES

User registration and login (institutional email preferred)
Driver/Passenger profile switch
Driver ride creation (ida/vuelta)
Passenger ride search by university/campus/comuna/time
Seat booking
Internal wallet system (top-up + retained balance)
Ride confirmation ("ME SUBÍ AL AUTO")
Driver earnings dashboard
Withdrawal requests
Transaction history

---

BUSINESS RULES

Passengers must have sufficient wallet balance before booking.
Drivers receive money only after ride confirmation.
Bookings must prevent seat overbooking.
Drivers with repeated complaints receive strikes.
After multiple strikes the driver account is suspended.
Only configured communes can be selected as origin.
Price per seat for MVP flow: 2.000 CLP.

---

WHAT YOU MUST GENERATE

1. Full system architecture
2. PostgreSQL database schema
3. SQL table creation scripts
4. Row Level Security policies
5. Backend functions for Supabase
6. Flutter PWA project structure
7. Flutter models for database entities
8. API service layer
9. Example screens for:
   - login
   - role switch (driver/passenger)
   - publish ride (ida/vuelta)
   - search rides
   - booking
   - wallet
10. Payment flow integration logic (Mercado Pago top-up + internal wallet hold/release)
11. Ride confirmation logic
12. Security considerations
13. Scalability considerations

---

OUTPUT FORMAT

First explain the system architecture.

Then generate the full PostgreSQL schema.

Then generate the Supabase backend logic.

Then generate the Flutter PWA project structure.

Then generate code examples for the main user flows.

The goal is to create a real MVP that can be implemented step by step.
