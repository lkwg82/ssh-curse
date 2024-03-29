#!/bin/perl

use strict;
use warnings;
use diagnostics -verbose;

# perltidy --backup-and-modify-in-place -l=120 -cti=2  --opening-brace-on-new-line --opening-sub-brace-on-new-line -lp -vt=0 -vtc=0 -cab=0 sshc.pl

BEGIN
{
    $diagnostics::DEBUG  = 0;
    $diagnostics::PRETTY = 1;

    if (0)
    {
        use Perl::Critic;
        my $file = $0;
        my $critic = Perl::Critic->new( -severity => '3',
                                        -verbose  => 11 );
        my @violations = $critic->critique($file);

        my ( $i, $n ) = ( 0, scalar @violations );
        for ( reverse Perl::Critic::Violation::sort_by_severity(@violations) )
        {
            print '-' x 20, "\n";
            printf( "%3d/%d ", ++$i, $n );
            print "[" . $_->severity() . "] " . $_;
            print " -- source --- \n";
            print " source: ", $_->source(), "\n";
            print " -- /source --- \n";
            print " expl: ", $_->explanation(), "\n";
            print " desc: ", $_->description(), "\n";
            print " dia : ", $_->diagnostics(), "\n";
            print "\n --- press Enter to continue ---\n";
            <STDIN>;
        }
        exit;
    }
}

use XML::Dumper;
use Data::Dumper;
use autodie qw< :io >;
use English qw(-no_match_vars);
$OUTPUT_AUTOFLUSH = 1;

use Curses;
use Curses::UI;
use Term::ANSIColor;

my $cui = Curses::UI->new( -color_support => 1,
                           -clear_on_exit => 0 );


my $ssh_config = &read_ssh_config;

#-color_support,-clear_on_exit,-mouse_support
#);

my $w = $cui->width();
my $h = $cui->height();

sub exit_dialog
{
    my $return = $cui->dialog(
        -message => 'Do you really want to quit?',
        -title   => 'Are you sure???',
        -buttons => [ 'yes', 'no' ],
        -border  => 1,

        );

    exit 0 if $return;

    return;
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
                 -padtop  => $options{-padtop},
                 );

my $win      = $cui->add( 'window_id',   'Window', %options );
my $win_info = $cui->add( 'window_info', 'Window', %options_info );

$cui->set_binding( sub { \&exit_dialog(); }, 'q' );

my $label = $win_info->add(
                            'mylabel', 'Label',
                            -text => 'quit: q   connect: ENTER',
                            -bold => 0,
                            )->draw();

#~ my $label2 = $win_info->add(
#~ 'mylabel1', 'Label',
#~ -text => 'Hello, world!\nds',
#~ -bold => 0,
#~ -x    => 30
#~ )->draw();

my @values = sort { lc $a cmp lc $b } ( keys %{$ssh_config} );

my $listbox = $win->add(
    'mylistbox', 'Listbox',
    -values => \@values,

    #~ -labels => {'12designer-dev'=>'12'},
    -onselchange => sub { \&display_ssh_config($ssh_config); }
    );
$listbox->set_binding( sub { &ssh_connect( $ssh_config, $listbox ) }, KEY_ENTER );
$listbox->{-onselchange}->();
$listbox->focus();

sub ssh_connect
{
    my ( $config, $listbox ) = @_;

    my $key = $listbox->get_active_value();

    $cui->leave_curses();

    my $cmdline = "ssh $key";
    print colored ( "executing ssh : $cmdline", 'bold on_white' ), "\n";

    my $e = system($cmdline);

    $e /= 256;

    if ( $e == 255 )
    {

        #~ print colored ("exit code = $e",'bold red'),"\n";
        print colored ( "--- error occurred - see message above --- ", 'bold red on_black' ), "\n";
        print colored ( "- press ENTER to continue ---", 'green on_white' );
        <STDIN>;
    }

}

# debugging function
sub dump
{
    use XML::Dumper;
    my $dump = new XML::Dumper;

    # ===== Dump to a file
    my $file = "dump.xml";
    $dump->pl2xml( $_[0], $file );
}

$cui->mainloop();

sub CURSE_setProperty
{
    my ( $obj, $property, $value ) = @_;

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
        $cui->error('no such obj');
    }

    return;
}

