datacoin-browser
================

* How to put file into Datacoin blockchain?

$ perl dtc_put_file.pl file.txt

Upon success scripts returns id of transaction received from daemon. This means that daemon accepted this transaction.

Use "--add_key" argument in order to add RSA public key to file. Correpspondin private key will be printed to STDOUT. Keys and signatures are required to link several txes in "big file" and "update file" scenarios. For details see "envelope.proto" file.

Note: both scenarios aren't fully implemented now. Only small (less 128Kb) files can be easily stored now.

* How to get data from Datacoin blockchain?

$ perl dtc_get_file.pl txid

"txid" is a transaction id returned by dtc_put_file.pl.

Upon success scripts prints data content of corresponding transaction. In order to save data to file use "--save_to=filename" option. 
