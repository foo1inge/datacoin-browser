package Datacoin::Envelope;

use strict;
use warnings;

our $VERSION = "0.1";

use base 'Exporter';

our @EXPORT = qw(create_envelope unpack_data_from_envelope);

use MIME::Base64 qw( encode_base64 decode_base64 );
use IO::Compress::Bzip2 qw(bzip2 $Bzip2Error);
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);
use Crypt::OpenSSL::RSA;
use Datacoin::Utils; 

sub create_envelope {
  my ($fn, $ct, $rsa_public_key, $rsa_private_key) = @_;
  my %env;

  $env{FileName} = $fn;
  $env{Compression} = Envelope::CompressionMethod::Bzip2();

  bzip2 $fn => \$env{Data} || die "bzip2 failed: $Bzip2Error\n"; 

  if (defined $ct) {
    $env{ContentType} = $ct;
  }

  if (defined $rsa_public_key) {
    my $public_key = decode_base64(get_raw_key($rsa_public_key->get_public_key_string()));

    $env{PublicKey} = $public_key;
  }

  if (defined $rsa_private_key) {
    $env{Signature} = $rsa_private_key->sign($env{Data});
  } 
 
  return \%env;
}

sub unpack_data_from_envelope {
  my ($renv) = @_;
  my $data;
  
  if (exists $renv->{Compression}) {
    if (Envelope::CompressionMethod::Bzip2() == $renv->{Compression}) {
      bunzip2 \$renv->{Data} => \$data;
    } else {
      die "ERROR: compression method $renv->{Compression} isn't supported yet";
    }
  } else {
    return $renv->{Data};    
  }

  return $data;
}

1;
