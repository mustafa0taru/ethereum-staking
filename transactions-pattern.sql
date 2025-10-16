-- Total Transactions - Overall count of successful ETH transfers (inbound + outbound)
-- Inbound Transactions - Count of transactions where this address is the recipient
-- Total ETH Received - Sum of ETH received across all inbound transactions (in ETH)
-- Avg Inbound Amount (ETH) - Average ETH amount per inbound transaction
-- Outbound Transactions - Count of transactions where this address is the sender
-- Total ETH Sent - Sum of ETH sent across all outbound transactions (in ETH)
-- Avg Outbound Amount (ETH) - Average ETH amount per outbound transaction
-- Net ETH Flow - Net inflow/outflow balance (Received - Sent)
-- Total Gas Spent (ETH) - Total ETH spent on transaction gas fees
-- First Transaction - Timestamp of first successful transaction
-- Last Transaction - Timestamp of most recent successful transaction
-- Days Active - Days between first and last recorded transaction

SELECT 
    COUNT(*) as "Total Transactions",
    
    -- INFLOWS
    SUM(CASE WHEN "to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN 1 ELSE 0 END) as "Inbound Transactions",
    ROUND(SUM(CASE WHEN "to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 ELSE 0 END), 4) as "Total ETH Received",
    ROUND(AVG(CASE WHEN "to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 END), 4) as "Avg Inbound Amount (ETH)",
    
    -- OUTFLOWS
    SUM(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN 1 ELSE 0 END) as "Outbound Transactions",
    ROUND(SUM(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 ELSE 0 END), 4) as "Total ETH Sent",
    ROUND(AVG(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 END), 4) as "Avg Outbound Amount (ETH)",
    
    -- NET FLOW
    ROUND(
        SUM(CASE WHEN "to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 ELSE -(value / 1e18) END), 
        4
    ) as "Net ETH Flow",
    
    -- GAS
    ROUND(SUM(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN (gas_used * gas_price) / 1e18 ELSE 0 END), 4) as "Total Gas Spent (ETH)",
    
    -- TIME
    MIN(block_time) as "First Transaction",
    MAX(block_time) as "Last Transaction",
    DATE_DIFF('day', MIN(block_time), MAX(block_time)) as "Days Active"
    
FROM ethereum.transactions
WHERE ("to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 
       OR "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4)
    AND success = true
    AND value > 0;


-- Month - Aggregated monthly transaction activity
-- Total Transactions - Number of total transactions in that month
-- Inbound Count - Number of inbound transactions (address as recipient)
-- ETH Received - Total ETH value received that month
-- Outbound Count - Number of outbound transactions (address as sender)
-- ETH Sent - Total ETH value sent that month
-- Net Flow (ETH) - Net inflow/outflow ETH balance per month
-- Avg Gas Price (Gwei) - Average gas price used (in Gwei) for outbound transactions
-- Gas Cost (ETH) - Total gas expenditure for that month (in ETH)

SELECT 
    DATE_TRUNC('month', block_time) as "Month",
    COUNT(*) as "Total Transactions",
    
    -- INFLOWS
    SUM(CASE WHEN "to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN 1 ELSE 0 END) as "Inbound Count",
    ROUND(SUM(CASE WHEN "to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 ELSE 0 END), 4) as "ETH Received",
    
    -- OUTFLOWS
    SUM(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN 1 ELSE 0 END) as "Outbound Count",
    ROUND(SUM(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 ELSE 0 END), 4) as "ETH Sent",
    
    -- NET
    ROUND(
        SUM(CASE WHEN "to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN value / 1e18 ELSE -(value / 1e18) END), 
        4
    ) as "Net Flow (ETH)",
    
    -- GAS
    ROUND(AVG(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN gas_price / 1e9 END), 2) as "Avg Gas Price (Gwei)",
    ROUND(SUM(CASE WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN (gas_used * gas_price) / 1e18 ELSE 0 END), 4) as "Gas Cost (ETH)"
    
FROM ethereum.transactions
WHERE ("to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 
       OR "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4)
    AND success = true
    AND value > 0
GROUP BY 1
ORDER BY 1 DESC;


-- Address - Counterparty wallet interacted with
-- Direction - Whether ETH was SENT or RECEIVED to/from that counterparty
-- Transaction Count - Number of transactions with this counterparty
-- Total ETH - Total ETH transferred in that direction
-- Avg per Transaction - Average ETH per transaction for that counterparty
-- First Transaction - Timestamp of first transaction with that counterparty
-- Last Transaction - Timestamp of most recent transaction with that counterparty
-- Type - Counterparty type classification (e.g., Beacon Deposit, Burn, or Regular Address)

WITH counterparty_data AS (
    SELECT 
        CASE 
            WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN "to"
            ELSE "from"
        END as counterparty,
        CASE 
            WHEN "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 THEN 'SENT'
            ELSE 'RECEIVED'
        END as direction,
        COUNT(*) as tx_count,
        SUM(value / 1e18) as total_eth,
        MIN(block_time) as first_tx,
        MAX(block_time) as last_tx
    FROM ethereum.transactions
    WHERE ("to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 
           OR "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4)
        AND success = true
        AND value > 0
    GROUP BY 1, 2
)

SELECT 
    counterparty as "Address",
    direction as "Direction",
    tx_count as "Transaction Count",
    ROUND(total_eth, 4) as "Total ETH",
    ROUND(total_eth / tx_count, 4) as "Avg per Transaction",
    first_tx as "First Transaction",
    last_tx as "Last Transaction",
    CASE 
        WHEN counterparty = 0x00000000219ab540356cBB839Cbe05303d7705Fa THEN 'Beacon Deposit Contract'
        WHEN counterparty = 0x0000000000000000000000000000000000000000 THEN 'Burn Address'
        ELSE 'Regular Address'
    END as "Type"
FROM counterparty_data
ORDER BY total_eth DESC
LIMIT 30;


-- Transaction Size Range - ETH amount range bucket for transactions
-- Count - Number of transactions within the range
-- Total ETH - Total ETH transferred within the range
-- Avg Amount - Average ETH amount per transaction within that range
-- % of Total Volume - Percentage of overall ETH volume represented by this range

SELECT 
    CASE 
        WHEN value / 1e18 < 100 THEN '50 – 100 ETH'
        WHEN value / 1e18 < 500 THEN '100 – 500 ETH'
        WHEN value / 1e18 < 1000 THEN '500 – 1,000 ETH'
        WHEN value / 1e18 < 5000 THEN '1,000 – 5,000 ETH'
        WHEN value / 1e18 < 10000 THEN '5,000 – 10,000 ETH'
        ELSE '> 10,000 ETH'
    END as "Transaction Size Range",
    COUNT(*) as "Count",
    ROUND(SUM(value / 1e18), 2) as "Total ETH",
    ROUND(AVG(value / 1e18), 4) as "Avg Amount",
    ROUND(SUM(value / 1e18) / SUM(SUM(value / 1e18)) OVER () * 100, 2) as "% of Total Volume"
FROM ethereum.transactions
WHERE ("to" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4 
       OR "from" = 0xe3c44d4d25172ef2e0cdb9e09189a8ca4ed878f4)
    AND success = true
    AND value > 0
GROUP BY 1
ORDER BY 3 DESC;
