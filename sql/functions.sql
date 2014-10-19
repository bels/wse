CREATE OR REPLACE FUNCTION register(name_val TEXT, password_val TEXT, password_reset_question_val INT,password_reset_answer_val TEXT, email_val TEXT, random_seed TEXT) RETURNS TEXT AS $$
DECLARE
    user_id UUID;
    auth_code_val TEXT;
BEGIN

    auth_code_val := substring(md5(random_seed) from 1 for 8);
    
	INSERT INTO accounts (name,pswhash,activation_code) VALUES (name_val,crypt(password_val,gen_salt('md5')),auth_code_val) RETURNING id INTO user_id;
    INSERT INTO account_profile(account,password_reset_question,password_reset_answer,email) VALUES (user_id,password_reset_question_val,password_reset_answer_val,email_val);
	RETURN auth_code_val;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION activate (name_val TEXT, code_val TEXT) RETURNS BOOLEAN AS $$
BEGIN
    IF (SELECT count(*) FROM accounts WHERE lower(name) = lower(name_val) AND lower(activation_code) = lower(code_val) AND active = FALSE)  THEN
        UPDATE accounts SET active = TRUE WHERE lower(name) = lower(name_val);
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION authenticate (name_val TEXT, pswhash_val TEXT) RETURNS BOOLEAN AS $$
BEGIN
    IF (SELECT count(*) FROM accounts WHERE lower(name) = lower(name_val) AND pswhash = crypt(pswhash_val,pswhash)) THEN
        UPDATE accounts SET last_login = now(),currently_logged_in = TRUE WHERE lower(name) = lower(name_val);
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION logout (name_val TEXT) RETURNS VOID AS $$
    UPDATE accounts SET currently_logged_in = FALSE WHERE lower(name) = lower(name_val);
$$ LANGUAGE SQL;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION duplicate_name_check (name_val TEXT) RETURNS BOOLEAN AS $$
BEGIN
    IF (SELECT count(*) FROM accounts WHERE lower(name) = lower(name_val)) THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION duplicate_security_check (name_val TEXT, symbol_val TEXT) RETURNS INTEGER AS $$
BEGIN
    IF (SELECT count(*) FROM securities WHERE name = name_val) THEN
        RETURN 1;
    END IF;
    IF (SELECT count(*) FROM securities WHERE symbol = symbol_val) THEN
        RETURN 2;
    END IF;
    RETURN 0;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION list_recent_trades (security_symbol TEXT, limit_val INTEGER) RETURNS SETOF trades AS $$
DECLARE
    security_id UUID;
    t trades%rowtype;
BEGIN
    SELECT id INTO security_id FROM securities WHERE lower(symbol) = lower(security_symbol);
    FOR t IN
        SELECT execution_time, number_of_shares, price FROM trade_history WHERE security = security_id ORDER BY execution_time DESC
    LOOP
        RETURN NEXT t;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_open_buys_for_security(security_symbol TEXT) RETURNS SETOF open_trade AS $$
DECLARE
    open_buy open_trade%rowtype;
BEGIN
    FOR open_buy IN
        SELECT open_trades.id,open_trades.security,open_trades.id,open_trades.price,open_trades.number_of_shares,'buy' FROM open_trades 
		JOIN securities ON open_trades.security = securities.id 
		WHERE buy = true AND lower(securities.symbol) = lower(security_symbol)
		ORDER BY open_trades.price DESC
    LOOP
        RETURN NEXT open_buy;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_open_sells_for_security(security_symbol TEXT) RETURNS SETOF open_trade AS $$
DECLARE
    open_sell open_trade%rowtype;
BEGIN
    FOR open_sell IN
        SELECT open_trades.id,open_trades.security,open_trades.id,open_trades.price,open_trades.number_of_shares,'sell' FROM open_trades 
	JOIN securities ON open_trades.security = securities.id 
	WHERE sell = true AND lower(securities.symbol) = lower(security_symbol)
	ORDER BY open_trades.price ASC
    LOOP
        RETURN NEXT open_sell;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_account(colname TEXT, field_val TEXT, user_id UUID) RETURNS VOID AS $$
BEGIN
    IF colname = 'pswhash' THEN
        UPDATE accounts SET pswhash = field_val WHERE id = user_id;
    ELSE
        EXECUTE format('UPDATE account_profile SET %I = %L WHERE account = %L',colname, field_val,user_id);
    END IF;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_account(colname TEXT, field_val INT, user_id UUID) RETURNS VOID AS $$
