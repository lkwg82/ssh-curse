#!/bin/perl

$|=1;


use diagnostics;
use strict;
use warnings;

use Data::Dumper;

my $ssh_config  = &read_ssh_config;

#exit;

use Curses::UI;
my $cui = Curses::UI->new(
	-color_support,-clear_on_exit,-mouse_support
);

my $w = $cui->width();
my $h = $cui->height();

sub exit_dialog() {
	my $return = $cui->dialog(
		-message => "Do you really want to quit?",
		-title   => "Are you sure???",
		-buttons => [ 'yes', 'no' ],
		-border  => 1,

	);

	exit(0) if $return;
}

my %options = (
	-title  => 'profile',
	-width  => $w / 3,
	-height => $h,
	-border => 1,
	-padtop => 3,
);

my %options_info = (
	-title  => 'infos',
	-width  => $w,
	-height => 3,
	-border => 1,
);

my %options2 = (
	-title   => 'details',
	-width   => $w,
	-height  => $options{-height},
	-border  => 1,
	-padleft => $w - $options{-width} * 2,
	-padtop  => $options{-padtop}
);

my $win      = $cui->add( 'window_id',   'Window', %options );
my $win_info = $cui->add( 'window_info', 'Window', %options_info );

$cui->set_binding( sub { \&exit_dialog(); }, "q" );

my $label = $win_info->add(
	'mylabel', 'Label',
	-text => 'quit: q',
	-bold => 0,
)->draw();

my $label2 = $win_info->add(
	'mylabel1', 'Label',
	-text => 'Hello, world!\nds',
	-bold => 0,
	-x    => 30
)->draw();



my @values = sort { lc($a) cmp lc($b) } ( keys %{$ssh_config} );

my $listbox = $win->add(
	'mylistbox', 'Listbox',
	-values => \@values,

	#-labels => \%labels,

	#~ -radio     => 1,
	-onselchange => sub { \&display_ssh_config($ssh_config); }
);

$listbox->focus();
$cui->mainloop();

sub CURSE_setProperty{
	my ($obj,$property,$value) = @_;

	if ($obj)
	{
		#~ if ( exists($ob->{$property}) )
		{
			$obj->{$property} = $value;

			$obj->draw();
		}
		#~ else
		#~ {
			#~ $cui->error(" \$obj has not such property : $property ");
		#~ }
	}
	else
	{
		$cui->error("no such obj");
	}
}

sub display_ssh_config {
	my $config = shift;
	my $key    = $win->getobj('mylistbox')->get_active_value();

	my $win2 = $cui->add( 'w2', 'Window', %options2 )->draw();
	my $offSet = { x => 0, y => 0 };

	# $key		- of the hash with the dataset
	# $offset	- remember the postions of the labels
	# $value_key	- the config-key
	# $default_value- if the config-key not exists display this instead [optional]
	my $subFillLabels = sub {
		my ($key,$offSet, $value_key, $default_value) = @_;

		my ( $label_key, $label_val ) = ( 'label_k_' . $value_key, 'label_v_' . $value_key );
		my $x_offset = 20;

		my $entry = $config->{$key};

		if ( exists($entry->{$value_key}) || $default_value )
		{
			my $init_obj = sub {
				my ($key,$options) = @_;

				unless ( $win2->getobj($key) )
				{
					$win2->add( @{$options} )->draw();
				}
			};

			$init_obj->(	$label_key,
					[
						$label_key, 'Label',
						-text 	=> $value_key,
						-bold 	=> 1,
						-x	=> $offSet->{x},
						-y	=> $offSet->{y}
					]
			);

			my $value 	 = exists($entry->{$value_key}) ? $entry->{$value_key} : $default_value;
			my @value_labels = ( ref($value) eq 'ARRAY' ) ? @{$value} : ($value);

			for(my $i=0; $i<scalar(@value_labels); $i++)
			{
				my $label = $label_val.'_'.$i;
				$init_obj->(	$label,
						[
							$label, 'Label',
							-bold	=> 0,
							-x	=> $x_offset,
							-y	=> $offSet->{y},
							-text	=> $value_labels[$i]
						]
				);

				$offSet->{y} +=  $win2->getobj($label)->{-height};
			}
		}

	};


	$cui->leave_curses();
	$subFillLabels->( ($key,$offSet),('Hostname',$key));
	$subFillLabels->( ($key,$offSet),('User'));
	$subFillLabels->( ($key,$offSet),('Port'));
	$subFillLabels->( ($key,$offSet),('IdentityFile'));
	$subFillLabels->( ($key,$offSet),('Compression'));
	$subFillLabels->( ($key,$offSet),('LocalForward'));
	$subFillLabels->( ($key,$offSet),('RemoteForward'));

	#$cui->destroy();

	#print Dumper({$key=>$config->{$key}});

	$cui->delete('w2');

}

sub read_ssh_config {

	my $user = $ENV{'USER'};

	my %config = ();

	# temporary
	my $host;

	open( CONFIG, "</home/" . $user . "/.ssh/config" ) || eval { die $^E; };
	while (<CONFIG>) {
		( local $_ = $_ ) =~ s/\n//;

		if (/^Host[\ \t]([^#]+)/i) {
			$host = $1;
			$config{$host} = ();

			#print $host,"\n";
		}
		else {
			if (/^#|^$/)
			{
				#print "-- Leerzeile\n";
			}
			else
			{
				/([^\ \t]+)[\ \t]([^#]+)/;
				my ( $key, $value ) = ( $1, $2 );
				if ( exists( $config{$host}{$key} ) )
				{
					if ( ref( $config{$host}{$key} ) eq 'ARRAY' )
					{
						push( @{ $config{$host}{$key} }, $value );
					}
					else
					{
						my $old_val = $config{$host}{$key};
						$config{$host}{$key} = [ $old_val, $value ];
					}
				}
				else
				{
					$config{$host}{$key} = $value;

				}

			}
		}

		#print $_ if (/^$/);
	}
	close(CONFIG);

	#print Dumper( \%config );
	#exit;

	return \%config;
}
