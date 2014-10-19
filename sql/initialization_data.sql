COMMENT ON TABLE account_history IS 'This table will log every time an account is disabled, failed login, account setting change, etc...';
COMMENT ON FUNCTION search_for_security(TEXT) IS 'This will take input from a user and try to find securities that match by name, symbol or description.';

INSERT INTO distribution_schedules (description) VALUES ('Daily');
INSERT INTO distribution_schedules (description) VALUES ('Weekly');
INSERT INTO distribution_schedules (description) VALUES ('Monthly');
INSERT INTO distribution_schedules (description) VALUES ('Quarterly');
INSERT INTO distribution_schedules (description) VALUES ('Biannual');
INSERT INTO distribution_schedules (description) VALUES ('Annually');

INSERT INTO account_event_types (description) VALUES ('Email Address Change');
INSERT INTO account_event_types (description) VALUES ('Password Change');
INSERT INTO account_event_types (description) VALUES ('Login');
INSERT INTO account_event_types (description) VALUES ('Failed Login');
INSERT INTO account_event_types (description) VALUES ('Withdraw Address Change');
INSERT INTO account_event_types (description) VALUES ('Deposit Address Change');
INSERT INTO account_event_types (description) VALUES ('Closed Account');
INSERT INTO account_event_types (description) VALUES ('Timezone Change');

INSERT INTO password_reset_questions (question) VALUES ('What is your mother''s maiden name?');
INSERT INTO password_reset_questions (question) VALUES ('Where did you go to highschool?');

INSERT INTO security_types (description) VALUES ('Stock');
INSERT INTO security_types (description) VALUES ('Bond');

INSERT INTO site_configuration (id,site_name,email_server_address,hot_wallet_ip_address) VALUES (1,'Worldcoin Security Exchange','127.0.0.1','127.0.0.1');

select * from register('wse', 'A!asd9d7fja',1,'not to login with','wse@wse.com','12d3da4');
select * from activate('wse','12d3da4');