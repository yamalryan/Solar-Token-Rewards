Carbon Credit Trading System

Overview
Added an independent carbon credit trading system that allows solar energy producers to convert their verified energy production into tradeable carbon offset certificates. This feature creates a marketplace for environmental impact tokens, enabling producers to monetize their carbon footprint reduction while providing transparency and verification for carbon offset transactions.

Technical Implementation
**New Data Structures:**
- `carbon-credit` NFT: Unique tokens representing verified carbon offsets with energy amount and producer metadata
- `carbon-credits` map: Tracks credit details including producer, energy amount, verification status, and carbon offset tons
- `carbon-credit-marketplace` map: Manages buy/sell listings with pricing and active status

**Key Functions Added:**
- `mint-carbon-credit`: Converts verified energy production into carbon credit NFTs with automatic carbon offset calculation
- `list-carbon-credit-for-sale`: Creates marketplace listings for carbon credits with custom pricing
- `purchase-carbon-credit`: Enables trading using solar tokens with automatic ownership transfer
- `transfer-carbon-credit`: Direct peer-to-peer carbon credit transfers
- `get-carbon-credit-stats`: Provides comprehensive carbon credit system analytics

**Configuration Variables:**
- `energy-to-credit-rate`: Conversion ratio (default 100 kWh = 1 ton CO2 offset)
- `min-energy-for-credit`: Minimum energy threshold for credit creation (500 kWh)
- `carbon-credit-counter`: Unique identifier tracking for all minted credits

Testing & Validation
✅ Contract passes clarinet check
✅ All npm tests successful  
✅ CI/CD pipeline configured
✅ Clarity v3 compliant with proper error handling