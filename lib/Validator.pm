package Validator;

#validator version 1.1

sub new{
	my $class = shift;
	my $self = bless {}, $class;
	
	return $self;
}

sub validate{
	my ($self, $data) = @_;
	my $valid = 1;
	
	my @failed_rules = ();
	my @failed_fields = ();
	$self->{'errors'} = {};
	$self->{'failed_fields'} = {};
	
	foreach my $field (keys %{$self->{'rules'}}){
		foreach my $rule (@{$self->{'rules'}->{$field}->{'rules'}}){
			if(ref($rule) eq 'HASH'){
				foreach my $key (keys %{$rule}){
					if($key eq 'match'){
						if(!match($data->{$field},$data->{$rule->{$key}})){
							$valid = 0;
							push(@failed_fields,$field);
							push(@failed_rules,$self->{'rules'}->{$field}->{'error'}->{$rule});
						}
					} elsif ($key eq 'exact_length') {
						if(!exact_length($rule->{$key},$data->{$field})){
							$valid = 0;
							push(@failed_fields,$field);
							push(@failed_rules,$self->{'rules'}->{$field}->{'error'}->{$key});
						}
					}
				}
			} else {
				unless(&$rule($data->{$field})){
					unless(!is_required($field,$self->{'rules'}) && is_empty($data->{$field})){
						$valid = 0;
						push(@failed_fields,$field);
						push(@failed_rules,$self->{'rules'}->{$field}->{'error'}->{$rule});
					}
				}
			}
		}
	}
	$self->{'failed_fields'} = \@failed_fields;
	$self->{'errors'} = \@failed_rules;
	$self->{'rules'} = {};
	return $valid;
}

sub rules{
	my ($self,$rules) = @_;
	
	$self->{'rules'} = $rules;
	
	return;
}

sub match{
	my ($orig,$match) = @_;
	if($orig =~ m/^$match$/){
		return 1;
	} else {
		return 0;
	}
}

sub email{
	my $data = shift;
	if($data =~ m/.+@.+\.[\w{2}|\w{3}|\w{4}]/){
		return 1;
	} else {
		return 0;
	}
}

sub telephone{
	my $data = shift;
	
	if($data =~ m/\d{3}.*\d{3}.*\d{4}/){
		return 1;
	} else {
		return 0;
	}
}

sub required{
	my $data = shift;
	if($data =~ m/.+/){
		return 1;
	} else {
		return 0;
	}
}

sub min_length{
	
}

sub max_length{
	
}

sub exact_length{
	my ($length,$data) = @_;
	if($data =~ m/^.{$length}$/){
		return 1;
	} else {
		return 0;
	}
}

sub zip{
	my $data = shift;
	
	if($data =~ m/^\d{5}$/ || $data =~ m/^\d{5}-\d{4}$/){
		return 1;
	} else {
		return 0;
	}
}

sub alpha{
	my $data = shift;
	
	if($data =~ m/^\w+$/){
		return 1;
	} else {
		return 0;
	}
}

sub numeric{
	my $data = shift;
	
	if($data =~ m/^\d+$/){
		return 1;
	} else {
		return 0;
	}
}

sub is_required{ #checks the rules and returns 1 if it is required and 0 if it is not
	my ($field,$rules) = @_;

	foreach my $value (@{$rules->{$field}->{'rules'}}){
		if($value eq 'required'){
			return 1;
		}
	}
	
	return 0;
}

sub is_empty{ #checks if the field is empty. returns 1 if it is, 0 if it is not
	my $data = shift;
	
	if($data =~ m/.+/){
		return 0;
	} else {
		return 1;
	}
}

sub get_errors{
	my $self = shift;

	my $errors;

	for(my $i = 0; $i < scalar(@{$self->{'failed_fields'}}); $i++){
		$errors->{$self->{'failed_fields'}->[$i]} = $self->{'errors'}->[$i];
	}
	return $errors;
}

sub clear_errors{
	my $self = shift;

	delete($self->{'failed_fields'});
	delete($self->{'errors'});
	
	return;
}
1;