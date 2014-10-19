package Wse::Security;
use Mojo::Base 'Mojolicious::Controller';

sub securities{
    my $self = shift;
    
    my $dbh = $self->app->dbh;
    my $query = "select * from get_all_securities()";
    my $sth = $dbh->prepare($query);
    $sth->execute;
    my $rs = $sth->fetchall_hashref('symbol');
    $self->stash(securities => $rs);
    
    $self->render(
        template => 'security',
		javascripts => [],
		styles => []
    );
}

sub individual_security {
    #TODO: reduce the number of database calls.  Make a larger sql function that returns this data
	my $self = shift;
	
	my $dbh = $self->app->dbh;
	my $query = "select * from get_open_buys_for_security(?)";
	my $sth = $dbh->prepare($query);
	$sth->execute($self->stash('security_symbol'));
	my $open_buys = $sth->fetchall_arrayref({});
	$query = "select * from get_open_sells_for_security(?)";
	$sth = $dbh->prepare($query);
	$sth->execute($self->stash('security_symbol'));
	my $open_sells = $sth->fetchall_arrayref({});
	$query = "select * from get_chart_data(?,?)";
	$sth = $dbh->prepare($query);
	$sth->execute($self->stash('security_symbol'),30);
	my $historical_prices = $sth->fetchall_arrayref({});
	$query = "select * from get_security_overview(?)";
	$sth = $dbh->prepare($query);
	$sth->execute($self->stash('security_symbol'));
	my $security_overview = $sth->fetchrow_hashref;
	$query = "select * from get_notes_for_security(?,?)";
	$sth = $dbh->prepare($query);
	$sth->execute($self->stash('security_symbol'),20);
	my $security_notes = $sth->fetchall_arrayref({});
	$query = "select * from get_distribution_history(?)";
	$sth = $dbh->prepare($query);
	$sth->execute($self->stash('security_symbol'));
	my $distribution_history = $sth->fetchall_arrayref({});
	$query = "select * from list_recent_trades(?,?)";
	$sth = $dbh->prepare($query);
	$sth->execute($self->stash('security_symbol'),30);
	my $recent_trades = $sth->fetchall_arrayref({});
	$query = "select wdc from accounts where id = ?";
    $sth = $dbh->prepare($query);
    $sth->execute($self->session->{'id'});
    my $wdc = $sth->fetchrow_hashref;
    my $security_id = $self->get_security_id($self->stash('security_symbol'));
    $query = "select amount from shares_held where account = ? and security = ?";
    $sth = $dbh->prepare($query);
    $sth->execute($self->session->{'id'},$security_id);
    my $shares = $sth->fetchrow_hashref;
    $query = "select * from open_trades_for_account_specific_security(?,?)";
    $sth = $dbh->prepare($query);
    $sth->execute($self->session->{'id'},$security_id->{'id'});
    my $your_open_trades = $sth->fetchall_arrayref({});
    $query = "select public_id from accounts join shares_held on accounts.id = shares_held.account where shares_held.security = ?";
    $sth = $dbh->prepare($query);
    $sth->execute($security_id);
    my $investors = $sth->fetchall_arrayref({});
    $query = "select date_issued from distributions where security = ? order by date_issued desc limit 1";
    $sth = $dbh->prepare($query);
    $sth->execute($security_id);
    my $last_issued_dividend = $sth->fetchrow_hashref;
    $query = "select count(*) from shares_held where security = ?";
    $sth = $dbh->prepare($query);
    $sth->execute($security_id);
    my $total_investors = $sth->fetchrow_hashref;
    
	$self->stash(
		historical_prices => $historical_prices,
		open_buys => $open_buys,
		open_sells => $open_sells,
		security_overview => $security_overview,
		security_notes => $security_notes,
		distribution_history => $distribution_history,
		recent_trades => $recent_trades,
        security_id => $security_id,
        wdc => $wdc->{'wdc'},
        shares => $shares->{'amount'},
        your_open_trades => $your_open_trades,
        investors => $investors,
        last_issued_dividend => $last_issued_dividend->{'date_issued'},
        total_investors => $total_investors->{'count'}
	);
	
	$self->render(
		template => 'individual_security',
		javascripts => ['jquery.jqplot.min.js','jqplot.dateAxisRenderer.min.js','jqplot.ohlcRenderer.min.js','jqplot.highlighter.min.js','security.js'],
		styles => ['individual_security.css','jquery.jqplot.min.css']
	);
}