BEGIN
    EXECUTE format('UPDATE account_profile SET %I = $L WHERE account = $L',colname, field_val,user_id);
	IF colname = 'timezone' THEN
		INSERT INTO account_history (account,event) VALUES (user_id, 8);
	END IF;
	IF colname = 'withdraw_address' THEN
		INSERT INTO account_history (account,event) VALUES (user_id, 5);
	END IF;
	IF colname = 'deposit_address' THEN
		INSERT INTO account_history (account,event) VALUES (user_id, 6);
	END IF;
	IF colname = 'email' THEN
		INSERT INTO account_history (account,event) VALUES (user_id, 1);
	END IF;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_account(colname TEXT, field_val SMALLINT, user_id UUID) RETURNS VOID AS $$
BEGIN
    EXECUTE format('UPDATE account_profile SET %I = $L WHERE account = $L',colname, field_val,user_id);
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION list_security (security_name TEXT, description_val TEXT, security_symbol TEXT, number_of_shares_val BIGINT, contract_verbiage_val TEXT, distribution_schedule_val INT,account_val UUID, type_val INTEGER) RETURNS VOID AS $$
    INSERT INTO securities (name,description,symbol,number_of_shares_issued,contract_verbiage,distribution_schedule,owner,type) VALUES (security_name, description_val, security_symbol,number_of_shares_val,contract_verbiage_val,distribution_schedule_val,account_val, type_val);
$$ LANGUAGE SQL;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION search_for_security (search_criteria TEXT) RETURNS SETOF security_search_data AS $$
DECLARE
	results security_search_data%rowtype;
BEGIN
	FOR results IN
		SELECT securities.id, securities.name, securities.symbol, trade_history.price, security_type.description FROM securities JOIN trade_history ON securities.id = trade_history.security JOIN security_type ON securities.type = security_type.id WHERE securities.name ILIKE '%search_criteria%' ORDER BY trade_history.execution_time DESC LIMIT 10
	LOOP
		RETURN NEXT results;
	END LOOP;
	FOR results IN
		SELECT securities.id, securities.name, securities.symbol, trade_history.price, security_type.description FROM securities JOIN trade_history ON securities.id = trade_history.security JOIN security_type ON securities.type = security_type.id WHERE securities.symbol ILIKE '%search_criteria%' ORDER BY trade_history.execution_time DESC LIMIT 10
	LOOP
		RETURN NEXT results;
	END LOOP;
	
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_site_config (field TEXT, val TEXT) RETURNS VOID AS $$
BEGIN
	EXECUTE 'UPDATE site_configuration SET $1 = $2';
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_wdc (account_id UUID, wdc_val NUMERIC) RETURNS VOID AS $$
	UPDATE accounts SET wdc = wdc_val WHERE id = account_id;
$$ LANGUAGE SQL;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fulfill_trade (number_of_shares_exchanging NUMERIC, price_val NUMERIC, trade_type TEXT, trader_id UUID, security_id UUID) RETURNS NUMERIC AS $$
DECLARE
    bought_all_shares BOOLEAN;
    total_shares_for_trade NUMERIC;
    existing_trader_id UUID;
    trade_ids UUID;
    current_requested_shares NUMERIC;
