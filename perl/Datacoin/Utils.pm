package Datacoin::Utils;

use strict;
use warnings;

our $VERSION = "0.1";

use base 'Exporter';

our @EXPORT = qw(init_config get_raw_key json_call method);

#use Datacoin::JSON::RPC::Client;
use Data::Dumper;

sub init_config {
  my ($path, $testnet) = @_;
  my %config;

  open(F, "< $path\/datacoin.conf") || die "Can't open \"$path\/datacoin.conf\"";
  while(<F>) {
    chomp $_;
    if ($_ =~ /^([^=]+)=(.*)$/) {
      if (exists $config{$1}) {
        print STDERR "Parameter $1 is redefined in line \"$_\"\n";
        next;
      }
      $config{$1} = $2;
    } else {
      print STDERR "Can't parse \"$_\"\n";
    }
  }
  close(F);

  if (!defined($testnet) || 0 == $testnet) {
    $config{"rpcport"} = 11777 unless exists $config{"rpcport"};
  } elsif (1 == $testnet) {
    $config{"rpcport"} = 11776 unless exists $config{"rpcport"}; # testnet
  }

  return %config;
}

sub get_raw_key {
  my ($str) = @_;
  $str =~ s/^-----BEGIN[A-Z ]+-----//;
  $str =~ s/^-----END[A-Z ]+-----//m;
  $str =~ s/[\r\n]//msg;
  return $str;
} 

sub json_call {
  my ($obj, $uri, $name, $rparams, $on_error) = @_;
  my $res;
  my $r = 0;
  while (1) {
    $res = $obj->call($uri, method($name, @{$rparams}));
    if (!$res->{is_success} && $res->{content}->{error} =~ /Can\'t connect/) {
      $r += 1;
      print STDERR "request \"$name\" retry $r\n";
      sleep(1);
      next;
    } elsif ($res->{is_success}) {
      return $res;
    } else {
      print STDERR "ERROR: JSON-RPC method \"$name\" with arguments\n";
      #print STDERR Dumper($rparams) . "\n";
      print STDERR "returned\n" . Dumper($res);
      print STDERR "JSON-RPC Client state\n" . Dumper($obj);
      if (defined $on_error) {
        $on_error->();
        last;
      } else {
        exit;
      }
    }
  }
  
  return $res;
}

sub method {
  my ($name, @params) = @_;
  my $obj = {
    method  => $name,
    params  => \@params,
  };
  print STDERR "obj = " . Dumper(\$obj) . "\n";
  return $obj;
}

1;
