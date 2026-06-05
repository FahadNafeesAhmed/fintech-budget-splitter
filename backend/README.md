# Backend — Dart Frog API

REST API built with [Dart Frog](https://dartfrog.vgv.dev/). Accepts a transaction, calculates the split, returns the result.

## Endpoint

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

## Notes

- CORS is handled via `routes/_middleware.dart` — allows all origins for local dev
- Math logic lives in `shared_models` — backend just calls `BudgetCalculator.calculate()`