BEGIN
    -- going to check if there is already a trade setup at the price point requested.  If so we're going to check if the new trade dwarfs
    -- the existing trade or not
    IF trade_type = 'buy' THEN
        FOR trade_ids IN
            SELECT id FROM open_trades WHERE price = price_val AND security = security_id AND sell = TRUE
        LOOP
            SELECT number_of_shares INTO total_shares_for_trade FROM open_trades WHERE id = trade_ids;
            current_requested_shares := number_of_shares_exchanging - total_shares_for_trade;
            IF current_requested_shares <= 0 THEN
                --adding the wdc from the trade to the seller
                UPDATE accounts SET wdc = wdc + (number_of_shares_exchanging * price_val) WHERE id = (SELECT account FROM open_trades WHERE id = trade_ids);
                --subtracting the wdc from the seller
                UPDATE accounts SET wdc = wdc - (number_of_shares_exchanging * (SELECT price FROM open_trades WHERE id = trade_ids)) WHERE id = trader_id;
                --Updating the shares held
                UPDATE shares_held SET amount = amount + number_of_shares_exchanging WHERE account = trader_id AND security = security_id;
                INSERT INTO shares_held (account,security,amount) 
                    SELECT 
                        trader_id, security_id, number_of_shares_exchanging
                    WHERE NOT EXISTS 
                        (SELECT 1 FROM shares_held WHERE account = trader_id AND security = security_id);
            
                UPDATE open_trades SET number_of_shares = number_of_shares - number_of_shares_exchanging WHERE id = trade_ids;
                INSERT INTO trade_history (seller,buyer,number_of_shares,price,security,buy_or_sell) 
                    VALUES ((SELECT account FROM open_trades WHERE id = trade_ids),trader_id,number_of_shares_exchanging,price_val,security_id,'buy');
                EXIT;
            ELSE
                UPDATE accounts SET wdc = wdc + (total_shares_for_trade * price_val) WHERE id = (SELECT account FROM open_trades WHERE id = trade_ids);
                UPDATE accounts SET wdc = wdc - (total_shares_for_trade * price_val) WHERE id = trader_id;
                UPDATE shares_held SET amount = amount + total_shares_for_trade WHERE acount = trader_id AND security = security_id;
                INSERT INTO shares_held (account,security,amount) 
                    SELECT 
                        trader_id, security_id, total_shares_for_trade
                    WHERE NOT EXISTS 
                        (SELECT 1 FROM shares_held WHERE account = trader_id AND security = security_id);
                number_of_shares_exchanging := number_of_shares_exchanging - total_shares_for_trade;
                INSERT INTO trade_history (seller,buyer,number_of_shares,price,security,buy_or_sell) 
                    VALUES ((SELECT account FROM open_trades WHERE id = trade_ids),trader_id,number_of_shares_exchanging,price_val,security_id,'buy');
                DELETE FROM open_trades WHERE id = trade_ids;
            END IF;
        END LOOP;
        RETURN number_of_shares_exchanging;
                
    ELSE
        FOR trade_ids IN
            SELECT id FROM open_trades WHERE price = price_val AND buy = TRUE
        LOOP
            SELECT number_of_shares INTO total_shares_for_trade FROM open_trades WHERE id = trade_ids;
            current_requested_shares := number_of_shares_exchanging - total_shares_for_trade;
            IF current_requested_shares <= 0 THEN
                --adding the wdc from the trade to the seller
                UPDATE accounts SET wdc = wdc + (number_of_shares_exchanging * price_val) WHERE id = trader_id;
                --subtracting the wdc from the seller
                UPDATE accounts SET wdc = wdc - (number_of_shares_exchanging * (SELECT price FROM open_trades WHERE id = trade_id)) WHERE id = (SELECT account FROM open_trades WHERE id = trade_ids);
                --Updating the shares held
                UPDATE shares_held SET amount = amount + number_of_shares_exchanging WHERE account = (SELECT account FROM open_trades WHERE id = trade_ids) AND security = security_id;
                INSERT INTO shares_held (account,security,amount) 
                    SELECT 
                        (SELECT account FROM open_trades WHERE id = trade_ids), security_id, number_of_shares_exchanging
                    WHERE NOT EXISTS 
                        (SELECT 1 FROM shares_held WHERE account = (SELECT account FROM open_trades WHERE id = trade_ids) AND security = security_id);

                UPDATE open_trades SET number_of_shares = number_of_shares - number_of_shares_exchanging WHERE id = trade_ids;
                INSERT INTO trade_history (seller,buyer,number_of_shares,price,security,buy_or_sell) 
                    VALUES (trader_id,(SELECT account FROM open_trades WHERE id = trade_ids),number_of_shares_exchanging,price_val,security_id,'sell');
                EXIT;
            ELSE
                UPDATE accounts SET wdc = wdc + (total_shares_for_trade * price_val) WHERE id = trader_id;
                UPDATE accounts SET wdc = wdc - (total_shares_for_trade * price_val) WHERE id = (SELECT account FROM open_trades WHERE id = trade_ids);
                UPDATE shares_held SET amount = amount + total_shares_for_trade WHERE acount = (SELECT account FROM open_trades WHERE id = trade_ids) AND security = security_id;
                INSERT INTO shares_held (account,security,amount) 
                    SELECT 
                        trader_id, security_id, total_shares_for_trade
                    WHERE NOT EXISTS 
                        (SELECT 1 FROM shares_held WHERE account = (SELECT account FROM open_trades WHERE id = trade_ids) AND security = security_id);
                number_of_shares_exchanging := number_of_shares_exchanging - total_shares_for_trade;
                INSERT INTO trade_history (seller,buyer,number_of_shares,price,security,buy_or_sell) 
                    VALUES (trader_id,(SELECT account FROM open_trades WHERE id = trade_ids),number_of_shares_exchanging,price_val,security_id,'sell');
                DELETE FROM open_trades WHERE id = trade_ids;
            END IF;
        END LOOP;
        RETURN number_of_shares_exchanging;
    END IF;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION list_trade (trade_type TEXT, price_val NUMERIC, trade_issuer UUID, security_val UUID, number_of_shares_val NUMERIC) RETURNS VOID AS $$
