CREATE EXTENSION "uuid-ossp";
CREATE EXTENSION "pgcrypto";

CREATE TABLE accounts(
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    pswhash TEXT NOT NULL,
    date_created TIMESTAMP DEFAULT now() NOT NULL,
    last_login TIMESTAMP,
    active BOOLEAN DEFAULT false,
    activation_code TEXT NOT NULL,
	wdc NUMERIC DEFAULT 0,
    currently_logged_in BOOLEAN DEFAULT FALSE NOT NULL,
    administrator BOOLEAN DEFAULT FALSE NOT NULL,
    public_id UUID DEFAULT uuid_generate_v4()
);

CREATE TABLE password_reset_questions(
    id SERIAL PRIMARY KEY,
    question TEXT NOT NULL
);

CREATE TABLE account_profile(
    account UUID references accounts(id) NOT NULL,
    time_zone SMALLINT DEFAULT 0 NOT NULL,
    password_reset_question INT references password_reset_questions(id) NOT NULL,
    password_reset_answer TEXT NOT NULL,
    withdraw_address TEXT,
    deposit_address TEXT,
    email TEXT
);

CREATE TABLE distribution_schedules(
    id SERIAL PRIMARY KEY,
    description TEXT NOT NULL
);

CREATE TABLE security_types(
    id SERIAL PRIMARY KEY,
    description TEXT
);

CREATE TABLE securities(
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    symbol TEXT NOT NULL,
    number_of_shares_issued BIGINT NOT NULL,
    contract_verbiage TEXT,
    distribution_schedule INT references distribution_schedules(id) NOT NULL,
    date_created TIMESTAMP DEFAULT now() NOT NULL,
    active BOOLEAN DEFAULT FALSE,
    date_approved TIMESTAMP,
    owner UUID references accounts(id),
    type INTEGER references security_types(id),
    denied BOOLEAN DEFAULT FALSE,
    denied_date TIMESTAMP
);

CREATE TABLE security_notes(
    security UUID references securities(id),
    note_title TEXT,
    created TIMESTAMP DEFAULT now() NOT NULL,
    note TEXT NOT NULL
);

CREATE TABLE shares_held(
    account UUID references accounts(id) NOT NULL,
    security UUID references securities(id) NOT NULL,
    amount BIGINT NOT NULL
);

CREATE TABLE distributions(
    date_issued TIMESTAMP DEFAULT now() NOT NULL,
    amount_per_share NUMERIC NOT NULL,
    shares_paid BIGINT NOT NULL,
    security UUID references securities(id) NOT NULL
);

CREATE TABLE open_trades(
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
    security UUID references securities(id) NOT NULL,
    account UUID references accounts(id) NOT NULL,
    price NUMERIC NOT NULL,
    number_of_shares NUMERIC NOT NULL,
    sell BOOLEAN,
    buy BOOLEAN
);

CREATE TABLE trade_history(
    execution_time TIMESTAMP DEFAULT now(),
    seller UUID references accounts(id) NOT NULL,
    buyer UUID references accounts(id) NOT NULL,
    number_of_shares NUMERIC NOT NULL,
    buy_or_sell TEXT,
    price NUMERIC NOT NULL,
    security UUID references securities(id) NOT NULL
);

CREATE TABLE account_history(
    account UUID references accounts(id) NOT NULL,
    event INTEGER NOT NULL,
    took_place TIMESTAMP DEFAULT now()
);

CREATE TABLE account_event_types(
    id SERIAL PRIMARY KEY,
    description TEXT NOT NULL
);

CREATE TABLE site_configuration(
    id SMALLINT CHECK (id = 1),
    site_name TEXT NOT NULL,
    email_server_address TEXT NOT NULL,
    hot_wallet_ip_address TEXT,
    hot_wallet_address TEXT,
    cold_wallet_address TEXT,
    rpcuser TEXT,
    rpcpassword TEXT
);

CREATE TABLE messages(
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender UUID references accounts(id) NOT NULL,
    on_behalf_of UUID references securities(id),
    recipient UUID references accounts(id) NOT NULL,
    sent_on TIMESTAMP DEFAULT now() NOT NULL,
    subject TEXT NOT NULL,
    message_body TEXT NOT NULL,
    "read" BOOLEAN DEFAULT false NOT NULL
);

CREATE TABLE deposit_history(
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account UUID references accounts(id) NOT NULL,
    amount NUMERIC NOT NULL,
    tx_id TEXT NOT NULL,
    sending_address TEXT NOT NULL,
    receiving_address TEXT NOT NULL
);

CREATE TABLE withdraw_history(
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account UUID references accounts(id) NOT NULL,
    amount NUMERIC NOT NULL,
    tx_id TEXT NOT NULL,
    sending_address TEXT NOT NULL,
    receiving_address TEXT NOT NULL
);

CREATE TABLE errors(
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    severity TEXT,
    message TEXT,
	occured_at TIMESTAMP DEFAULT now()
);

CREATE TABLE bad_login_attempt(
    ip_address TEXT,
    login_time TIMESTAMP DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON accounts TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON account_profile TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON securities TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON security_issuers TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON shares_held TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON distributions TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON open_trades TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON trade_history TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON account_history TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON account_event_types TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON site_configuration TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON password_reset_questions TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON distribution_schedules TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON messages TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON security_notes TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON security_types TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON deposit_history TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON withdraw_history TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON errors TO wseuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON bad_login_attempt TO wseuser;

GRANT ALL ON account_event_types_id_seq TO wseuser;
GRANT ALL ON password_reset_questions_id_seq TO wseuser;
GRANT ALL ON distribution_schedules_id_seq TO wseuser;
GRANT ALL ON security_types_id_seq TO wseuser;