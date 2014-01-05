#!/usr/bin/perl
use strict;
use warnings;

package Datacoin::LocalServer;
 
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

use File::HomeDir;
use Datacoin::JSON::RPC::Client;
use Google::ProtocolBuffers;
use MIME::Base64 qw( encode_base64 decode_base64 );
use Data::Dumper;

use Datacoin::Envelope;
use Datacoin::Utils;

our $VERSION = "0.1";

use base 'Exporter';

our @EXPORT = qw(init_daemon);


 sub new {
   my ($class, $rharg, $port, $testnet) = @_;
   
   my $self = $class->SUPER::new($port);

   if (defined($testnet) && 1 == $testnet) {
     $self->{testnet} = 1;
     $self->{urlprefix} = "dtc-testnet";
   } else {
     $self->{testnet} = 0;
     $self->{urlprefix} = "dtc";
   }

   my %harg = %{$rharg};
   my $config_path = File::HomeDir->my_home . "/.datacoin/" unless exists $harg{config_path};
   my %conf = init_config($config_path, $self->{testnet});

   # Initialize JSONRPC
   $self->{daemon} = new Datacoin::JSON::RPC::Client;
   $self->{daemon}->ua->credentials("localhost:$conf{rpcport}", 'jsonrpc', $conf{rpcuser} => $conf{rpcpassword});
   $self->{daemon}->ua->timeout(60);
   $self->{uri} = "http://localhost:$conf{rpcport}/";
   

   # Compile header.proto
   Google::ProtocolBuffers->parsefile("envelope.proto");

   return $self;
 }

 sub get_tx_data {
   my ($self, $txid) = @_;
   my $data;

   my $res = json_call($self->{daemon}, $self->{uri}, "getdata", [$txid], sub {print STDERR "error fetching data from $txid\n";});
   my $base64_data = $res->content->{result};

   if (0 == length($base64_data)) { return $data; }

   print STDERR "LocalServer::get_tx_data($txid).length() == " . length($base64_data);

   $data = decode_base64($base64_data);

   return $data;
 }

 sub execute_json_method {
   my ($self, $method, @args) = @_;
   print STDERR "executing JSON call: $method with args (" . join(", ", @args) . ")\n";
   my $res = json_call($self->{daemon}, $self->{uri}, $method, \@args, sub {print STDERR "ERROR: \"$method\"\n";});
   return $res->jsontext;
 }

 sub parse_envelope {
   my ($self, $data) = @_;

   my $renv;
   eval { $renv = Envelope->decode($data); };

   if (exists $renv->{Data}) {
     print STDERR " " . join(" ", ($renv->{FileName}, $renv->{ContentType}, $renv->{Compression}, "\n"));
   }
 
   return $renv;
 }
 
 sub handle_request {
     my $self = shift;
     my $cgi  = shift;
   
     my $path = $cgi->path_info();

     if ($path =~ /^\/$self->{urlprefix}\/tx\/([^\/]+)(\/([^\/]+))?/) {
       my ($id, $mode) = ($1, $3);

       # Get object by id from daemon
       my $data = $self->get_tx_data($id);
       
       if (!defined($mode)) {
         my $renv = $self->parse_envelope($data);
         if (defined($renv)) {
           print "HTTP/1.0 200 OK\r\n";

           if (exists $renv->{ContentType}) {
             print "Content-type: $renv->{ContentType};\r\n\r\n";
           } else {
             print $cgi->header;
           }
           my $unpacked_data = unpack_data_from_envelope($renv);
           print $unpacked_data;
         } else {
           print "HTTP/1.0 200 OK\r\n";
           print $cgi->header, $cgi->start_html('Error'),
                 $cgi->h1('Error'), "Can't parse tx $id as an Envelope\n",
                 $cgi->end_html;
         }
       } elsif ("raw" eq $mode) {
         print "HTTP/1.0 200 OK\r\n";
         print $cgi->header, $data;
       } else {
         print "HTTP/1.0 200 OK\r\n";
         print $cgi->header, $cgi->start_html('Error'),
               $cgi->h1('Error'), "Unknown mode $mode\n",
               $cgi->end_html;
       }
     } elsif ($path =~ /^\/$self->{urlprefix}\/rpc\/([^\/]+)(\/(.*))?$/) {
       my ($method, $rawargs) = ($1, $3);
       my @args = split(/\//, $3);
       if ("getinfo" eq $method || "getblockhash" eq $method || "getblock" eq $method ||
           "getrawtransaction" eq $method || "getmininginfo" eq $method) {
         print "HTTP/1.0 200 OK\r\n";
         print "Content-type: application/json;\r\n\r\n",
               $self->execute_json_method($method, @args) . "\r\n";
       } else {
         print "HTTP/1.0 404 OK\r\n";
         print "Content-type: application/json;\r\n\r\n",
               "{ \"Method\": \"$method\", \"Error\": \"unknown method\" }\r\n";
       }
     } elsif ($path =~ /^\/$self->{urlprefix}\/lsrpc\/([^\/]+)(\/(.*))?$/) {
       # This is Datacoin::LocalServer RPC (we have to handle it here)
       my ($method, @args) = ($1, split("\/", $3));
       if ("getenvelope" eq $method) {
         print "HTTP/1.0 200 OK\r\n";
         print "Content-type: application/json;\r\n\r\n";
         if ($#args < 0) {
           print "{ \"Method\": \"$method\", \"Error\": \"no tx id provided\" }\r\n";
           return;
         }
         my $id = $args[0];
         my $data = $self->get_tx_data($id);
         my $renv = $self->parse_envelope($data);
         if (defined($renv)) {
           print "{ \"result\": {";
           foreach my $k (keys %{$renv}) {
             if ("Data" ne $k) {
               if ("PublicKey" eq $k || "Signature" eq $k) {
                 my $encstr = encode_base64($renv->{$k}, "");
                 chomp $encstr;
                 print "\"$k\":\"$encstr\",";
               } else {
                 print "\"$k\":\"$renv->{$k}\",";
               }
             }
           }
           print "} }";
         } else {
           print "HTTP/1.0 404 Not found\r\n";
           print $cgi->header, $cgi->start_html('Not found'), $cgi->h1('Not found'), $cgi->end_html;
         }
       }
     } else {
         print "HTTP/1.0 404 Not found\r\n";
         print $cgi->header, $cgi->start_html('Not found'), $cgi->h1('Not found'), $cgi->end_html;
     }
 }
 
 sub handle_raw_data_request {
     my $cgi  = shift;   # CGI.pm object
     return if !ref $cgi;
     
     my $who = $cgi->param('name');
     
     print $cgi->header,
           $cgi->start_html("Hello"),
           $cgi->h1("Hello $who!"),
           $cgi->end_html;
 }
 

1;
