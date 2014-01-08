use strict;
use utf8;

use Datacoin::LocalServer;

# Initialize
my %harg = parse_args(\@ARGV);

my $localSrv = Datacoin::LocalServer->new(\%harg, $harg{"http-port"}, $harg{testnet});

$localSrv->run();

###

sub parse_args {
  my ($ra) = @_;
  my %h;

  foreach my $a (@{$ra}) {
    if ($a =~ /^--([a-zA-Z_\-]+)=(.*)$/) {
      $h{$1} = $2;
    } elsif (! exists $h{file}) {
      $h{id} = $a;
    } else {
      die "Can't parse \"$a\"";
    }
  }

  if (! exists($h{"http-port"})) {
    $h{"http-port"} = 80;
  }

  return %h;
}