sub post_sell{
    my $self = shift;

    if($self->session->{'logged_in'} == 1){
        my $dbh = $self->app->dbh;

        my $query = "select * from have_enough_shares(?,?,?)";
        my $sth = $dbh->prepare($query);
        $sth->execute($self->param('amount'),$self->session->{'id'},$self->param('security_id'));
        my $rs = $sth->fetchrow_hashref;
        if($rs->{'have_enough_shares'}){
            $query = "select * from fulfill_trade(?,?,?,?,?) AS remainder";
            $sth = $dbh->prepare($query);
            $sth->execute($self->param('amount'),$self->param('price_per'),'sell',$self->session->{'id'},$self->param('security_id'));
            my $leftover_order = $sth->fetchrow_hashref;
            if($leftover_order->{'remainder'} > 0){
                $query = "select * from list_trade(?,?,?,?,?)";
                $sth = $dbh->prepare($query);
                $sth->execute('sell',$self->param('price_per'),$self->session->{'id'},$self->param('security_id'),$leftover_order->{'remainder'});
            }
            $self->flash(success => 'Your trade posted successfully');
        } else {
            $self->flash(error => 'You do not have enough shares to list your trade');
        }
    } else {
        $self->flash(error => 'You need to log in to post a trade');
    }
    $self->redirect_to($self->req->headers->referrer);
}

sub post_buy{
    my $self = shift;
    
    if($self->session->{'logged_in'} == 1){
        my $dbh = $self->app->dbh;
        if($self->have_enough_coins($self->param('total_buy'))){
            $query = "select * from fulfill_trade(?,?,?,?,?) AS remainder";
            $sth = $dbh->prepare($query);
            $sth->execute($self->param('amount'),$self->param('price_per'),'buy',$self->session->{'id'},$self->param('security_id'));
            my $leftover_order = $sth->fetchrow_hashref;
            if($leftover_order->{'remainder'} > 0){
                my $query = "select * from list_trade(?,?,?,?,?)";
                my $sth = $dbh->prepare($query);
                $sth->execute('buy',$self->param('price_per'),$self->session->{'id'},$self->param('security_id'),$leftover_order->{'remainder'});
            }
            $self->flash(success => 'Your trade posted successfully');
        } else {
            $self->flash(error => 'You do not have enough coins to list your trade');
        }
    } else {
        $self->flash(error => 'You need to log in to post a trade');
    }
    $self->redirect_to($self->req->headers->referrer);

}

sub create{
    my $self = shift;
    
    if($self->session->{'logged_in'} == 1){
        my $dbh = $self->app->dbh;
        my $query = "select * from duplicate_security_check(?,?)";
        my $sth = $dbh->prepare($query);
        $sth->execute($self->param('name'),$self->param('security'));
        my $rs = $sth->fetchrow_hashref;
        if($rs->{'duplicate_security_check'} == 1){
            $self->flash(error => 'Security name already in use');
            $self->redirect_to($self->req->headers->referrer);
        } elsif($rs->{'duplicate_security_check'} == 2){
            $self->flash(error => 'Security symbol already in use');
            $self->redirect_to($self->req->headers->referrer);
        } else {
            $query = "select * from list_security(?,?,?,?,?,?,?,?)";
            $sth = $dbh->prepare($query);
            $sth->execute($self->param('name'),$self->param('description'),$self->param('symbol'),$self->param('number_of_shares'),$self->param('contract'),$self->param('distribution_schedule'),$self->session->{'id'},$self->param('security_type'));
            my $security_id = $sth->fetchrow_hashref;
            ##### giving wse their shares of the new security #####
            $query = "select id from accounts where name = ?";
            $sth = $dbh->prepare($query);
            $sth->execute('wse');
            my $wse_id = $sth->fetchrow_hashref;
            my $shares_to_wse = int($self->param('number_of_shares') * .001);
            $query = "insert into shares_held(account,security,amount) values(?,?,?)";
            $sth = $dbh->prepare($query);
            $sth->execute($wse_id->{'id'},$security_id->{'list_security'},$shares_to_wse);
            $query = "update shares_held set amount = ? where account = ? and security = ?";
            $sth = $dbh->prepare($query);
            my $new_share_amount = $self->param('number_of_shares') - $shares_to_wse;
            $sth->execute($new_share_amount,$self->session->{'id'},$security_id->{'list_security'});
            ###### end #####
            $self->flash(success => 'Your security has been successfully submitted for approval');
            $self->redirect_to($self->url_for('profile'));
        }
    } else {
        $self->flash(error => 'You need to login before creating a security');
        $self->redirect_to($self->url_for('login'));
    }
}

