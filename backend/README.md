# `backend/` — NOT on the DartStream path

> ⚠️ This Dart Frog service is **not** part of the DartStream sample. It exists
> only as an optional illustration of a "bring-your-own microservice" pattern,
> and the Flutter app **does not call it**.

**DartStream is the backend for this sample.** All persistence, reactive event,
feature-flag, and auth flows go through the DartStream SaaS via the
`dartstream_client` package — see `frontend/lib/state/session.dart` and
`frontend/lib/screens/home_screen.dart`.

The split math implemented here duplicates `BudgetCalculator` from
`packages/shared_models`, which the frontend already runs client-side. Delete
this directory if it is confusing for your purposes.

---

## Endpoint (legacy / illustrative)

### `POST /api/transactions`

**Request**
```json
{
  "total_amount": 90.0,
  "number_of_people": 3,
  "description": "Dinner"
}
```

**Response `200`**
```json
{
  "amount_per_person": 30.0,
  "total_amount": 90.0,
  "number_of_people": 3
}
```

**Response `400`** — invalid input (negative amount, zero people)

## Running

```bash
dart pub get
dart_frog dev
# → Running on http://localhost:8080
```
