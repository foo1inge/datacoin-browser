package Datacoin::Utils;

use strict;
use warnings;

our $VERSION = "0.1";

use base 'Exporter';

our @EXPORT = qw(init_config method);

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

  $config{"rpcport"} = 11777 unless exists $config{"rpcport"};
#  $config{"rpcport"} = 11776 unless exists $config{"rpcport"}; # testnet

  return %config;
}

sub method {
  my ($name, @params) = @_;
  my $obj = {
    method  => $name,
    params  => \@params,
  };
  return $obj;
}

1;
