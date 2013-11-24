use strict;

use Google::ProtocolBuffers;
use MIME::Base64 qw( encode_base64 decode_base64 );
use IO::Compress::Bzip2 qw(bzip2 $Bzip2Error);
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);
use Crypt::OpenSSL::RSA;
use JSON::RPC::Client;
use File::HomeDir;
use Data::Dumper;

use Datacoin::Envelope;
use Datacoin::Utils;

# Parse daemon config
my %harg = parse_args(\@ARGV);
my $config_path = File::HomeDir->my_home . "/.datacoin/" unless length($harg{config_path}) > 0;
my %conf = init_config($config_path);

# Initialize JSONRPC
my $daemon = new JSON::RPC::Client;
$daemon->ua->credentials("localhost:$conf{rpcport}", 'jsonrpc', $conf{rpcuser} => $conf{rpcpassword});
my $uri = "http://localhost:$conf{rpcport}/";

# Compile header.proto
Google::ProtocolBuffers->parsefile("envelope.proto");

# Get raw transaction
my $res;
$res = $daemon->call($uri, method("getrawtransaction", ($harg{id})));
if (!$res->{is_success}) {
  print STDERR "Failed to do \"getrawtransaction\"\n";
  print STDERR Dumper($res) . "\n";
  exit;
}

my $rawtx = $res->{content}->{result};

# Decode raw transaction
$res = $daemon->call($uri, method("decoderawtransaction", ($rawtx)));
if (!$res->{is_success}) {
  print STDERR "Failed to do \"decoderawtransaction\"\n";
  print STDERR Dumper($res) . "\n";
  exit;
}

# Parse envelope
my $content = decode_base64($res->{content}->{result}->{data});
my $renv = Envelope->decode($content);
if (!exists $renv->{Data}) {
  print "This isn't an Envelope encoding. " . length($content) . " bytes are stored in tx in unknown format.\n";
  exit;
}
my $data = unpack_data_from_envelope($renv);

if (exists $harg{save_to}) {
  if (-e $harg{save_to}) {
    die "ERROR: file \"$harg{save_to}\" already exists.";
  }

  open(F, "> $harg{save_to}") || die "Can't open \"$harg{save_to}\"";
  print F $data;
  close(F);
} else {
  print $data; #Dumper($renv);
}

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

  return %h;
}