BEGIN
    IF trade_type = 'buy' THEN
        INSERT INTO open_trades (security, account, price, number_of_shares, buy) VALUES( security_val, trade_issuer, price_val, number_of_shares_val,TRUE);
        UPDATE accounts SET wdc = wdc - (number_of_shares_val * price_val) WHERE id = trade_issuer;
    END IF;
    IF trade_type = 'sell' THEN
        INSERT INTO open_trades (security, account, price, number_of_shares, sell) VALUES( security_val, trade_issuer, price_val, number_of_shares_val,TRUE);
        UPDATE shares_held SET amount = amount - number_of_shares_val WHERE account = trade_issuer AND security = security_val;
    END IF;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cancel_trade (trade_id UUID, account_val UUID) RETURNS VOID AS $$
BEGIN
	DELETE FROM open_trades WHERE id = trade_id AND account = account_val;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION approve_security(security_id UUID) RETURNS VOID AS $$
	UPDATE securities SET active = TRUE, date_approved = now() WHERE id = security_id;
    INSERT INTO shares_held (account,security,amount) VALUES ((SELECT owner FROM securities WHERE id = security_id),security_id,(SELECT number_of_shares_issued FROM securities WHERE id = security_id));
$$ LANGUAGE SQL;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION decline_security(security_id UUID) RETURNS VOID AS $$
	UPDATE securities SET denied = TRUE, denied_date = now() WHERE id = security_id;
$$ LANGUAGE SQL;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_account_overview(account_id UUID) RETURNS SETOF account_overview AS $$
BEGIN
	RETURN QUERY
		SELECT accounts.id, accounts.name, accounts.wdc, account_profile.withdraw_address, account_profile.deposit_address, account_profile.email, account_profile.time_zone, accounts.last_login, accounts.date_created FROM accounts JOIN account_profile ON accounts.id = account_profile.account WHERE accounts.id = account_id;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_account_overview(account_id TEXT) RETURNS SETOF account_overview AS $$
BEGIN
	RETURN QUERY
		SELECT accounts.id, accounts.name, accounts.wdc, account_profile.withdraw_address, account_profile.deposit_address, account_profile.email, account_profile.time_zone, accounts.last_login, accounts.date_created FROM accounts JOIN account_profile ON accounts.id = account_profile.account WHERE lower(accounts.name) = lower(account_id);
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_account_trade_history(account_val UUID) RETURNS SETOF trade_history_list AS $$
DECLARE
    t trade_history_list%rowtype;
BEGIN
    FOR t IN
        SELECT * FROM trade_history WHERE seller = account_val OR buyer = account_val
    LOOP
        RETURN NEXT t;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_historical_price_data (security_val UUID, limit_val INTEGER) RETURNS SETOF historical_prices AS $$
DECLARE
    past_prices historical_prices%rowtype;
BEGIN
    FOR past_prices IN
        SELECT execution_time, price, buy_or_sell FROM trade_history WHERE security = security_val
    LOOP
        RETURN NEXT past_prices;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_historical_price_data (security_val TEXT, limit_val INTEGER) RETURNS SETOF historical_prices AS $$
DECLARE
    past_prices historical_prices%rowtype;
BEGIN
    FOR past_prices IN
        SELECT execution_time, price, buy_or_sell FROM trade_history JOIN securities ON trade_history.security = securities.id WHERE lower(securities.symbol) = lower(security_val)
    LOOP
        RETURN NEXT past_prices;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION send_message(sender_id UUID, recipient_id UUID, subject_val TEXT, body_val TEXT) RETURNS VOID AS $$
	INSERT INTO messages (sender, recipient, subject, message_body) VALUES (sender_id, recipient_id, subject_val, body_val);
