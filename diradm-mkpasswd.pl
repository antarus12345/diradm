#!/usr/bin/perl
# $Header: /code/convert/cvsroot/infrastructure/diradm/Attic/diradm-mkpasswd.pl,v 1.2 2004/12/10 03:12:50 robbat2 Exp $
use Crypt::SmbHash qw(lmhash nthash ntlmgen);
#use warnings;
use strict;

sub generatesalt {
    my $formatstr = $_[0];
    if(!$formatstr or length($formatstr) == 0) { $formatstr = '%.2s'; }
    my $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/
.";
    my $randstr = '';
    while(length($randstr) < 64) {
        my $val = int(rand(64));
        $randstr .= substr($chars,$val,1);
    }
    return sprintf($formatstr, $randstr);
}

sub usage {
	print "Usage: diradm-mkpasswd.pl [-m|-i] password [salt]\n";
	print "       diradm-mkpasswd.pl [-n|-l] password\n";
	exit 1;
}

my $passwd;
my $ARGC=$#ARGV+1;
if($ARGC >= 2) {
	# trim whitespace
	$passwd = $ARGV[1];
	$passwd =~ s/^\s+//g;
	$passwd =~ s/\s+$//g;
	#print "passwd: '",$passwd,"'\n";
} else {
	usage;
}


my $salt;

if( $ARGV[0] =~ /-m/ ) {    
	$salt = generatesalt( '$1$%.8s$' );
	$salt = $ARGV[2] if $ARGV[2];
	print  crypt( $passwd, $salt ) ;
} elsif( $ARGV[0] =~ /-i/ ) { 
	$salt = generatesalt;
	$salt = $ARGV[2] if $ARGV[2];
	print  crypt( $passwd, $salt ) ;
} elsif( $ARGV[0] =~ /-n/ ) { 
	print nthash( $passwd ) ;
} elsif( $ARGV[0] =~ /-l/ ) { 
	print lmhash( $passwd ) ;
} else {
	usage;
}

#print "\n"
