select * from register('test_owner', 'test',1,'test answer','test_owner@test.com','12d3da4');
select * from activate('test_owner','12d3da4');
select list_security('test security 1','First Test Security','TS1',10000,'This is some made up contract1',1,(SELECT id FROM accounts WHERE name = 'test_owner'),1);
select list_security('test security 2','Second Test Security','TS2',5000,'This is some made up contract2',3,(SELECT id FROM accounts WHERE name = 'test_owner'),2);
select approve_security((SELECT id FROM securities WHERE symbol = 'TS1'));
select approve_security((SELECT id FROM securities WHERE symbol = 'TS2'));
update accounts set wdc = 100000;
update account_profile set withdraw_address = '6sadfhas6sadfsadfjalfdy98saf';
update account_profile set deposit_address = 'asdf67asdfjkwaer67sadfsadf67';
insert into distributions (amount_per_share,shares_paid,security) values (3,2453,(SELECT id FROM securities WHERE symbol = 'TS1'));
insert into distributions (amount_per_share,shares_paid,security) values (2.43,5453,(SELECT id FROM securities WHERE symbol = 'TS1'));
insert into distributions (amount_per_share,shares_paid,security) values (1.8345,4673,(SELECT id FROM securities WHERE symbol = 'TS1'));
insert into distributions (amount_per_share,shares_paid,security) values (3.5326,7453,(SELECT id FROM securities WHERE symbol = 'TS1'));
insert into distributions (amount_per_share,shares_paid,security) values (2.987,8453,(SELECT id FROM securities WHERE symbol = 'TS1'));
select add_note(
    (SELECT id FROM securities WHERE symbol = 'TS1'),
    'This be a note to the user',
    'Just testing out the note adding SQL function.  Looks like it is adding notes');
insert into trade_history (execution_time,seller,buyer,number_of_shares,buy_or_sell,price,security)
    values (
        '2014-06-09 06:23:12',
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        2,
        'buy',
        1.21,
        (SELECT id FROM securities WHERE symbol = 'TS1')),
        (
        '2014-06-09 16:23:12',
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        1,
        'buy',
        1.25,
        (SELECT id FROM securities WHERE symbol = 'TS1')),
        (
        '2014-06-10 08:23:12',
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        2,
        'buy',
        1.3,
        (SELECT id FROM securities WHERE symbol = 'TS1')),
        (
        '2014-06-10 12:23:12',
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        2,
        'buy',
        1.7,
        (SELECT id FROM securities WHERE symbol = 'TS1')),
        (
        '2014-06-11 06:23:12',
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        2,
        'buy',
        1.8,
        (SELECT id FROM securities WHERE symbol = 'TS1')),
        (
        '2014-06-11 13:23:12',
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        4,
        'sell',
        1.4,
        (SELECT id FROM securities WHERE symbol = 'TS1')),
        (
        '2014-06-14 06:23:12',
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        4,
        'sell',
        1.1,
        (SELECT id FROM securities WHERE symbol = 'TS1')),
        (
        '2014-06-14 09:23:12',
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        4,
        'buy',
        1.3,
        (SELECT id FROM securities WHERE symbol = 'TS1')),
        (
        '2014-06-14 18:23:12',
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        (SELECT id FROM accounts ORDER BY RANDOM() LIMIT 1),
        4,
        'buy',
        2.08,
        (SELECT id FROM securities WHERE symbol = 'TS1'));