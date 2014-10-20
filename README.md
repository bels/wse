WSE
===

Worldcoin Securities Exchange is an open source exchange that allows someone to host several companies' security offerings (bond/stock).  Worldcoin is a leading crypto currency that allows for fast transactions and is suited well for doing business.  More proper documentation will follow shortly.  Patches are welcome.  This code is BSD licensed and I welcome anyone to use it within the boundaries of that license.  Any bug reports or enhancement requests should be entered into the issue tracker here on github.

Prerequisites
===

- Mojolicious
- *BSD/Linux
- Postgresql 9.2+

Perl Modules

- DBI
- DBD::Pg
- Net::SMTP
- JSON::RPC::Client

Install
===

Code

1. Install Mojolicious
2. Place code in a directory that has suitable permissions on it
3. Delete the sql and t directories (after you import the SQL)
4. Run hypnotoad on script/wse
5. Go to IP_of_server:8080

SQL

1. Import data_type.sql
2. Import main.sql
3. Import functions.sql
4. Import initialization_data.sql

Testing
===

If you would like to run WSE in a test environment I recommend the following procedure

1. Install the web app and SQL files
2. Create a user through the web interface
3. Import test_data.sql
4. Tie the test user to a worldcoin address on your testnet (you may will have to sort out the WDC balances in the app and on testnet)
