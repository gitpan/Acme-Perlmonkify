package Acme::PerlMonkify;
use 5.008;
use strict;
use warnings;

=pod

=head1 NAME

Acme::Perlmonkify - Rewrites your code in the style of perlmonks.org

=head1 SYNOPSIS

 perl -MAcme::PerlMonkify my_script.pl

=head1 DESCRIPTION

The first time you run a program under Acme::PerlMonkify, the module
removes most of the variable, function and file handle names from your
source file and replaces them with PerlMonks.org usernames. The code
(hopefully) continues to work exactly as it did before, but now it
looks like this:

 my $Ovid = Benedictine_Monk();
 Basavaraj_Khuba($SaveDir, $Ovid);

The easiest way to use this is right from the command prompt:

 perl -MAcme::PerlMonkify my_script.pl

=cut

our $strict;
our $warnings;
our $VERSION = '0.02';

use LWP::Simple;
use Cache::FileCache ();
use B::Deobfuscate '0.10';

use constant DEBUG => 0;

our ( $start_url, $USERNAME, $START );
BEGIN {
    $start_url = "http://tinymicros.com/pm/index.php?goto=MonkStats&start=1";
    $USERNAME = "usernames";
    $START = "start";
}

BEGIN {
    my $old = \ &B::Deparse::declare_hints;
    no warnings 'redefine';
    *B::Deparse::declare_hints = sub {
        my $r = $old->( @_ );
        no strict 'refs';
        ${__PACKAGE__ . "::$1"} = 1 if $r =~ /^use (warnings|strict)/;
        ${__PACKAGE__ . "::warnings"} = 1 if $^W or ${^WARNING_BITS};
        return $r;
    }
}

sub cached_get {
    my $cache = shift;
    my $start = shift;
    
    my $url;
    ($url = $start_url) =~ s/(?<=start=)\d+/$start/;
    
    my $html = $cache->get( $url );
    return $html if $html;
    
    $html = get( $url );
    $cache->set( $url, $html );
    
    return $html;
}

sub usernames {    
    my $cache = Cache::FileCache->new( { namespace => __PACKAGE__ } );
    
    my $users = $cache->get( $USERNAME ) || {};
    my $start = $cache->get( $START ) || 0;
    
    # Get the next cached page
    my $page = cached_get( $cache, $start );
    
    # Update the start parameter so we'll search farther next time.
    DEBUG and print "$START: $start\n";
    my $new_start = $start + 50;
    $cache->set( $START, $new_start );
    
    # Update the users list
    my @urls = $page =~ m{<tr>(?>(?!<a\s)(?s:.))+<a\s+([^>]+)>(.+)}ig;
    for (my $i = 0; $i < @urls; $i += 2) {
        unless ($urls[$i] =~ m{http://(?:www\.)+perlmonks\.org}) {
            $urls[$i + 1] = undef;
        }
        $urls[$i] = undef;
    }
    my @new_users = grep defined, @urls;
    
    for (@new_users) {
        s((?:\s*</[^>]+>)*\s*$)()mi;
        s/\W/_/g;
    }
      
    @$users{@new_users} = () x @new_users;
    DEBUG and print "\@new_users: " . @new_users . "\n";

    $cache->set( $USERNAME, $users );
    DEBUG and print( "%users: ".(0+keys %$users), "\n" );
    
    return join "\n", keys %$users;
}

sub import {
    shift;
    return if @_;
    
    my $deparse = B::Deparse->new(qw(-p))->coderef2text(
        \&B::Deparse::begin_is_use );
    $deparse =~ s{^\s*if\s*\(\s*\(\s*\(\s*\(\s*\(\s*(\$\w+)\s+eq\s*'strict'
    \s*\)\s*or\s*\(\s*\$\w+\s+eq\s*'integer'\s*\)\s*\)\s*or\s*\(\s*\$\w+\s+eq
    \s*'bytes'\s*\)\s*\)\s*or\s*\(\s*\$\w+\s+eq\s*'warnings'\s*\)\s*\)\s*\)
    \s*{\s*return\s*\(\s*''\s*\)\s*;\s*}\s*^}{
    \$Acme::PerlMonkify::strict = 1 if $1 eq 'strict';
    \$Acme::PerlMonkify::warnings = 1 if $1 eq 'warnings';
    }mx;
    {
        no warnings;
        *B::Deparse::begin_is_use = eval "sub $deparse" or die $@;
    }
    
    open *B::Deobfuscate::DATA, "<", \ usernames();
    require O;
    tie *STDOUT, __PACKAGE__ || die $!;
    O->import( 'Deobfuscate', "-m/${\qr[\A(?=\w*[[:lower:]]\w*)\w+\z]}/" );
}

sub TIEHANDLE { bless \my $stick, shift }
sub PRINT {
    my $src = $_[1];
    
    local *OUT;
    open OUT, ">", $0 or die "Cannot monkify '$0'";
    select OUT;
    $| = 1;

    open STDIN, $0;
    my $octothorpebang = <STDIN>;
    print OUT $octothorpebang if $octothorpebang and $octothorpebang =~ /^\Q#!/;

    print OUT
        +(not ($strict or $warnings)) ? qq[warn "So you didn't use strict? And no warnings? - Expect the Inquisitors\n";] :
        not($strict) ? qq[warn "No strict?! Who do you think you are, [TheDamian]?\n";] :
        not($warnings) ? qq[use strict;\nwarn "I didn't see you use warnings so I turned them on for you and made them fatal errors";\nuse warnings FATAL => 'all'; \# Bwuahaha!\n] : 
        "\# Sit! What a good monk you are! Good boy!\nuse strict;\nuse warnings;\n";

    $src =~ s/\A(?:^sub Cache::[\w:]+;\s*)+//gm;
    print OUT $src;
    close STDERR;
}

1;

__END__