$$ LANGUAGE SQL;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION send_message(sender_id UUID, recipient_id UUID, subject_val TEXT, body_val TEXT, on_behalf_of_val UUID) RETURNS VOID AS $$
	INSERT INTO messages (sender, recipient, subject, message_body, on_behalf_of) VALUES (sender_id, recipient_id, subject_val, body_val, on_behalf_of_val);
$$ LANGUAGE SQL;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_unread_messages(account_val UUID, limit_val INTEGER) RETURNS SETOF message_list AS $$
DECLARE
    m message_list%rowtype;
BEGIN
    FOR m IN
        SELECT id, subject, sent_on, sender, "read" FROM messages WHERE recipient = account_val AND "read" = FALSE
    LOOP
        RETURN NEXT m;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_all_messages(account_val UUID, limit_val INTEGER) RETURNS SETOF message_list AS $$
DECLARE
    m message_list%rowtype;
BEGIN
    FOR m IN
        SELECT id, subject, sent_on, sender, "read" FROM messages WHERE recipient = account_val
    LOOP
        RETURN NEXT m;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_specific_message(message_id_val UUID) RETURNS SETOF message AS $$
BEGIN
    RETURN QUERY
        SELECT account.name,messages.subject,messages.message_body FROM messages JOIN accounts ON messages.sender = accounts.id WHERE messages.id = message_id_val;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION add_note (security_id UUID, note_title_val TEXT, note_val TEXT) RETURNS VOID AS $$
	INSERT INTO security_notes (security, note_title, note) VALUES (security_id, note_title_val, note_val);
$$ LANGUAGE SQL;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION list_all_notes_for_all_securities (note_title_val TEXT, note_val TEXT) RETURNS SETOF note AS $$
DECLARE
    all_notes note%rowtype;
BEGIN
    FOR all_notes IN
        SELECT securities.name, security_notes.note_title, security_notes.note, security_notes.created FROM security_notes JOIN securities ON security_notes.security = securities.id ORDER BY security_notes.created DESC LIMIT 10
    LOOP
        RETURN NEXT all_notes;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_notes_for_security(security_id UUID, limit_val INTEGER) RETURNS SETOF note AS $$
DECLARE
    all_notes note%rowtype;
BEGIN
    FOR all_notes IN
        SELECT securities.name, security_notes.note_title, security_notes.note, security_notes.created FROM security_notes JOIN securities ON security_notes.security = securities.id WHERE security_notes.security = security_id ORDER BY security_notes.created DESC LIMIT limit_val
    LOOP
        RETURN NEXT all_notes;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_notes_for_security(security_symbol TEXT, limit_val INTEGER) RETURNS SETOF note AS $$
DECLARE
    all_notes note%rowtype;
BEGIN
    FOR all_notes IN
        SELECT securities.name, security_notes.note_title, security_notes.note, security_notes.created FROM security_notes JOIN securities ON security_notes.security = securities.id WHERE securities.symbol = security_symbol ORDER BY security_notes.created DESC LIMIT limit_val
    LOOP
        RETURN NEXT all_notes;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION close_security (security_id UUID) RETURNS VOID AS $$
BEGIN
	UPDATE securities SET active = FALSE WHERE id = security_id;
	RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION issue_dividend (security_id UUID, dividend_receiver UUID, dividend_amount NUMERIC) RETURNS VOID AS $$
BEGIN
    UPDATE accounts SET wdc = wdc - dividend_amount WHERE id = (SELECT owner FROM securities WHERE id = security_id);
    UPDATE accounts SET wdc = wdc + dividend_amount WHERE id = dividend_receiver;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION close_account (account_id UUID) RETURNS VOID AS $$
BEGIN
	UPDATE accounts SET active = FALSE WHERE id = account_id;
	INSERT INTO account_history (account,event) VALUES (account_id, 7);
	RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION have_enough_shares (shares_needed NUMERIC, account_val UUID, security_val UUID) RETURNS BOOLEAN AS $$
BEGIN
    IF (SELECT amount FROM shares_held WHERE account = account_val AND security = security_val) >= shares_needed THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION have_enough_coins (wdc_needed NUMERIC, account_val UUID) RETURNS BOOLEAN AS $$
BEGIN
    IF (SELECT wdc FROM accounts WHERE id = account_val) >= wdc_needed THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_password_reset_question_list() RETURNS SETOF password_reset_questions AS $$
BEGIN
    RETURN QUERY
        SELECT * FROM password_reset_questions;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_securities_held(account_val UUID) RETURNS SETOF held_security_data AS $$
