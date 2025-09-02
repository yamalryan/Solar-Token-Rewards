# 🌞 Solar Token Rewards Contract

A Clarity smart contract that rewards solar energy producers with tokens for their renewable energy contributions.

## ⚡ Features

- 🏭 **Producer Registration**: Register as a verified solar energy producer
- 📊 **Energy Submission**: Submit daily energy production data  
- 🎁 **Token Rewards**: Earn SOLAR tokens based on energy produced
- ✅ **Verification System**: Optional verification by contract owner
- 💰 **Bonus Rewards**: Time-based bonus rewards for active producers
- 🔄 **Token Transfers**: Transfer earned tokens between users
- 📈 **Analytics**: Track total energy and rewards across the network

## 🚀 Quick Start

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for deployment

### Deployment
```bash
clarinet check
clarinet test
clarinet deploy
```

## 📝 Contract Functions

### 🔧 Producer Management

#### `register-producer`
Register as a solar energy producer with your energy production rate.
```clarity
(contract-call? .Solar-Token-Rewards register-producer u100)
```

#### `deactivate-producer` / `reactivate-producer`
Pause or resume your producer status.

### ⚡ Energy & Rewards

#### `submit-energy-production`
Submit your daily energy production (in kWh).
```clarity
(contract-call? .Solar-Token-Rewards submit-energy-production u500)
```

#### `claim-bonus-rewards`
Claim time-based bonus rewards (available after cooldown period).
```clarity
(contract-call? .Solar-Token-Rewards claim-bonus-rewards)
```

#### `transfer-tokens`
Transfer SOLAR tokens to another user.
```clarity
(contract-call? .Solar-Token-Rewards transfer-tokens u100 'SP1ABC...)
```

### 👑 Owner Functions

#### `verify-energy-submission`
Verify energy submissions (if verification is required).
```clarity
(contract-call? .Solar-Token-Rewards verify-energy-submission 'SP1ABC... u1)
```

#### Configuration Functions
- `set-base-reward-rate`: Update token rewards per kWh
- `set-verification-required`: Toggle verification requirement
- `set-claim-cooldown`: Set bonus claim cooldown period
- `set-max-daily-energy`: Set maximum daily energy submission

### 📊 Read-Only Functions

#### `get-producer-info`
Get detailed producer information.
```clarity
(contract-call? .Solar-Token-Rewards get-producer-info 'SP1ABC...)
```

#### `get-token-balance`
Check SOLAR token balance.
```clarity
(contract-call? .Solar-Token-Rewards get-token-balance 'SP1ABC...)
```

#### `get-contract-stats`
View network-wide statistics.

#### `calculate-potential-bonus`
Check available bonus rewards.

## 🎯 Usage Flow

1. **🔐 Register**: Call `register-producer` with your energy rate
2. **⚡ Submit**: Daily call `submit-energy-production` with kWh generated  
3. **✅ Verify**: Owner verifies submissions (if enabled)
4. **🎁 Earn**: Automatically receive SOLAR tokens as rewards
5. **💰 Bonus**: Claim time-based bonuses periodically
6. **💸 Transfer**: Use tokens as needed

## 🔢 Token Economics

- **Base Rate**: 10 SOLAR tokens per kWh (configurable)
- **Bonus Formula**: `(energy_produced × blocks_since_claim) ÷ 1000`
- **Cooldown**: 144 blocks (~24 hours) between bonus claims
- **Daily Limit**: 10,000 kWh maximum per submission

## 🛡️ Security Features

- Owner-only admin functions
- Input validation and bounds checking
- Cooldown periods prevent abuse
- Producer activation/deactivation controls
- Optional verification system

## 📊 Contract Data

The contract tracks:
- Producer registration and activity status
- Energy submissions with timestamps
- Total network energy and rewards
- Individual producer statistics
- Token balances and transfers

## 🔧 Error Codes

- `u100`: Owner-only function
- `u101`: Not found
- `u102`: Already exists  
- `u103`: Insufficient balance
- `u104`: Invalid amount
- `u105`: Not registered
- `u106`: Invalid energy amount
- `u107`: Cooldown active

## 🌱 Contributing

This contract promotes renewable energy adoption through blockchain incentives. Contributions welcome!

## 📄 License

MIT License - Building a sustainable future with blockchain technology.
