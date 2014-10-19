CREATE TYPE trades AS (execution_time TIMESTAMP, shares INTEGER, price NUMERIC);
CREATE TYPE open_trade AS (trade_id UUID, security UUID, trade_lister UUID, price NUMERIC, number_of_shares NUMERIC, trade_type TEXT);
CREATE TYPE security_search_data AS (id UUID, name TEXT, symbol TEXT, current_price NUMERIC, type TEXT);
CREATE TYPE account_overview AS (id UUID, name TEXT, wdc NUMERIC, withdraw_address TEXT, deposit_address TEXT, email TEXT, time_zone SMALLINT, last_login TIMESTAMP, joined TIMESTAMP);
CREATE TYPE trade_history_list AS (execution_time TIMESTAMP, seller UUID, buyer UUID, number_of_shares NUMERIC, price NUMERIC, security UUID);
CREATE TYPE historical_prices AS (execution_time TIMESTAMP, price NUMERIC, buy_or_sell TEXT);
CREATE TYPE chart_data AS ("date" TIMESTAMP, "open" NUMERIC, hi NUMERIC, low NUMERIC, "close" NUMERIC);
CREATE TYPE message_list AS (id UUID, subject TEXT, sent_on TIMESTAMP, sender UUID, "read" BOOLEAN);
CREATE TYPE message AS (sender_name TEXT, subject TEXT, message_body TEXT);
CREATE TYPE note AS (name TEXT, note_title TEXT, note TEXT, created TIMESTAMP);
CREATE TYPE held_security_data AS (symbol TEXT, security TEXT, number_of_shares BIGINT, price NUMERIC);
CREATE TYPE security_overview AS (
	id UUID, 
	symbol TEXT, 
	name TEXT, 
	contract TEXT, 
	number_of_shares NUMERIC,
	date_approved TIMESTAMP, 
	owner TEXT, 
	type TEXT, 
	distribution_schedule TEXT,
	description TEXT
);

CREATE TYPE distribution_history AS(
    date_issued TIMESTAMP,
    amount_per_share NUMERIC,
    shares_paid BIGINT
);
CREATE TYPE unapproved_securities AS (id UUID,name TEXT, symbol TEXT);
CREATE TYPE site_config AS(
    site_name TEXT,
    database_server_address TEXT,
    hot_wallet_ip_address TEXT,
    cold_wallet_address TEXT
);