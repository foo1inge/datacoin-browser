datacoin-browser
================

**1. How to put file into Datacoin blockchain?**

$ perl dtc\_put\_file.pl file.txt

Upon success scripts returns id of transaction received from daemon. This means that daemon accepted this transaction.

Use "--add_key" argument in order to add RSA public key to file. Correpspondin private key will be printed to STDOUT. Keys and signatures are required to link several txes in "big file" and "update file" scenarios. For details see "envelope.proto" file.

Note: both scenarios aren't fully implemented now. Only small (less 128Kb) files can be easily stored now.

**2. How to get data from Datacoin blockchain?**

$ perl dtc\_get\_file.pl txid

"txid" is a transaction id returned by dtc\_put\_file.pl.

Upon success scripts prints data content of corresponding transaction. In order to save data to file use "--save_to=filename" option. 

**Dependencies**

Both scripts depends on following modules.

- Google::ProtocolBuffers
- MIME::Base64
- IO::Compress::Bzip2
- IO::Uncompress::Bunzip2
- Crypt::OpenSSL::RSA
- JSON::RPC::Client
- File::HomeDir
- Data::Dumper 