DECLARE
    hsd held_security_data%rowtype;
    s UUID;
BEGIN
    FOR s IN 
        SELECT security FROM shares_held WHERE account = account_val
    LOOP
        SELECT
        (SELECT symbol FROM securities WHERE id = s),
        (SELECT name FROM securities WHERE id = s),
        (SELECT sum(amount) FROM shares_held WHERE security = s),
        (SELECT price FROM trade_history WHERE security = s ORDER BY price DESC LIMIT 1)
        INTO hsd;
        RETURN NEXT hsd;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_all_securities() RETURNS SETOF security_search_data AS $$
DECLARE
    ssd security_search_data%rowtype;
BEGIN
    FOR ssd IN
        SELECT securities.id, securities.name, securities.symbol, trade_history.price, security_types.description FROM securities LEFT OUTER JOIN trade_history ON securities.id = trade_history.security JOIN security_types ON securities.type = security_types.id
        WHERE securities.active = TRUE AND securities.denied != TRUE
    LOOP
        RETURN NEXT ssd;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_security_overview(security_symbol TEXT) RETURNS security_overview AS $$
DECLARE
	overview security_overview;
BEGIN
	SELECT
		securities.id,
		securities.symbol,
		securities.name,
		securities.contract_verbiage,
		securities.number_of_shares_issued,
		securities.date_approved,
		accounts.name,
		security_types.description,
		distribution_schedules.description,
		securities.description
	INTO overview
	FROM securities
	JOIN accounts ON 
		securities.owner = accounts.id
	JOIN security_types ON
		securities.type = security_types.id
	JOIN distribution_schedules ON
		securities.distribution_schedule = distribution_schedules.id
	WHERE
		lower(securities.symbol) = lower(security_symbol);
	RETURN overview;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_distribution_history(security_symbol TEXT) RETURNS SETOF distribution_history AS $$
BEGIN
	RETURN QUERY
		SELECT date_issued, amount_per_share, shares_paid FROM distributions 
		JOIN securities ON
			distributions.security = securities.id
		WHERE lower(securities.symbol) = lower(security_symbol)
		ORDER BY date_issued DESC;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_chart_data(security_symbol TEXT, limit_val INTEGER) RETURNS SETOF chart_data AS $$
DECLARE
    date_counter TIMESTAMP;
    security_id UUID;
    cd chart_data;
BEGIN
SELECT id INTO security_id FROM securities WHERE symbol = security_symbol;
    FOR date_counter IN
        SELECT DISTINCT execution_time::timestamp::date FROM trade_history WHERE security = security_id ORDER BY execution_time::timestamp::date LIMIT limit_val
    LOOP
        SELECT
        date_counter,
        (SELECT price FROM trade_history WHERE execution_time::timestamp::date = date_counter ORDER BY execution_time ASC LIMIT 1),
        (SELECT price FROM trade_history WHERE execution_time::timestamp::date = date_counter ORDER BY price DESC LIMIT 1),
        (SELECT price FROM trade_history WHERE execution_time::timestamp::date = date_counter ORDER BY price ASC LIMIT 1),
        (SELECT price FROM trade_history WHERE execution_time::timestamp::date = date_counter ORDER BY execution_time DESC LIMIT 1)
        INTO cd;
        RETURN NEXT cd;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_unapproved_securities() RETURNS SETOF unapproved_securities AS $$
BEGIN
    RETURN QUERY
        SELECT id, name, symbol FROM securities WHERE active = false AND denied != TRUE;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_site_config() RETURNS site_config AS $$
DECLARE
    sc site_config;
BEGIN
    SELECT * INTO sc FROM site_configuration;
    RETURN sc;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION open_trades_for_account_specific_security(account_val UUID,security_val UUID) RETURNS SETOF open_trade AS $$
DECLARE
    counter UUID;
    ot open_trade%rowtype;
    trade_type text;
BEGIN
    FOR counter IN
        SELECT id FROM open_trades WHERE account = account_val AND security = security_val
    LOOP
        IF (SELECT buy FROM open_trades WHERE id = counter) THEN
            trade_type := 'buy';
        ELSE
            trade_type := 'sell';
        END IF;
        SELECT
            counter,
            security_val,
            account_val,
            (SELECT price FROM open_trades WHERE id = counter),
            (SELECT number_of_shares FROM open_trades WHERE id = counter),
            trade_type
            INTO ot;
        RETURN NEXT ot;
    END LOOP;
END;
$$ LANGUAGE plpgsql;