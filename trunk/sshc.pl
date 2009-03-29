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
my $ssh_config = &read_ssh_config;

use Curses;
use Curses::UI;

my $cui = Curses::UI->new();

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
                            -text => 'quit: q',
                            -bold => 0,
                            )->draw();

my $label2 = $win_info->add(
                             'mylabel1', 'Label',
                             -text => 'Hello, world!\nds',
                             -bold => 0,
                             -x    => 30
                             )->draw();

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

    my $cmdline = &ssh_get_connection_info( $config, $key );
    $cui->leave_curses();

    print "executing ssh : $cmdline \n";
    system($cmdline);

}

sub ssh_get_connection_info
{
    my ( $config, $key ) = @_;

    if ( exists $config->{$key} )
    {
        my $entry   = $config->{$key};
        my $cmdline = 'ssh ';

        my $getValue = sub {
            my ( $key, $lowercase, $defaultkey ) = @_;

            if ( defined($lowercase) ? $lowercase : 1 )
            {
                $key = lc $key;
                $defaultkey = defined $defaultkey ? lc $defaultkey : undef;
            }

            if ( exists $entry->{$key} )
            {
                return $entry->{$key};
            }
            elsif ( defined $defaultkey && exists $entry->{$defaultkey} )
            {
                return $entry->{$defaultkey};
            }
            else
            {
                return undef;
            }
        };

        my $appendStr = sub {
            my ( $key, $prefix, $lowercase, $defaultkey, $sub_ref ) = @_;

            my $value = $getValue->( $key, $lowercase, $defaultkey );

            if ( defined $defaultkey && !defined $value )
            {
                warn "value should not be null \n";
            }

            if ( defined $value )
            {
                if ( ref $value ne 'ARRAY' )
                {
                    $value = [$value];
                }

                if ( defined $sub_ref && ref $sub_ref eq 'CODE' )
                {
                    map { $_ = $sub_ref->($_); } @{$value};
                }

                if ( defined $prefix )
                {
                    my $result;
                    grep { $result .= ' ' . $prefix . ' ' . $_; } @{$value};
                    return ' ' . $result;
                }
            }

            return '';
        };

        my $appendFlag = sub {
            my ( $key, $trueValue, $caseinsensitive, $flag_on_true ) = @_;

            my $value = $getValue->( $key, 1 );

            if ( ref $trueValue ne 'ARRAY' )
            {
                $trueValue = [$trueValue];
            }

            if ( defined $value )
            {
                for my $val ( @{$trueValue} )
                {
                    if ($caseinsensitive)
                    {
                        return $flag_on_true if ( $val =~ /^$value$/i );
                    }
                    else
                    {
                        return $flag_on_true if ( $val =~ /^$value$/ );
                    }
                }
            }

            return '';
        };

        my $prepareForwards = sub {
            local $_ = shift;
            s/[\ \t]+/:/;
            return $_;
        };

        $cmdline .= $appendFlag->( 'Compression', 'Yes', 1, '-C' );
        $cmdline .= $appendStr->( 'user',          '-l', 1 );
        $cmdline .= $appendStr->( 'identityfile',  '-i', 1 );
        $cmdline .= $appendStr->( 'port',          '-p', 1 );
        $cmdline .= $appendStr->( 'localforward',  '-L', 1, undef, $prepareForwards );
        $cmdline .= $appendStr->( 'remoteforward', '-R', 1, undef, $prepareForwards );
        $cmdline .= $appendStr->( 'Hostname', '', 1, 'Host' );

        $cmdline =~ s/([\ ])+/$1/g;
        return $cmdline;
    }
    else
    {
        return '';
    }
}

#&dump($listbox);

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
        my ( $key_, $_offSet, $value_key, $default_value ) = @_;
        $value_key = lc $value_key;

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

    $cui->leave_curses();
    $subFillLabels->( ( $key, $offSet ), ( 'Hostname', $key ) );
    $subFillLabels->( ( $key, $offSet ), ('User') );
    $subFillLabels->( ( $key, $offSet ), ('Port') );
    $subFillLabels->( ( $key, $offSet ), ('IdentityFile') );
    $subFillLabels->( ( $key, $offSet ), ('Compression') );
    $subFillLabels->( ( $key, $offSet ), ('LocalForward') );
    $subFillLabels->( ( $key, $offSet ), ('RemoteForward') );

    #$cui->destroy();

    #print Dumper({$key=>$config->{$key}});

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

    my $error_on_open = open my $fh, q{<}, '/home/' . $user . '/.ssh/config';
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

    #~ &dump( \%config );
    #~ exit;

    #~ &ssh_get_connection_info( \%config, 'zeus.fh-brandenburg.de' );
    #~ exit;

    return \%config;
}