sub display_ssh_config
{
    my $config = shift;
    my $key    = $win->getobj('mylistbox')->get_active_value();

    if ( $cui->getobj('w2') )
    {
        $cui->delete('w2');
    }

    my $win2 = $cui->add( 'w2', 'Window', %options2 )->draw();
    my $offSet = {
                   x => 0,
                   y => 0
                   };

    # $key        - of the hash with the dataset
    # $offset    - remember the postions of the labels
    # $value_key    - the config-key
    # $default_value- if the config-key not exists display this instead [optional]
    my $subFillLabels = sub {
        my ( $key_, $_offSet, $list_already_onscreen, $value_key, $default_value ) = @_;

        $value_key = lc $value_key;
        $list_already_onscreen->{$value_key} = 1;

        my ( $label_key, $label_val ) = ( 'label_k_' . $value_key, 'label_v_' . $value_key );
        my $x_offset = 20;

        my $entry = $config->{$key_};

        if ( exists $entry->{$value_key} || $default_value )
        {
            my $init_obj = sub {
                my ( $_key, $options ) = @_;

                if ( !$win2->getobj($_key) )
                {
                    $win2->add( @{$options} )->draw();
                }
            };

            $init_obj->(
                         $label_key,
                         [
                            $label_key, 'Label',
                            -text => $value_key,
                            -bold => 1,
                            -x    => $_offSet->{x},
                            -y    => $_offSet->{y}
                         ]
                         );

            my $value = exists $entry->{$value_key} ? $entry->{$value_key} : $default_value;
            my @value_labels = ( ref $value eq 'ARRAY' ) ? @{$value} : ($value);

            for my $i ( 0 .. scalar @value_labels - 1 )
            {
                my $_label = $label_val . '_' . $i;
                $init_obj->(
                             $label,
                             [
                                $_label, 'Label',
                                -bold => 0,
                                -x    => $x_offset,
                                -y    => $_offSet->{y},
                                -text => $value_labels[$i]
                             ]
                             );

                $_offSet->{y} += $win2->getobj($_label)->{-height};
            }
        }

    };

    my $list_already_onscreen = { 'host' => 1 };

    $subFillLabels->( ( $key, $offSet, $list_already_onscreen ), ( 'Hostname', $key ) );
    $subFillLabels->( ( $key, $offSet, $list_already_onscreen ), ('User') );
    $subFillLabels->( ( $key, $offSet, $list_already_onscreen ), ('Port') );
    $subFillLabels->( ( $key, $offSet, $list_already_onscreen ), ('IdentityFile') );
    $subFillLabels->( ( $key, $offSet, $list_already_onscreen ), ('Compression') );
    $subFillLabels->( ( $key, $offSet, $list_already_onscreen ), ('LocalForward') );
    $subFillLabels->( ( $key, $offSet, $list_already_onscreen ), ('RemoteForward') );

    #~ $cui->leave_curses();

    grep {
        if ( !( exists $list_already_onscreen->{$_} ) )
        {
            $subFillLabels->( ( $key, $offSet, $list_already_onscreen ), ($_) );
        }

    } sort keys %{ $config->{$key} };

    #~ <STDIN>;

    return;
}

sub read_ssh_config
{
    my $user = $ENV{'USER'};

    my %config = ();

    # temporary
    my $host;

    my $process_ssh_config = sub {
        my ( $fh, $config ) = @_;
        while (<$fh>)
        {
            ( local $_ = $_ ) =~ s/\n//smx;

            if (
                m{
                    ^(Host)      # a comment
                    [\ \t]      # or
                    ([^#]+)      # empty line
                }smxi
              )
            {
                $host = $2;
                $config->{$host} = { lc "$1" => $host };

                #print $host,"\n";
            }
            else
            {
                if (
                    m{
                            ^\#     # a comment
                            |       # or
                            ^$      # empty line
                        }smx
                  )
                {

                    # ignore
                }
                else
                {
                    if (
                        m{
                            ([^\ \t]+)    # match everything except
                            [\ \t]        # with space and tab in between
                            ([^\#]+)        # match everthing except beginning comment
                        }smx
                      )
                    {

                        # coz the keys are case-insensitive - lower them all
                        my ( $key, $value ) = ( lc $1, $2 );

                        if ( exists $config->{$host}->{$key} )
                        {
                            if ( ref $config->{$host}->{$key} eq 'ARRAY' )
                            {
                                push @{ $config->{$host}->{$key} }, $value;
                            }
                            else
                            {
                                my $old_val = $config->{$host}->{$key};
                                $config->{$host}->{$key} = [ $old_val, $value ];
                            }
                        }
                        else
                        {
                            $config->{$host}->{$key} = $value;
                        }
                    }
                    else
                    {
                        warn "regex not matched \n";
                    }
                }
            }

            #print $_ if (/^$/);
        }
    };

    my $ssh_config_file = '/home/' . $user . '/.ssh/config';
    if ( -e $ssh_config_file )
    {
        my $error_on_open = open my $fh, q{<}, $ssh_config_file;
        if ( !$error_on_open )
        {
            die $EXTENDED_OS_ERROR;
        }
        else
        {
            $process_ssh_config->( $fh, \%config );
            my $error_on_close = close $fh;
            if ( !$error_on_close )
            {
                die $EXTENDED_OS_ERROR;
            }
        }
    }
    else
    {
        $cui->error(
            -message => 'please create a ssh config file : '.$ssh_config_file,
            -title   => 'config missing',
            -buttons => [ 'ok' ],
            -border  => 1,
            );
        exit 1;
    }

    #~ &dump( \%config );
    #~ exit;

    #~ &ssh_get_connection_info( \%config, 'zeus.fh-brandenburg.de' );
    #~ exit;

    return \%config;
}

