# Scry - Lightweight Ruby Document Store

## Features
- MongoDB-style query syntax
- CRUD operations for Hash/Array storage
- Supported selectors:
  - `_eq`
  - `_gt`
  - `_gte`
  - `_lt`
  - `_lte`
  - `_ne`
  - `_in`
  - `_nin`
  - `_exists`
  - `_type`
- Supported compound operators:
  - `_and`
  - `_or`
  - `_nor`
- Projection and pagination (limit/skip)

## Basic Usage
```ruby
# Initialize with hash storage
store = Scry.new({})
# or 
store = Scry.new(args.state)
# or 
store = Scry.new(args.state.data)
# etc

# Insert document
store.insert_one({ name: 'Aragorn', level: 50, class: 'Ranger' })
# or, if you're using args.state
args.state.store.insert_one({ name: 'Aragorn', level: 50, class: 'Ranger' })

# Find documents
high_level = store.find({ level: { '_gt' => 40 } })
```

## Query Operators
| Operator | Example                      |
|----------|------------------------------|
| _eq     | `{ level: { _eq: 50 } }`     |
| _gt     | `{ level: { _gt: 40 } }`     |
| _gte    | `{ level: { _gte: 50 } }`    |
| _lt     | `{ level: { _lt: 40 } }`     |
| _lte    | `{ level: { _lte: 50 } }`    |
| _ne     | `{ level: { _ne: 50 } }`     |
| _in     | `{ class: { _in: ['Warrior'] } }` |
| _nin    | `{ class: { _nin: ['Warrior'] } }` |
| _exists | `{ class: { _exists: true } }` |
| _type   | `{ class: { _type: 'string' } }` |
| _and    | `{ _and: [{ level: { _gt: 40 }}, { class: { _eq: 'Ranger' }}] }` |
| _or     | `{ _or: [{ level: { _gt: 40 }}, { class: { _eq: 'Ranger' }}] }` |
| _nor    | `{ _nor: [{ level: { _gt: 40 }}, { class: { _eq: 'Ranger' }}] }` |
| _not    | `{ _not: { level: { _gt: 40 }}, { class: { _eq: 'Ranger' }}] }` |