sub approve{
    my $self = shift;
    
    if($self->session->{'logged_in'} == 1){
        my $dbh = $self->app->dbh;
        my $query = "select approve_security(?)";
        my $sth = $dbh->prepare($query);
        $sth->execute($self->param('security'));
        $self->flash(success => 'Security has been approved');
        $self->render(txt => '1');
    } else {
        $self->flash(error => 'You need to login before approving a security');
        $self->redirect_to($self->url_for('login'));
    }
}

sub decline{
    my $self = shift;
    
    if($self->session->{'logged_in'} == 1){
        my $dbh = $self->app->dbh;
        my $query = "select decline_security(?)";
        my $sth = $dbh->prepare($query);
        $sth->execute($self->param('security'));
        $self->flash(error => 'Security has been declined');
        $self->render(txt => '1');
    } else {
        $self->flash(error => 'You need to login before declining a security');
        $self->redirect_to($self->url_for('login'));
    }
}

sub cancel{
    my $self = shift;
    
    if($self->session->{'logged_in'} == 1){
        my $dbh = $self->app->dbh;
        my $query = "select cancel_trade(?,?)";
        my $sth = $dbh->prepare($query);
        $sth->execute($self->param('trade_id'),$self->session->{'id'});
        $self->flash(success => 'Successfully cancelled trade');
        $self->render(txt => '1');
    } else {
        $self->flash(error => 'You need to login before cancelling a trade');
        $self->redirect_to($self->url_for('login'));
    }
}

sub add_note{
	my $self = shift;

	my ($security_id,$note,$title) = ($self->param('id'),$self->scrub_html($self->param('add_note')),$self->scrub_html($self->param('title')));
	
	my $dbh = $self->app->dbh;
	my $query = "select owner from securities where id = ?";
	my $sth = $dbh->prepare($query);
	my $rs = $sth->fetchrow_hashref;
	if($self->session->{'logged_in'} == 1 && $rs->{'owner'} eq $security_id){
		$query = "select add_note(?,?,?)";
		$sth = $dbh->prepare($query);
		$sth->execute($security_id,$note,$title);
		$self->flash(success => 'Added your note');
	} else {
		$self->flash(error => 'You need to be logged in and the owner of the security to leave a note.');
	}
	$self->redirect_to($self->req->headers->referrer);
}

sub issue_dividend{
    my $self = shift;
    
    my $dbh = $self->app->dbh;
	my $query = "select owner from securities where id = ?";
	my $sth = $dbh->prepare($query);
	my $rs = $sth->fetchrow_hashref;
    if($self->session->{'logged_in'} == 1 && $rs->{'owner'} eq $self->param('security_id')){
        my $coins_needed = $self->param('investors') * $self->param('dividend_amount');
        if($self->have_enough_coins($coins_needed)){
            $query = "select count(*) from shares_held where security = ?";
            $sth = $dbh->prepare($query);
            $sth->execute($self->param('security_id'));
            my $total_dividend = $sth->fetchrowh_hashref;
            $total_dividend = $total_dividend->{'count'} * 
            $query = "select account,amount from shares_held where security = ?";
            $sth = $dbh->prepare($query);
            $sth->execute($self->param('security_id'));
            my $investor_info = $sth->fetchall_arrayref({});
            foreach (@{$investor_info}){
                my $dividend_amount = $_->{'amount'} * $self->param('dividend_amount');
                $query = "select * from issue_dividend(?,?,?)";
                $sth = $dbh->prepare($query);
                $sth->execute($self->param('security_id'),$_->{'account'},$dividend_amount);
            }
            $self->flash(success => 'Dividends issued');
            $self->redirect_to($self->req->headers->referrer);
        } else {
            $self->flash(error => 'You do not have enough coins in your account to issue dividends.  Please check your balance.  If you think this message is in error, contact support');
            $self->redirect_to($self->req->headers->referrer);
        }
    } else {
        # Implement better logging here
        warn "Someone from IP: " . $self->tx->remote_address . " tried to issue a dividend for security: " . $self->param('security_id');
        $self->flash(error => 'You need to be logged in and the owner of the security before issuing dividends');
        $self->redirect_to($self->url_for('securities'));
    }

}

1;