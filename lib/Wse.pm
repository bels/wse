package Wse;
use Mojo::Base 'Mojolicious';

use Validator;
use DBI;
use Net::SMTP;
use JSON::RPC::Client;

has dbh => sub {
	my $self = shift;
	
	my $data_source = "dbi:Pg:host=localhost dbname=wse";
	my $username = 'wseuser';
	my $password = 'CHANGEME';
	
	my $dbh = DBI->connect(
		$data_source,
		$username,
		$password,
		{RaiseError => 1}
	);
	
	return $dbh;
};

# This method will run once at server start
sub startup {
    my $self = shift;


    #session cookie stuff
    $self->secrets(['wse','another_secret','worldcoin','worldcoin_is_awesome','youshouldchangethese']);
    $self->sessions->default_expiration('3600');
    #end session cookie stuff

    my $validator = Validator->new();
	$self->helper(validator => sub {return $validator});
    $self->helper(just_date => sub {
       my ($self,$date) = @_;

       my @date_array = split(/\s/,$date);
       return $date_array[0];
    });
    $self->helper(trim_milliseconds => sub{
        my ($self,$date) = @_;
    
        my @date_array = split(/\./,$date);
        return $date_array[0];
    });
    $self->helper(minus_one_day => sub{
        my ($self,$date) = @_;
    
        my @date_array1 = split(/\s/,$date);
        my @date_array2 = split(/-/,$date_array1[0]);
        if(($date_array2[2] - 1) < 1){
            $date_array2[1]--;
            $date_array2[2] = '31';
        } else {
            $date_array2[2]--;
        }
        my $new_date = $date_array2[0] . '-' . $date_array2[1] . '-' . $date_array2[2] . ' ' . $date_array1[1];
        return $new_date;
    });
    $self->helper(add_one_day => sub{
        my ($self,$date) = @_;
    
        my @date_array1 = split(/\s/,$date);
        my @date_array2 = split(/-/,$date_array1[0]);
        if(($date_array2[2] + 1) > 31){
            $date_array2[1]++;
            $date_array2[2] = '01';
        } else {
            $date_array2[2]++;
        }
        my $new_date = $date_array2[0] . '-' . $date_array2[1] . '-' . $date_array2[2] . ' ' . $date_array1[1];
        return $new_date;
    });
    
    $self->helper(get_security_id => sub{
        my ($self,$symbol) = @_;
        
        my $dbh = $self->app->dbh;
        my $query = "select id from securities where symbol = ?";
        my $sth = $dbh->prepare($query);
        $sth->execute($symbol);
        my $rs = $sth->fetchrow_hashref;
        
        return $rs->{'id'};
    });
    
    $self->helper(send_email => sub{
        my ($self,$data) = @_;
        
        my $from = 'wse@changeme.com';
        my $sending_user = 'wsemail';
        
        my $smtp = Net::SMTP->new($data->{'mail_server'}, Hello => $data->{'mail_server'}) or return();
        $smtp->auth($sending_user,'CHANGEME');
        $smtp->mail($from);
        $smtp->to($data->{'email'});
        
        $smtp->data();
        $smtp->datasend("To: " . $data->{'email'} . "\n");
        $smtp->datasend("From: $from\n");
        $smtp->datasend("Subject: " . $data->{'subject'} . "\n");
        $smtp->datasend("\n");

        $smtp->datasend($data->{'message_body'});
        $smtp->dataend();
        $smtp->quit;
    });
    
    $self->helper(get_new_address => sub {
        my ($self,$data) = @_;
    
        my $client = new JSON::RPC::Client;
        my $dbh = $self->app->dbh;
        my $query = "select rpcuser,rpcpassword,hot_wallet_ip_address,hot_wallet_address from site_configuration";
        my $sth = $dbh->prepare($query);
        $sth->execute;
        my $hot_wallet = $sth->fetchrow_hashref;
        $client->ua->credentials(
            $hot_wallet->{'hot_wallet_ip_address'} . ':11082', 'jsonrpc', $hot_wallet->{'rpcuser'} => $hot_wallet->{'rpcpassword'}
        );
        my $request = {
            method => 'getnewaddress',
            params => []
        };
		my $uri = 'http://' . $hot_wallet->{'hot_wallet_ip_address'}. ':11082';
        my $res = $client->call($uri,$request) or die "Couldn't connect to worldcoin daemon when generating a new address\n";
        if ($res){
            if ($res->is_error) { 
                $query = "insert into errors (severity,message) values(?,?)";
                $sth = $dbh->prepare($query);
                $sth->execute('warning',$client->status_line);
            } else {
				return $res->result;
            }
        } else {
            $query = "insert into errors (severity,message) values(?,?)";
            $sth = $dbh->prepare($query);
            $sth->execute('warning',$client->status_line);
        }

        return;
    });
    
    $self->helper(check_balance => sub{
        my ($self,$data) = @_;
    
        my $ua = Mojo::UserAgent->new;
		my $url = 'www.worldcoinexplorer.com/api/address/' . $data->{'address'};
		my $result = $ua->get($url);

		my $string = $result->res->body;
		$string =~ s/[{"}]//g;
		$string =~ s/,/:/g;
		my %res = split(/:/,$string);
		my $dbh = $self->app->dbh;
        if (exists($res{'Balance'})){
            if (!defined($res{'Balance'})) { 
                $self->flash(error => 'There is an error with checking your balance. Please contact support and give them this error code: 404');
                my $query = "insert into errors (severity,message) values(?,?)";
                my $sth = $dbh->prepare($query);
                $sth->execute('error','Worldcoin explorer did not return a balance');
            } else {
				my $query = "update accounts set wdc = ? where id = ?";
				my $sth = $dbh->prepare($query);
				$sth->execute($res{'Balance'},$data->{'id'});
                return $res{'Balance'};
            }
        } else {
            my $query = "insert into errors (severity,message) values(?,?)";
            my $sth = $dbh->prepare($query);
            $sth->execute('error',"Worldcoin explorer didn''t return anything. It may be down.");
        }

        return;
    });
    
	$self->helper(have_enough_coins => sub{
		my ($self,$data) = @_;
		
		my $dbh = $self->app->dbh;
		my $query = "select * from have_enough_coins(?,?)";
        my $sth = $dbh->prepare($query);
        $sth->execute($data->{'coins_needed'},$self->session->{'id'});
        my $rs = $sth->fetchrow_hashref;
		
		return $rs->{'have_enough_coins'};
	});
	
	$self->helper(have_enough_shares => sub {
        #TODO: move the have enough shares check here
	});
	
    $self->helper(withdraw_funds => sub {
        my ($self,$data) = @_;
        
        my $client = new JSON::RPC::Client;
        my $dbh = $self->app->dbh;
        my $query = "select rpcuser,rpcpassword,hot_wallet_ip_address,hot_wallet_address from site_configuration";
        my $sth = $dbh->prepare($query);
        $sth->execute;
        my $hot_wallet = $sth->fetchrow_hashref;
        $client->ua->credentials(
            $hot_wallet->{'hot_wallet_ip_address'} . ':11082', 'jsonrpc', $hot_wallet->{'rpcuser'} => $hot_wallet->{'rpcpassword'}
        );
		my $amount = $data->{'withdraw_amount'} + 0.0;
        my $request = {
            method => 'sendtoaddress',
            params => [
                $data->{'withdraw_address'},
                $amount
            ]
        };

		my $uri = 'http://' . $hot_wallet->{'hot_wallet_ip_address'} . ':11082';
        my $res = $client->call($uri,$request);
        if ($res){
            if ($res->is_error) { 
                $self->flash(error => 'There is an error with your withdraw. Please contact support and give them this message: ' . $res->error_message);
                $query = "insert into errors (severity,message) values(?,?)";
                $sth = $dbh->prepare($query);
                $sth->execute('warning',$client->status_line);
            } else {
                $query = "insert into withdraw_history (account,amount,tx_id,sending_address,receiving_address) values(?,?,?,?,?)";
                $sth = $dbh->prepare($query);
                $sth->execute($self->session->{'id'},$amount,$res->result,$hot_wallet->{'hot_wallet_address'},$self->param('withdraw_address'));
                $self->flash(success => 'Your funds withdrew successfully.  You should have them soon.  The TX ID is: ' . $res->result);
            }
        } else {
            $query = "insert into errors (severity,message) values(?,?)";
            $sth = $dbh->prepare($query);
            $sth->execute('warning',$client->status_line);
            $self->flash(error => 'Your withdraw did not go through. Try again later');
        }
    
    });
    
    $self->helper(transfer_funds => sub {
        my ($self,$data) = @_;
        #used to send wdc to user after a purchase or dividend
        my $request;
        # mode 1 = single address
        # mode 2 = multiple address
        if($data->{'mode'} == 1){
            my $amount = $data->{'amount'} + 0.0;
            $request = {
                method => 'sendtoaddress',
                params => [
                    $data->{'address'},
                    $amount
                ]
            };
        } elsif($data->{'mode'} == 2){
            my $addresses = [];
            foreach (@{$data->{'addresses'}}){
                my $amount = $data->{'amount'} + 0.0;
                my $d = $_ . ':' . $amount;
                push(@{$addresses},$d);
            }
            $request = {
                method => 'sendmany',
                params => [
                    $data->{'account'},
                    $addresses
                ]
            };
        } else {
            #unknown mode, needs logging
        }
        my $client = new JSON::RPC::Client;
        my $dbh = $self->app->dbh;
        my $query = "select rpcuser,rpcpassword,hot_wallet_ip_address,hot_wallet_address from site_configuration";
        my $sth = $dbh->prepare($query);
        $sth->execute;
        my $hot_wallet = $sth->fetchrow_hashref;
        $client->ua->credentials(
            $hot_wallet->{'hot_wallet_ip_address'} . ':11082', 'jsonrpc', $hot_wallet->{'rpcuser'} => $hot_wallet->{'rpcpassword'}
        );
        my $uri = 'http://' . $hot_wallet->{'hot_wallet_ip_address'}. ':11082';
        my $res = $client->call($uri,$request);
		if ($res){
            if ($res->is_error) { 
                $self->flash(error => 'There is an error sending your dividends. Please contact support and give them this message: ' . $res->error_message);
                $query = "insert into errors (severity,message) values(?,?)";
                $sth = $dbh->prepare($query);
                $sth->execute('warning',$client->status_line);
            } else {
                $query = "insert into withdraw_history (account,amount,tx_id,sending_address,receiving_address) values(?,?,?,?,?)";
                $sth = $dbh->prepare($query);
                $sth->execute($self->session->{'id'},$hot_wallet->{'hot_wallet_ip_address'},$res->id,$hot_wallet->{'hot_wallet_address'},$self->param('withdraw_address'));
                $self->flash(success => 'Your dividends sent correctly');
            }
        } else {
            $query = "insert into errors (severity,message) values(?,?)";
            $sth = $dbh->prepare($query);
            $sth->execute('warning',$client->status_line);
            $self->flash(error => 'Your dividends did not send.  Contact support or wait a little while and try again.');
        }
    });
    
    $self->helper(scrub_html => sub {
        my ($self,$data) = @_;

        $data =~ s/<script>|<\/script>|\bon.+\s*=//i;

        return $data;
    });
    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->route('/')->to('w#index')->name('index');
    $r->route('/register')->to('account#register')->name('register');
    $r->post('/register_submit')->to('account#register_submit')->name('register_submit');
    $r->route('/activate/:name/:code')->to('account#activate')->name('activate_account');
    $r->get('/login')->to('account#login')->name('login');
    $r->post('/auth')->to('account#auth')->name('auth');
    $r->route('/logout')->to('account#logout')->name('logout');
    $r->route('/profile')->to('account#profile')->name('profile');
	$r->route('/set_withdraw_address')->to('account#set_withdraw_address')->name('set_withdraw_address');
    $r->route('/support')->to('w#support')->name('support');
    $r->route('/securities')->to('security#securities')->name('securities');
    $r->route('/securities/create')->to('security#create')->name('create_security');
    $r->route('/securities/approve')->to('security#approve')->name('approve_security');
    $r->route('/securities/decline')->to('security#decline')->name('decline_security');
    $r->route('/securities/:security_symbol')->to('security#individual_security')->name('securities');
    $r->route('/trade/sell')->to('security#post_sell')->name('post_sell');
    $r->route('/trade/buy')->to('security#post_buy')->name('post_buy');
    $r->route('/trade/cancel/:id')->to('security#cancel')->name('cancel');
    $r->route('/admin')->to('system#admin')->name('admin');
    $r->route('/faq')->to('w#faq')->name('faq');
    $r->route('/withdraw')->to('account#withdraw')->name('withdraw');
    $r->route('/change_password')->to('account#change_password')->name('change_password');
    $r->route('/add_note')->to('security#add_note')->name('add_note');
    $r->route('/issue_dividend')->to('security#issue_dividend')->name('issue_dividend');
}

1;
