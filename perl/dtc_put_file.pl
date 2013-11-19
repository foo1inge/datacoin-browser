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
#print Dumper(\%conf);

# Initialize JSONRPC
my $daemon = new JSON::RPC::Client;
$daemon->ua->credentials("localhost:$conf{rpcport}", 'jsonrpc', $conf{rpcuser} => $conf{rpcpassword});
my $uri = "http://localhost:$conf{rpcport}/";

my $res = $daemon->call($uri, method("getinfo", ()));
#print Dumper($res) . "\n";

# Compile header.proto
Google::ProtocolBuffers->parsefile("envelope.proto");

# Pack file into envelope 
my $rsa_new_public_key;
if ("true" eq $harg{add_key}) {
  #Crypt::OpenSSL::Random::random_seed($good_entropy);
  Crypt::OpenSSL::RSA->import_random_seed();
  $rsa_new_public_key = Crypt::OpenSSL::RSA->generate_key(1024);
  $rsa_new_public_key->use_pkcs1_oaep_padding;

  print $rsa_new_public_key->get_private_key_string() . "\n";
}

my $rsa_private_key;
if (exists $harg{sign_with}) {
  open(F, "< $harg{sign_with}") || die "Can't open file \"$harg{sing_with}\"";
  my $private_key_string;
  while (<F>) { $private_key_string .= $_; }
  close(F);
  $rsa_private_key = Crypt::OpenSSL::RSA->new_private_key($private_key_string);
}

my $renv = create_envelope($harg{file}, $harg{content_type}, $rsa_new_public_key, $rsa_private_key);
#print Dumper($renv);
my $blob = Envelope->encode($renv);
if (length($blob) > (1024*128)) {
  die "ERROR: File is too big: " . legnth($blob) . "bytes. Max size is 128Kb";
}
my $txdata = encode_base64($blob, "");
#print $txdata . "\n"; 

#open(Z, "> tttt.txt");
#print Z Envelope->encode($renv);
#close(Z);

# Try to send tx with data
my $res = $daemon->call($uri, method("senddata", ($txdata)));

if ($res->{is_success}) {
  my $txid = $res->{content}->{result};
  print $txid . "\n";
} else {
  print STDERR "Failed to send tx\n";
  print STDERR Dumper($res) . "\n";
  exit;
}

#print Dumper($renv);

sub parse_args {
  my ($ra) = @_;
  my %h;

  foreach my $a (@{$ra}) {
    if ($a =~ /^--([a-zA-Z_\-]+)=(.*)$/) {
      $h{$1} = $2;
    } elsif (! exists $h{file}) {
      $h{file} = $a;
    } else {
      die "Can't parse \"$a\"";
    }
  }

  return %h;
}
