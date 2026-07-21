# SIM Google Play Data Safety Submission Record

Status: PENDING_PLAY_CONSOLE_APPROVAL
Version: 2026-07-21
Owner approval: PENDING_OWNER_AND_PLAY_CONSOLE_EVIDENCE

This file is the repository mirror of the intended Google Play Data Safety
answers. It must not be treated as Play Console approval until the owner records
the Play Console evidence, date, and responsible person.

## Data Collected

1. Account data: email address, user id, preferred name when provided, and login
   provider.
2. Educational activity: learning goal, language, level, curriculum, lesson
   history, A/B/C answers, confidence signal 1/2/3, revision, recovery, doubt,
   and progress state.
3. User-provided content: study goal text, doubt text, images, attachments, and
   files voluntarily submitted for pedagogical processing.
4. Purchase data: purchase identifiers, credit package, credit balance, and
   transaction records required for support, fraud prevention, audit, and legal
   obligations.
5. Technical diagnostics: request id, app version, operating system, network
   status, crash or error events when observability is enabled.

## Purpose

The data is used for app functionality, account management, personalized
lessons, progress synchronization, payment/credit operations, fraud prevention,
security, support, stability diagnostics, and aggregated quality review.

## Service Providers And Processors

SIM may use Supabase for authentication, database, and storage; configured AI
providers for lesson, image, audio, and attachment processing; Google Play
Billing for Android purchases; Stripe where platform rules allow it; hosting and
observability providers required to operate the service. SIM does not sell
personal data.

## Transport And Storage

The Google Play production build must use HTTPS for server traffic. Secrets for
AI, payment, and service providers remain on the server and must never be
embedded in the app. Data is stored in the configured production backend with
access controls by authenticated user.

## Deletion

The user can request account deletion inside the app and through the public web
resource. Authenticated deletion deletes or anonymizes educational state and
account-linked data. Minimum financial or fraud-prevention records may be
retained when required by law, accounting, security, payment reconciliation, or
defense of rights.

## Minors

If SIM is distributed to children or teenagers, the Play Console declarations
must reflect minors' data collection and the owner must maintain guardian
consent and child-protection compliance required by applicable law and Google
Play policy.

## External Approval Evidence

Play Console Data Safety submitted: PENDING
Play Console Data Safety approved: PENDING
Responsible person: PENDING
Approval evidence location: PENDING
